param([string]$DockerPath = '')
. "$PSScriptRoot/Common.ps1"
$docker = Resolve-FcgTool 'docker' $DockerPath
Invoke-Fcg $docker @('info','--format','{{.OSType}}')
& "$PSScriptRoot/Initialize-Local.ps1"
Push-Location $FcgRoot
try {
    foreach ($service in @('users-api','catalog-api','payments-api','notifications-function')) {
        Invoke-Fcg $docker @('compose','build',$service)
    }
    Invoke-Fcg $docker @('compose','up','--no-build','-d')
} finally { Pop-Location }
Write-Host 'Gateway: http://localhost:8000 | Grafana: http://localhost:3000'
Write-Host 'Compose serve para desenvolvimento. Use Start-Kubernetes.ps1 para demonstrar KEDA e escala a zero.'
