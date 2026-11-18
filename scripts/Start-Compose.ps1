param([string]$DockerPath = '', [switch]$WithNotifications)
. "$PSScriptRoot/Common.ps1"
$docker = Resolve-FcgTool 'docker' $DockerPath
Invoke-Fcg $docker @('info','--format','{{.OSType}}')
& "$PSScriptRoot/Initialize-Local.ps1"
Push-Location $FcgRoot
try {
    $services = @('users-api','catalog-api','payments-api')
    if ($WithNotifications) { $services += 'notifications-function' }
    foreach ($service in $services) {
        Invoke-Fcg $docker @('compose','--env-file','.env','--env-file','.local/compose.env','build',$service)
    }
    $composeArgs = @('compose','--env-file','.env','--env-file','.local/compose.env')
    if ($WithNotifications) { $composeArgs += @('--profile','notifications') }
    Invoke-Fcg $docker ($composeArgs + @('up','--no-build','-d'))
} finally { Pop-Location }
$gatewayPort = if ($env:GATEWAY_PORT) { $env:GATEWAY_PORT } else { 8000 }
$grafanaPort = if ($env:GRAFANA_PORT) { $env:GRAFANA_PORT } else { 3000 }
Write-Host "Gateway: http://localhost:$gatewayPort | Grafana: http://localhost:$grafanaPort"
Write-Host 'Compose serve para desenvolvimento. Use Start-Kubernetes.ps1 para demonstrar KEDA e escala a zero.'
