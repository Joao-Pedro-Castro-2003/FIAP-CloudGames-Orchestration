param([string]$BaseUrl = 'http://localhost:8000')
. "$PSScriptRoot/Common.ps1"
$kubectl = "$FcgRoot/.local/tools/kubectl.exe"
$values = Read-FcgEnv
$body = @{email=$values.ADMIN_EMAIL; password=$values.ADMIN_PASSWORD} | ConvertTo-Json
$job = Start-Job -ArgumentList $BaseUrl,$body -ScriptBlock {
    param($url,$loginBody)
    while ($true) {
        try {
            $login = Invoke-RestMethod -Method Post -Uri "$url/api/auth/login" -Body $loginBody -ContentType application/json -TimeoutSec 5
            $null = Invoke-RestMethod -Uri "$url/api/games" -Headers @{Authorization="Bearer $($login.token)"} -TimeoutSec 5
            $true
        } catch {
            $false
        }
        Start-Sleep -Milliseconds 500
    }
}
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    $initial = @()
    while (!$initial.Count -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 500
        $initial = @(Receive-Job $job)
    }
    if (!$initial.Count -or $initial -contains $false) { throw 'Falha ao iniciar o tráfego do ensaio.' }
    foreach ($service in 'users-api','catalog-api') {
        Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','restart',"deployment/$service")
        Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','status',"deployment/$service",'--timeout=300s')
    }
    $samples = @(Receive-Job $job)
    if (!$samples.Count -or $samples -contains $false) { throw 'Falha HTTP ou ausência de amostras durante o rollout.' }
    Write-Host "$($samples.Count) ciclos de login e catálogo concluídos durante o rollout."
} finally {
    Stop-Job $job
    Remove-Job $job
}
