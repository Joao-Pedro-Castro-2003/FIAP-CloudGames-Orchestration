param([string]$DockerPath = '', [switch]$WithNotifications)
. "$PSScriptRoot/Common.ps1"
$docker = Resolve-FcgTool 'docker' $DockerPath
$osType = & $docker info --format '{{.OSType}}'
if ($LASTEXITCODE -ne 0 -or $osType -ne 'linux') { throw 'Abra Docker Desktop com Linux containers antes de continuar.' }
& "$PSScriptRoot/Initialize-Local.ps1"
& "$PSScriptRoot/Install-LocalTools.ps1"
$kubectl = "$FcgRoot/.local/tools/kubectl.exe"
$kind = "$FcgRoot/.local/tools/kind.exe"
$previousPath = $env:PATH
$env:PATH = "$(Split-Path $docker -Parent);$env:PATH"
Push-Location $FcgRoot
try {
    $services = @('users-api','catalog-api','payments-api')
    if ($WithNotifications) { $services += 'notifications-function' }
    foreach ($service in $services) {
        Invoke-Fcg $docker @('compose','--env-file','.env','--env-file','.local/compose.env','build',$service)
    }
    $clusters = & $kind get clusters
    if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel consultar clusters kind' }
    if ($clusters -notcontains 'fcg-fase3') {
        foreach ($port in @(8000,3000,9090,15672)) {
            if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) {
                throw "Porta $port ocupada. Se iniciou Compose, execute Stop-Compose.ps1 antes de mudar para Kubernetes."
            }
        }
        Invoke-Fcg $kind @('create','cluster','--name','fcg-fase3','--config','kind.yml','--kubeconfig',"$FcgRoot/.local/kubeconfig",'--wait','180s')
    } else {
        Invoke-Fcg $kind @('export','kubeconfig','--name','fcg-fase3','--kubeconfig',"$FcgRoot/.local/kubeconfig")
    }

    foreach ($service in $services) {
        $image = "fiap-${service}:fase3"
        Invoke-Fcg $kind @('load','docker-image','--name','fcg-fase3',$image)
    }
    Invoke-FcgCluster $kubectl @('apply','--server-side','-f','https://github.com/kedacore/keda/releases/download/v2.18.1/keda-2.18.1.yaml')
    foreach ($component in @('keda-operator','keda-admission','keda-metrics-apiserver')) {
        Invoke-FcgCluster $kubectl @('-n','keda','rollout','status',"deployment/$component",'--timeout=600s')
    }
    Invoke-FcgCluster $kubectl @('apply','-k','.')
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','status','statefulset/postgres','--timeout=600s')
    # Reload the local API images and the gateway configuration.
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','restart','deployment/users-api','deployment/catalog-api','deployment/payments-api','deployment/kong')
    foreach ($service in @('rabbitmq','mongo','redis','azurite','users-api','catalog-api','payments-api','kong','prometheus','loki','grafana','alloy')) {
        Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','status',"deployment/$service",'--timeout=600s')
    }
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','status','statefulset/opensearch','--timeout=600s')
    if ($WithNotifications) {
        Invoke-FcgCluster $kubectl @('apply','-f','../FIAP-NotificationsFunction/infra/k8s/notifications.yml')
    }
} finally { Pop-Location; $env:PATH = $previousPath }
Write-Host 'Gateway http://localhost:8000 | Grafana http://localhost:3000'
Write-Host 'Execute Test-Flow.ps1, Test-Observability.ps1 e Test-Serverless.ps1.'
