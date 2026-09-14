. "$PSScriptRoot/Common.ps1"
$kubectl = Resolve-FcgTool 'kubectl'
$values = Read-FcgEnv
$last = Get-Content -Raw -LiteralPath "$FcgRoot/.local/last-test.json" | ConvertFrom-Json
function Get-AdminHeaders {
    $body = @{email=$values.ADMIN_EMAIL;password=$values.ADMIN_PASSWORD} | ConvertTo-Json
    $login = Invoke-RestMethod 'http://localhost:8000/api/auth/login' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 30
    return @{Authorization="Bearer $($login.token)"}
}
function Read-SavedReview($Headers) {
    $response = Invoke-WebRequest "http://localhost:8000/api/games/$($last.gameId)/reviews" -Headers $Headers -UseBasicParsing -TimeoutSec 30
    $reviews = $response.Content | ConvertFrom-Json
    if (@($reviews.items).Count -ne 1 -or $reviews.items[0].rating -ne 4) { throw 'Avaliacao persistida nao encontrada' }
    return $response
}
$headers = Get-AdminHeaders
$null = Read-SavedReview $headers
try {
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','scale','deployment/redis','--replicas=0')
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','wait','--for=delete','pod','-l','app=redis','--timeout=90s')
    $response = Read-SavedReview $headers
    if ($response.Headers['X-Cache'] -ne 'BYPASS') { throw 'Esperado BYPASS com Redis parado' }
    Write-Host 'Redis indisponivel: leitura preservada pelo MongoDB.'
} finally {
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','scale','deployment/redis','--replicas=1')
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','status','deployment/redis','--timeout=180s')
}
foreach ($app in @('mongo','users-api','catalog-api')) {
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','restart',"deployment/$app")
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','status',"deployment/$app",'--timeout=180s')
}
$headers = Get-AdminHeaders
$null = Read-SavedReview $headers
Write-Host 'Persistencia confirmada: login e avaliacao disponiveis apos recriar os Pods de MongoDB e APIs.'
