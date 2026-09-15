. "$PSScriptRoot/Common.ps1"
& "$PSScriptRoot/Test-Observability.ps1"
$kubectl = Resolve-FcgTool 'kubectl'
Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','wait','--for=condition=Ready','scaledobject/notifications-function','--timeout=180s')
Write-Host 'Aguardando a funcao voltar a zero apos processar as mensagens (ate 240s)...'
Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','wait','--for=jsonpath={.spec.replicas}=0','deployment/notifications-function','--timeout=240s')
Write-Host 'Escala a zero confirmada. Execute Test-Flow.ps1 novamente para demonstrar a reativacao por mensagens.'
