# Gera credenciais locais uma unica vez; preserva .env existente.
. "$PSScriptRoot/Common.ps1"
function New-FcgSecret {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return ([BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
}
$utf8 = New-Object System.Text.UTF8Encoding $false
if (!(Test-Path -LiteralPath "$FcgRoot/.env")) {
    $storageKey = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((New-FcgSecret)))
    $storage = "DefaultEndpointsProtocol=http;AccountName=fcg;AccountKey=$storageKey;BlobEndpoint=http://azurite:10000/fcg;QueueEndpoint=http://azurite:10001/fcg;TableEndpoint=http://azurite:10002/fcg;"
    $lines = @("JWT_KEY=$(New-FcgSecret)", "RABBIT_PASSWORD=$(New-FcgSecret)",
        "ADMIN_EMAIL=admin@fcg.local", "ADMIN_PASSWORD=$(New-FcgSecret)",
        "GRAFANA_PASSWORD=$(New-FcgSecret)", 'PAYMENT_APPROVAL_RATE=100',
        "AZURITE_CONNECTION=$storage", "AZURITE_ACCOUNTS=fcg:$storageKey")
    [IO.File]::WriteAllLines("$FcgRoot/.env", $lines, $utf8)
}
$values = Read-FcgEnv
foreach ($name in @('JWT_KEY','RABBIT_PASSWORD','ADMIN_EMAIL','ADMIN_PASSWORD','GRAFANA_PASSWORD','PAYMENT_APPROVAL_RATE','AZURITE_CONNECTION','AZURITE_ACCOUNTS')) {
    if (!$values.ContainsKey($name) -or !$values[$name] -or $values[$name] -eq 'GENERATE_WITH_SCRIPT') {
        throw ".env existente incompleto: falta $name. Preserve uma copia antes de corrigir ou gerar novamente."
    }
}
if ($values.JWT_KEY -notmatch '^[a-zA-Z0-9_-]{32,}$') { throw 'JWT_KEY deve conter 32+ letras, numeros, _ ou -' }
if ($values.RABBIT_PASSWORD -notmatch '^[a-zA-Z0-9_-]+$') { throw 'RABBIT_PASSWORD deve conter apenas letras, numeros, _ ou -' }
New-Item -ItemType Directory -Force -Path "$FcgRoot/.local" | Out-Null
$kong = [IO.File]::ReadAllText("$FcgRoot/gateway/kong.template.yml").Replace('__JWT_KEY__', $values.JWT_KEY)
[IO.File]::WriteAllText("$FcgRoot/.local/kong.yml", $kong, $utf8)
$settings = @(
    "Jwt__Key=$($values.JWT_KEY)", "RabbitMq__Password=$($values.RABBIT_PASSWORD)",
    "RabbitMQConnection=amqp://fcg:$($values.RABBIT_PASSWORD)@rabbitmq.fiap-cloud-games.svc.cluster.local:5672",
    "RABBITMQ_DEFAULT_USER=fcg", "RABBITMQ_DEFAULT_PASS=$($values.RABBIT_PASSWORD)",
    "Bootstrap__AdminEmail=$($values.ADMIN_EMAIL)", "Bootstrap__AdminPassword=$($values.ADMIN_PASSWORD)",
    "GF_SECURITY_ADMIN_PASSWORD=$($values.GRAFANA_PASSWORD)",
    "Payment__ApprovalRate=$($values.PAYMENT_APPROVAL_RATE)",
    "AzureWebJobsStorage=$($values.AZURITE_CONNECTION)", "AZURITE_ACCOUNTS=$($values.AZURITE_ACCOUNTS)"
)
[IO.File]::WriteAllLines("$FcgRoot/.local/app.env", $settings, $utf8)
# Importar definicoes impede a criacao automatica do usuario padrao do RabbitMQ.
# Inclua o usuario local e suas permissoes no arquivo gerado, mantendo a senha fora do Git.
$salt = New-Object byte[] 4
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($salt) } finally { $rng.Dispose() }
$sha = [Security.Cryptography.SHA256]::Create()
try { $digest = $sha.ComputeHash([byte[]]($salt + [Text.Encoding]::UTF8.GetBytes($values.RABBIT_PASSWORD))) } finally { $sha.Dispose() }
$passwordHash = [Convert]::ToBase64String([byte[]]($salt + $digest))
$definitions = Get-Content -Raw -LiteralPath "$FcgRoot/rabbitmq/definitions.json" | ConvertFrom-Json
$definitions | Add-Member -NotePropertyName users -NotePropertyValue @(@{name='fcg';password_hash=$passwordHash;hashing_algorithm='rabbit_password_hashing_sha256';tags=@('administrator')}) -Force
$definitions | Add-Member -NotePropertyName permissions -NotePropertyValue @(@{user='fcg';vhost='/';configure='.*';write='.*';read='.*'}) -Force
[IO.File]::WriteAllText("$FcgRoot/.local/definitions.json", ($definitions | ConvertTo-Json -Depth 20), $utf8)
Write-Host 'Configuracao local pronta. Credenciais em .env (nao publicar).'
