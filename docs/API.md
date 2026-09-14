# API pelo gateway

Base: `http://localhost:8000`. Envie JSON com `Content-Type: application/json`.

| Método | Caminho | Permissão |
|---|---|---|
| POST | /api/users | Público; cria apenas usuário comum |
| POST | /api/auth/login | Público |
| GET | /api/users/{id} | Admin |
| GET | /api/games | Autenticado |
| POST | /api/games | Admin |
| PUT / DELETE | /api/games/{id} | Admin |
| POST | /api/promotions | Admin |
| POST | /api/games/{id}/purchase | Autenticado |
| GET | /api/orders/{id} | Dono do pedido |
| GET | /api/library/me | Autenticado |
| GET | /api/games/{id}/reviews?page=1 | Autenticado |
| PUT | /api/games/{id}/reviews/me | Autenticado |

Nas rotas protegidas: `Authorization: Bearer <token>`. Login retorna `{"token":"..."}`. O gateway não publica /metrics, /health nem Swagger dos serviços.

Cadastro:
```json
{"name":"Jogador","email":"jogador@example.com","password":"UmaSenha123!","isAdmin":false}
```
Envio de isAdmin=true recebe 400. O administrador é inicializado por configuração local somente em banco vazio.

Login:
```json
{"email":"jogador@example.com","password":"UmaSenha123!"}
```

Criar jogo:
```json
{"name":"Aventura FCG","price":100}
```

Promoção: gameId, discountPercent (1–100), startsAt/endsAt em UTC e active. O maior desconto ativo é aplicado; datas finais devem ser posteriores às iniciais. Listagem e compra usam a mesma regra de arredondamento monetário.

A compra retorna 202 e o ID do pedido. Consulte /api/orders/{id} até Pending mudar para Approved ou Rejected. Pagamentos são simulados; a taxa inicial é 100% para uma demonstração reproduzível.

Avaliação:
```json
{"rating":5,"comment":"Gostei da aventura","tags":["aventura","coop"]}
```

Uma avaliação por jogo/usuário, atualizada por PUT. A identidade vem do JWT, não do corpo. São permitidos até 10 tags de 40 caracteres e comentário de até 2000 caracteres. Listagem paginada, 20 itens por página. X-Cache informa MISS, HIT ou BYPASS; páginas posteriores à primeira vão diretamente ao MongoDB.

Mudar preço, cadastrar promoções ou criar avaliações não substitui a necessidade de token de usuário com a permissão correta. Os scripts de demonstração já fazem cadastro, login e propagação dos tokens automaticamente.
