param([string]$PrometheusUrl='http://localhost:9090',[string]$GrafanaUrl='http://localhost:3000')
. "$PSScriptRoot/Common.ps1"
$values = Read-FcgEnv
$last = Get-Content -Raw -LiteralPath "$FcgRoot/.local/last-test.json" | ConvertFrom-Json
$auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("admin:$($values.GRAFANA_PASSWORD)"))
$headers = @{ Authorization="Basic $auth" }
$deadline = [DateTime]::UtcNow.AddSeconds(180)
do {
    $targets = Invoke-RestMethod -Uri "$PrometheusUrl/api/v1/targets" -TimeoutSec 15
    $healthy = @($targets.data.activeTargets | Where-Object { $_.health -eq 'up' })
    if ($healthy.Count -ge 3) { break }
    Start-Sleep -Seconds 5
} while ([DateTime]::UtcNow -lt $deadline)
if ($healthy.Count -lt 3) { throw 'Prometheus nao consegue consultar as tres APIs' }
foreach ($id in @("welcome:$($last.userId)","payment:$($last.orderId)")) {
    $query = [Uri]::EscapeDataString('{service="notifications-function"} |= "' + $id + '"')
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    do {
        $logs = Invoke-RestMethod -Headers $headers -Uri "$GrafanaUrl/api/datasources/proxy/uid/loki/loki/api/v1/query_range?query=$query&limit=20" -TimeoutSec 15
        if (@($logs.data.result).Count -gt 0) { break }
        Start-Sleep -Seconds 5
    } while ([DateTime]::UtcNow -lt $deadline)
    if (@($logs.data.result).Count -eq 0) { throw "Log da funcao nao encontrado para $id" }
}
Write-Host 'Prometheus coleta as tres APIs e Loki contem logs das duas notificacoes.'
