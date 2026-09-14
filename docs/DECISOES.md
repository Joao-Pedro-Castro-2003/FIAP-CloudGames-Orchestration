# Decisões e limites

## Sem nuvem e com função real

Azure Functions executa como runtime FaaS com triggers RabbitMQ. KEDA observa as duas filas e ajusta a função de zero a duas réplicas (consulta a cada 5s, cooldown de 60s). Azurite fornece o armazenamento necessário ao host sem conta Azure. Infraestrutura é versionada em manifestos Kubernetes no repositório da função, um formato de infraestrutura como código.

Isso demonstra capacidades serverless em um cluster local autogerenciado. Não é uma implantação no serviço Azure gerenciado, não há cobrança por execução e o cluster/RabbitMQ/KEDA continuam ligados. O requisito do vídeo deve ser demonstrado em Kubernetes; Compose sozinho não comprova a otimização do container ocioso.

## Dados

- SQLite por serviço: usuários; jogos, promoções, pedidos e biblioteca.
- MongoDB: avaliações (comentários/tags), decisões imutáveis por pedido e comprovantes das notificações.
- Redis: cache descartável; não é a fonte de verdade.
- PVCs preservam dados quando Pods são recriados. Excluir o cluster remove o armazenamento local.
- EnsureCreated cria bancos novos. Para alterar o esquema de um banco existente no futuro, adicionar migrations ou um processo explícito de migração; não apagar dados para atualizar tabelas.
- Os arquivos reconstruídos não recuperam registros de bancos antigos.

## Cache

Padrão cache-aside. A primeira consulta de avaliações lê MongoDB e grava Redis; a seguinte usa Redis. PUT salva no MongoDB e remove a chave. TTL absoluto de 30 segundos limita conteúdo antigo caso a invalidação falhe ou haja uma leitura concorrente à escrita. Há consistência eventual nesse intervalo, não garantia de leitura imediatamente consistente em concorrência.

Falha de Redis não impede ler/gravar avaliações; a API consulta MongoDB e registra BYPASS. Erros de MongoDB não são transformados em lista vazia: o cliente recebe erro. Paginação limita a resposta; o índice por jogo/data atende à ordenação das avaliações.

## Mensagens

- MassTransit publica envelopes JSON e exchanges pelo nome do contrato. A função extrai o campo message e valida messageId.
- As filas e bindings da função são criados previamente pelas definições do RabbitMQ. Assim as mensagens aguardam mesmo quando a função está em zero.
- PaymentsAPI persiste a primeira decisão no MongoDB por OrderId. Uma reentrega reutiliza a mesma aprovação e valores; não sorteia um novo resultado.
- CatalogAPI salva status aprovado ou rejeitado e atualiza a biblioteca na mesma transação. Resultados de pedidos já finalizados são ignorados.
- A função registra um comprovante único por usuário (boas-vindas) ou pedido (pagamento). Notificações são simulações, sem e-mail real.
- Filas da função possuem dead-letter exchange notifications-dead. Mensagens rejeitadas pelo trigger ficam na fila notifications-dead para análise. Consumidores MassTransit têm tentativas limitadas e filas _error.
- Em falha persistente, investigar logs e corrigir a causa antes de republicar o envelope original. Não excluir filas para tentar corrigir o sistema.

Ainda existe uma janela entre salvar usuário/pedido no SQLite e publicar seu evento no RabbitMQ: uma interrupção nesse ponto pode deixar a operação sem evento. Não há outbox transacional durável no produtor. A implementação não promete entrega exatamente uma vez. O comprovante da função também não é transacional com a emissão do log: em um encerramento nesse intervalo pode haver comprovante sem a linha de sucesso. Esses limites devem ser conhecidos ao avaliar recuperação de falhas; o teste normal pressupõe dependências disponíveis.

## Segurança e escopo

Gateway verifica assinatura e expiração; APIs também verificam audiência e emissor. Cadastro público rejeita tentativa de tornar-se administrador. O seed de admin opera apenas em banco vazio e usa senha gerada fora do Git.

Configurações com segredos são geradas em .local e viram Kubernetes Secrets. As portas de demonstração são locais. MongoDB sem autenticação e HTTP interno são escolhas restritas a este ambiente de estudo isolado; não usar estes manifestos diretamente para publicar na internet.

Logs evitam senha, token e e-mail nas notificações. Alloy coleta stdout dos Pods por RBAC limitado ao namespace. No Compose, o coletor usa o socket local do Docker para ler logs dos containers do projeto. Para operação contínua real, separar identidades, credenciais, TLS, backups, retenção e capacidade conforme a implantação escolhida.

## Observabilidade

Escolhida opção A: Prometheus/Grafana. Latência, contagem e taxa de erro vêm do prometheus-net. Loki/Alloy atendem à centralização de logs da demonstração. Não há APM pago nem implementação de traces distribuídos. Métricas incluem também requisições internas de saúde; 401 rejeitados no Kong não chegam ao contador das APIs e podem ser vistos nos logs do gateway.
