param([string]$KubectlPath = '')
. "$PSScriptRoot/Common.ps1"
$kubectl = Resolve-FcgTool 'kubectl' $KubectlPath
New-Item -ItemType Directory -Force -Path "$FcgRoot/.local" | Out-Null
foreach ($pair in @(@('kong','8000:8000'),@('grafana','3000:3000'),@('prometheus','9090:9090'),@('rabbitmq','15672:15672'))) {
    $service = $pair[0]
    $port = [int]($pair[1].Split(':')[0])
    if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) {
        Write-Host "Porta $port ja ocupada; nao abri outro encaminhamento. Confirme se e o ambiente correto."
        continue
    }
    $process = Start-Process -FilePath $kubectl -WindowStyle Hidden -PassThru -ArgumentList @(
        '--kubeconfig', ('"' + $FcgRoot + '/.local/kubeconfig"'), '--context','kind-fcg-fase3','-n','fiap-cloud-games','port-forward',"service/$service",$pair[1],'--address','127.0.0.1'
    ) -RedirectStandardOutput "$FcgRoot/.local/$service-forward.log" -RedirectStandardError "$FcgRoot/.local/$service-forward-error.log"
    Write-Host "${service}: processo $($process.Id), porta $port"
}
Write-Host 'Gateway http://localhost:8000 | Grafana http://localhost:3000 | Prometheus http://localhost:9090'
