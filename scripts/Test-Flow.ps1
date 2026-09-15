param([string]$BaseUrl = 'http://localhost:8000')
. "$PSScriptRoot/Common.ps1"
$values = Read-FcgEnv
function Send-Api([string]$Method,[string]$Path,$Body=$null,[string]$Token='') {
    $options = @{ Uri="$BaseUrl$Path"; Method=$Method; UseBasicParsing=$true; TimeoutSec=30 }
    if ($Token) { $options.Headers = @{ Authorization="Bearer $Token" } }
    if ($null -ne $Body) { $options.Body = ConvertTo-Json $Body -Depth 10; $options.ContentType = 'application/json' }
    return Invoke-WebRequest @options
}
function Expect-Status([int]$Expected,[scriptblock]$Action) {
    try { $response = & $Action; $actual = [int]$response.StatusCode }
    catch {
        if (!($_.Exception.PSObject.Properties.Name -contains 'Response') -or !$_.Exception.Response) { throw }
        $actual = [int]$_.Exception.Response.StatusCode
    }
    if ($actual -ne $Expected) { throw "HTTP esperado $Expected, recebido $actual" }
}
Expect-Status 401 { Send-Api GET '/api/games' }
Expect-Status 401 { Send-Api GET '/api/games' $null 'invalid-token' }
Expect-Status 404 { Send-Api GET '/metrics' }
$stamp = [Guid]::NewGuid().ToString('N').Substring(0,12)
$signup = @{ name='Jogador Teste'; email="jogador-$stamp@fcg.local"; password="Teste-$stamp-123"; isAdmin=$false }
$adminSignup = $signup.Clone(); $adminSignup.isAdmin = $true
Expect-Status 400 { Send-Api POST '/api/users' $adminSignup }
$user = (Send-Api POST '/api/users' $signup).Content | ConvertFrom-Json
if ($user.isAdmin) { throw 'Cadastro publico elevou privilegios' }
$login = (Send-Api POST '/api/auth/login' @{email=$signup.email; password=$signup.password}).Content | ConvertFrom-Json
$admin = (Send-Api POST '/api/auth/login' @{email=$values.ADMIN_EMAIL; password=$values.ADMIN_PASSWORD}).Content | ConvertFrom-Json
Expect-Status 403 { Send-Api POST '/api/games' @{name='Proibido';price=10} $login.token }
$game = (Send-Api POST '/api/games' @{name="Jogo $stamp";price=100} $admin.token).Content | ConvertFrom-Json
$null = Send-Api POST '/api/promotions' @{gameId=$game.id;discountPercent=20;startsAt=[DateTime]::UtcNow.AddDays(-1).ToString('o');endsAt=[DateTime]::UtcNow.AddDays(1).ToString('o');active=$true} $admin.token
$order = (Send-Api POST "/api/games/$($game.id)/purchase" $null $login.token).Content | ConvertFrom-Json
$deadline = [DateTime]::UtcNow.AddSeconds(120)
do {
    Start-Sleep -Seconds 2
    $status = (Send-Api GET "/api/orders/$($order.id)" $null $login.token).Content | ConvertFrom-Json
} while ($status.status -eq 'Pending' -and [DateTime]::UtcNow -lt $deadline)
if ($status.status -eq 'Pending') { throw 'Pagamento nao processado em 120s. Verifique RabbitMQ e PaymentsAPI.' }
if ($status.price -ne 80) { throw "Compra nao aplicou promocao: $($status.price)" }
# Windows PowerShell 5.1 returns the JSON array as one pipeline object.
# Assign it directly before enumerating, avoiding a nested array.
$library = (Send-Api GET '/api/library/me' $null $login.token).Content | ConvertFrom-Json
$ownedGames = @($library | Where-Object { $null -ne $_ -and $_.id -eq $game.id })
if ($status.status -eq 'Approved' -and $ownedGames.Count -eq 0) { throw 'Jogo aprovado ausente da biblioteca' }
if ($status.status -eq 'Rejected' -and $ownedGames.Count -gt 0) { throw 'Jogo rejeitado foi adicionado a biblioteca' }
$reviewPath = "/api/games/$($game.id)/reviews"
$null = Send-Api PUT "$reviewPath/me" @{rating=5;comment='Excelente';tags=@('aventura')} $login.token
$first = Send-Api GET $reviewPath $null $login.token
$second = Send-Api GET $reviewPath $null $login.token
if ($first.Headers['X-Cache'] -ne 'MISS' -or $second.Headers['X-Cache'] -ne 'HIT') { throw 'Esperado MISS seguido de HIT no Redis' }
$null = Send-Api PUT "$reviewPath/me" @{rating=4;comment='Atualizado';tags=@('coop')} $login.token
$updated = Send-Api GET $reviewPath $null $login.token
if ($updated.Headers['X-Cache'] -ne 'MISS') { throw 'Cache nao foi invalidado' }
$reviews = $updated.Content | ConvertFrom-Json
if (@($reviews.items).Count -ne 1 -or $reviews.items[0].rating -ne 4) { throw 'MongoDB nao atualizou a avaliacao' }
$summary = @{time=[DateTime]::UtcNow.ToString('o');userId=$user.id;gameId=$game.id;orderId=$order.id;payment=$status.status;price=$status.price;cache='MISS/HIT/invalidation OK'}
$summary | ConvertTo-Json | Set-Content -LiteralPath "$FcgRoot/.local/last-test.json" -Encoding UTF8
Write-Host "Fluxo aprovado: gateway, autorizacao, compra ($($status.status)), MongoDB e Redis."
Write-Host 'Confira a notificacao e a escala a zero no Grafana/Kubernetes. IDs em .local/last-test.json.'
