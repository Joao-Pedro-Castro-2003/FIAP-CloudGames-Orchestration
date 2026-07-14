# FIAP Cloud Games - Orchestration

Repositorio de orquestracao do Tech Challenge FIAP - Fase 2.

Este repo centraliza a execucao local e os manifestos Kubernetes dos quatro microservicos:

- UsersAPI: cadastro, login JWT e evento `UserCreatedEvent`
- CatalogAPI: catalogo, promocoes, compras e biblioteca
- PaymentsAPI: simulacao de pagamento e evento `PaymentProcessedEvent`
- NotificationsAPI: simulacao de notificacoes no console

## Estrutura esperada

Mantenha os cinco repos como pastas irmas:

```text
C:\GitHubPessoal\Meus-Repositorios\
  FIAP-UsersAPI\
  FIAP-CatalogAPI\
  FIAP-PaymentsAPI\
  FIAP-NotificationsAPI\
  FIAP-CloudGames-Orchestration\
```

## Subir localmente com Docker Compose

```powershell
cd C:\GitHubPessoal\Meus-Repositorios\FIAP-CloudGames-Orchestration
docker compose up --build
```

Servicos publicados:

- UsersAPI: http://localhost:5001
- CatalogAPI: http://localhost:5002
- PaymentsAPI: http://localhost:5003
- NotificationsAPI: http://localhost:5004
- RabbitMQ Management: http://localhost:15672

Credenciais padrao do RabbitMQ Management:

- Usuario: `guest`
- Senha: `guest`

## Fluxo principal para validar

1. Criar usuario no UsersAPI.
2. Confirmar log de boas-vindas no NotificationsAPI.
3. Fazer login e obter token JWT.
4. Criar jogo no CatalogAPI com token de usuario admin.
5. Iniciar compra no CatalogAPI.
6. Confirmar processamento no PaymentsAPI.
7. Confirmar atualizacao de pedido/biblioteca no CatalogAPI.
8. Confirmar log de notificacao de compra no NotificationsAPI.

## Kubernetes

A pasta `k8s/` contem manifestos base para rodar em cluster local.

Aplicar tudo:

```powershell
kubectl apply -f .\k8s\
```

Remover tudo:

```powershell
kubectl delete -f .\k8s\
```

Antes de aplicar em Kubernetes, gere ou publique as imagens Docker usadas nos manifests.
