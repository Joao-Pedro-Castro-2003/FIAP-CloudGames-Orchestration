param([string]$DockerPath = '')
. "$PSScriptRoot/Common.ps1"
$docker = Resolve-FcgTool 'docker' $DockerPath
Push-Location $FcgRoot
try { Invoke-Fcg $docker @('compose','down') } finally { Pop-Location }
Write-Host 'Containers Compose parados. Volumes e dados preservados.'
