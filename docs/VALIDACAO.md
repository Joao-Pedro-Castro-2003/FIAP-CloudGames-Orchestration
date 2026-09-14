# Validação da implementação

Validação local realizada em 11/09/2026, em Windows com Docker Desktop (Linux containers), kind e Kubernetes 1.32.2. Não houve implantação em nuvem ou publicação no GitHub.

## Testes automatizados

17 testes aprovados: UsersAPI (3), CatalogAPI (9), PaymentsAPI (1), NotificationsFunction (4).

- Bancos SQLite reais em memória: esquema e transações.
- Cadastro público sem elevação para administrador.
- Validação MVC dos requests, incluindo preços nas culturas pt-BR e en-US.
- Desconto, pagamento aprovado/rejeitado e atualização da biblioteca.
- Decisão de pagamento previamente persistida respeitada no consumo.
- Cache com invalidação e falha simulada de Redis.
- Parsing e identificação estável de notificações MassTransit.

## Integração executada com containers

| Verificação | Resultado |
|---|---|
| Quatro imagens .NET construídas | Aprovado |
| Start-Kubernetes.ps1 completo | Executado com sucesso, preservando o cluster e as credenciais |
| Kong: token ausente/inválido e autorização | 401/403 conforme esperado; /metrics externo retorna 404 |
| Cadastro, login, jogo, promoção e compra | Aprovado; jogo de 100 comprado por 80 |
| Pagamento aprovado | Pedido finalizado e jogo presente na biblioteca |
| Pagamento rejeitado | Pedido finalizado sem liberar jogo; configuração restaurada |
| MongoDB real | Avaliação criada e atualizada sem duplicação |
| Redis real | MISS, HIT e invalidação na escrita |
| Redis indisponível | BYPASS com leitura mantida pelo MongoDB |
| Recriação de MongoDB/Users/Catalog | Login e avaliação preservados nos volumes |
| Recriação do RabbitMQ | Fila durável e mensagem persistente recuperadas; fila temporária removida |
| Prometheus | Três APIs com scrape ativo; consultas dos seis painéis de métricas retornam séries |
| Grafana | Dashboard FCG - Fase 3 provisionado com sete painéis |
| Loki/Alloy | Logs das duas notificações encontrados pelos IDs do fluxo |
| Azure Functions/RabbitMQ | Boas-vindas e resultado do pagamento executados diretamente por trigger |
| KEDA | Ativação por mensagens e retorno a zero, repetidos com novos eventos |
| Gitignore | .env, .local, credenciais e kubeconfig ignorados; código Data versionável |

O Docker foi fechado e reaberto entre sessões; o cluster e seus registros permaneceram disponíveis. O hostname do RabbitMQ foi fixado para manter a identidade do banco entre recriações de Pods. A mudança inicial foi aplicada com todas as filas vazias; o armazenamento anterior permaneceu no PVC.

## Reproduzir

Na pasta de orquestração, com Docker Desktop aberto:

```powershell
.\scripts\Start-Kubernetes.ps1
.\scripts\Test-Flow.ps1
.\scripts\Test-Observability.ps1
.\scripts\Test-Serverless.ps1
# Cenários de recuperação; interrompem temporariamente serviços locais:
.\scripts\Test-Recovery.ps1
.\scripts\Test-Rejection.ps1
.\scripts\Test-BrokerPersistence.ps1
```

IDs e resultado do último fluxo ficam em .local/last-test.json, sem senhas nem tokens. Os testes criam dados demonstrativos. Test-Rejection restaura a configuração de pagamento em finally; Test-Recovery restaura Redis.

Na pasta que contém os repositórios:

```powershell
dotnet test FIAP-UsersAPI/UsersAPI.sln
dotnet test FIAP-CatalogAPI/CatalogAPI.sln
dotnet test FIAP-PaymentsAPI/PaymentsAPI.sln
dotnet test FIAP-NotificationsFunction/NotificationsFunction.sln
```

## Limites e trabalho externo

- Compose foi configurado, mas a validação integrada descrita acima foi executada em Kubernetes.
- Não foi realizado teste de carga, alta disponibilidade ou implantação pública.
- A simulação não envia e-mail nem cobra dinheiro.
- Ainda há as janelas de falha sem outbox durável descritas em DECISOES.md; não se promete entrega exatamente uma vez.
- Publicação dos repositórios, vídeo e entrega acadêmica continuam sob responsabilidade do usuário.
