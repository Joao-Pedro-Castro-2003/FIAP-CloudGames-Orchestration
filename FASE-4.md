# Relatório de entrega — FIAP Cloud Games, Fase 4

**Integrantes e usuários do Discord** — [preencher nomes e usuários]

**Vídeo** — [inserir link acessível ao avaliador]

## Código e documentação

- [Users API](https://github.com/Joao-Pedro-Castro-2003/FIAP-UsersAPI)
- [Catalog API](https://github.com/Joao-Pedro-Castro-2003/FIAP-CatalogAPI)
- [Orquestração Kubernetes, gateway e roteiro de execução](README.md)

## Arquitetura

O Kong recebe as requisições do cliente. A Users API emite o token de autenticação. A Catalog API persiste o catálogo no PostgreSQL e atualiza o índice de busca no OpenSearch. As avaliações são persistidas no MongoDB, e as consultas repetidas podem usar o cache do Redis. Users API e Catalog API foram implantadas com duas réplicas cada.

## Evidências da demonstração

| Item | Evidência | Ambiente |
| --- | --- | --- |
| Busca com tolerância a erros | A consulta por `galaxai` encontrou o jogo 15 após o cadastro. | Kubernetes local |
| Avaliações e cache | A avaliação do jogo 15 foi gravada e a demonstração compara duas consultas consecutivas pelo cabeçalho `X-Cache`. | Kubernetes local |
| Substituição gradual das réplicas | O vídeo mostra a sondagem autenticada durante o rolling restart da Catalog API com a imagem atual. | Kubernetes local |
| Registro privado | Imagens da Users API e da Catalog API publicadas nos repositórios privados do Amazon ECR com a tag `fase4-20261117-203924`. | AWS |
| Kubernetes gerenciado | As duas APIs chegaram a duas réplicas prontas no Amazon EKS. | AWS |
| Acesso externo | Kong exposto por LoadBalancer. A requisição externa sem token recebeu HTTP 401 do gateway. | AWS |

Os scripts [Test-Search.ps1](scripts/Test-Search.ps1), [Test-Flow.ps1](scripts/Test-Flow.ps1) e [Test-Rollout.ps1](scripts/Test-Rollout.ps1) acompanham a documentação de reprodução.

## CI/CD e limitação do ambiente

Os workflows das duas APIs definem build e testes, publicação de imagem no Amazon ECR e atualização do deployment no Amazon EKS quando a integração AWS está habilitada e configurada.

A validação completa por push ficou pendente. Após a substituição dos nós do EKS pelo Auto Scaling, o bootstrap dos novos nós recebeu HTTP 403 em `ec2:DescribeInstances` por uma negação explícita de uma política da organização no Learner Lab. Os nós substitutos não ingressaram no cluster. O teste local de rolling restart demonstra a troca de pods com a imagem atual.
