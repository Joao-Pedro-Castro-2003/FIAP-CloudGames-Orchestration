# Ferramentas portateis em .local; sem instalacao global.
. "$PSScriptRoot/Common.ps1"
$toolDir = "$FcgRoot/.local/tools"
New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
function Install-Verified([string]$Name,[string]$Url,[string]$ChecksumUrl) {
    $file = "$toolDir/$Name.exe"
    if (!(Test-Path -LiteralPath $file)) { Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $file }
    $checksumBody = (Invoke-WebRequest -UseBasicParsing -Uri $ChecksumUrl).Content
    $checksumText = if ($checksumBody -is [byte[]]) { [Text.Encoding]::UTF8.GetString($checksumBody) } else { [string]$checksumBody }
    if ($checksumText -notmatch '[a-fA-F0-9]{64}') { throw "Checksum invalido para $Name" }
    $expected = $Matches[0]
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $expected) {
        throw "Arquivo $file nao corresponde ao checksum oficial. Remova apenas esse arquivo e tente novamente."
    }
}
Install-Verified 'kubectl' 'https://dl.k8s.io/release/v1.32.2/bin/windows/amd64/kubectl.exe' 'https://dl.k8s.io/release/v1.32.2/bin/windows/amd64/kubectl.exe.sha256'
Install-Verified 'kind' 'https://github.com/kubernetes-sigs/kind/releases/download/v0.27.0/kind-windows-amd64' 'https://github.com/kubernetes-sigs/kind/releases/download/v0.27.0/kind-windows-amd64.sha256sum'
Write-Host 'kubectl e kind locais verificados.'
