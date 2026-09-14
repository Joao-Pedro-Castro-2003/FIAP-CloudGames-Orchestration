# Roteiro do vídeo — até 20 minutos

Execute os testes previamente; não grave senhas ou tokens completos. Use Kubernetes com KEDA.

1. **0–2 min:** mostre o diagrama e explique Kong (porta única), bancos, fila, função e monitoramento.
2. **2–5 min:** rode Test-Flow.ps1 e mostre os casos 401/403 e a compra promocional. Explique que só o gateway recebe tráfego de negócio.
3. **5–9 min:** mostre o RabbitMQ, as filas function-user-created/function-payment-processed e os logs da função no Grafana. Use os IDs de .local/last-test.json para correlacionar pedido e notificação.
4. **9–12 min:** acompanhe os Pods e o ScaledObject. Depois de processar, mostre zero réplicas; execute Test-Flow novamente e observe a função voltar. Pode existir uma espera de inicialização.
5. **12–15 min:** abra o dashboard FCG: latência p95, total por status, requisições por segundo, erros e cache.
6. **15–17 min:** explique as avaliações no MongoDB e demonstre X-Cache MISS → HIT → MISS após alterar. Ressalte a expiração e o comportamento sem Redis.
7. **17–19 min:** mostre testes automatizados, repos separados e manifestos da função e da orquestração.
8. **19–20 min:** explique que a solução roda localmente sem nuvem, e mencione os limites de estudo documentados.

## Pagamento rejeitado

Execute .\scripts\Test-Rejection.ps1. O script muda temporariamente a taxa de aprovação para zero, verifica o pedido rejeitado sem liberar o jogo, confere as notificações e a escala a zero, e restaura a configuração original. Decisões de pedidos já processados permanecem iguais.

## Conferir antes de gravar

- Test-Flow, Test-Observability e Test-Serverless concluídos.
- Dashboard carregado e recebendo dados.
- Logs das duas notificações disponíveis.
- Nenhum container antigo de NotificationsAPI participa da arquitetura.
- Conta inicial e credenciais não aparecem na gravação.
- Links dos repositórios e da documentação preparados por você para a entrega acadêmica.
