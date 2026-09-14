. "$PSScriptRoot/Common.ps1"
$kubectl = Resolve-FcgTool 'kubectl'
try {
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','set','env','deployment/payments-api','Payment__ApprovalRate=0')
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','status','deployment/payments-api','--timeout=180s')
    & "$PSScriptRoot/Test-Flow.ps1"
    $last = Get-Content -Raw -LiteralPath "$FcgRoot/.local/last-test.json" | ConvertFrom-Json
    if ($last.payment -ne 'Rejected') { throw 'O pagamento deveria ser rejeitado' }
    & "$PSScriptRoot/Test-Serverless.ps1"
} finally {
    # Remove a substituicao temporaria e volta ao valor do Secret local.
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','set','env','deployment/payments-api','Payment__ApprovalRate-')
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','status','deployment/payments-api','--timeout=180s')
}
Write-Host 'Pagamento rejeitado validado, sem liberar o jogo. Configuracao original restaurada.'
