param([string]$BaseUrl = 'http://localhost:8000')
. "$PSScriptRoot/Common.ps1"
$values = Read-FcgEnv
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/auth/login" -ContentType application/json -Body (
    @{email=$values.ADMIN_EMAIL; password=$values.ADMIN_PASSWORD} | ConvertTo-Json
)
$headers = @{Authorization="Bearer $($login.token)"}
function Write-Game($method, $path, $name) {
    Invoke-RestMethod -Method $method -Uri "$BaseUrl$path" -Headers $headers -ContentType application/json -Body (
        @{name=$name; price=42} | ConvertTo-Json
    )
}
function Wait-Search($term, $expectedName, $expectedId = $game.id) {
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        $query = [Uri]::EscapeDataString($term)
        try {
            $hits = Invoke-RestMethod -Uri "$BaseUrl/search?q=$query" -Headers $headers
            if ($expectedName -and $hits -and $hits[0].name -eq $expectedName -and $hits[0].id -eq $expectedId) { return }
            if (!$expectedName -and !($hits | Where-Object id -eq $game.id)) { return }
        } catch {
            if (!$_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 503) { throw }
        }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Resultado esperado não encontrado para '$term'."
}

$suffix = [Guid]::NewGuid().ToString('N').Substring(0,8)
$name = "Galaxia$suffix"
$game = Write-Game Post '/api/games' $name
try {
    Wait-Search "Galaxai$suffix" $name
    $similar = Write-Game Post '/api/games' "Galaxai$suffix"
    try {
        Wait-Search "Galaxai$suffix" $similar.name $similar.id
        $results = Invoke-RestMethod -Uri "$BaseUrl/search?q=Galaxai$suffix" -Headers $headers
        if (!($results | Where-Object id -eq $game.id)) {
            throw 'A busca por relevância deveria incluir também a correspondência aproximada.'
        }
    } finally {
        Invoke-RestMethod -Method Delete -Uri "$BaseUrl/api/games/$($similar.id)" -Headers $headers
    }
    $updatedName = "Nebulosa$suffix"
    $null = Write-Game Put "/api/games/$($game.id)" $updatedName
    Wait-Search "Nebluosa$suffix" $updatedName
    Wait-Search $name ''
} finally {
    Invoke-RestMethod -Method Delete -Uri "$BaseUrl/api/games/$($game.id)" -Headers $headers
}
Wait-Search $updatedName ''
Write-Host 'Busca validada: tolerância a erro, relevância, edição e remoção.'
