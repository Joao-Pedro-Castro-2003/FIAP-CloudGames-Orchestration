Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$FcgRoot = Split-Path $PSScriptRoot -Parent
function Resolve-FcgTool([string]$Name, [string]$ExplicitPath = '') {
    if ($ExplicitPath) {
        if (!(Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) { throw "Executavel nao encontrado: $ExplicitPath" }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    $found = Get-Command $Name -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    $locations = @("$FcgRoot/.local/tools/$Name.exe","$env:ProgramFiles\Docker\Docker\resources\bin\$Name.exe",
        "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin\$Name.exe")
    foreach ($location in $locations) { if (Test-Path -LiteralPath $location) { return $location } }
    throw "$Name nao encontrado. Abra Docker Desktop ou informe -DockerPath / -KubectlPath com o caminho do executavel."
}
function Invoke-Fcg([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Comando falhou ($LASTEXITCODE): $Executable $($Arguments -join ' ')" }
}
function Read-FcgEnv {
    $values = @{}
    foreach ($line in Get-Content -LiteralPath "$FcgRoot/.env") {
        if ($line -match '^([A-Z_]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
    }
    return $values
}

function Invoke-FcgCluster([string]$Kubectl, [string[]]$Arguments) {
    Invoke-Fcg $Kubectl (@("--kubeconfig", "$FcgRoot/.local/kubeconfig", "--context", "kind-fcg-fase3") + $Arguments)
}
