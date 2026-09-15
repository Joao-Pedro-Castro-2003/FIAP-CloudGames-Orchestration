. "$PSScriptRoot/Common.ps1"
$kubectl = Resolve-FcgTool 'kubectl'
$values = Read-FcgEnv
$auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("fcg:$($values.RABBIT_PASSWORD)"))
$headers = @{Authorization="Basic $auth"}
$queue = 'fcg-persistence-' + [Guid]::NewGuid().ToString('N')
$queueUri = "http://localhost:15672/api/queues/%2F/$queue"
function Wait-Broker {
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    do {
        try { $null = Invoke-RestMethod 'http://localhost:15672/api/overview' -Headers $headers -TimeoutSec 5; return }
        catch { Start-Sleep -Seconds 3 }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'RabbitMQ nao ficou disponivel em 120s'
}
Wait-Broker
$created = $false
try {
    $body = @{durable=$true;auto_delete=$false;arguments=@{}} | ConvertTo-Json
    $null = Invoke-RestMethod $queueUri -Method Put -Headers $headers -ContentType 'application/json' -Body $body
    $created = $true
    $body = @{properties=@{delivery_mode=2};routing_key=$queue;payload=$queue;payload_encoding='string'} | ConvertTo-Json
    $published = Invoke-RestMethod 'http://localhost:15672/api/exchanges/%2F/amq.default/publish' -Method Post -Headers $headers -ContentType 'application/json' -Body $body
    if (!$published.routed) { throw 'Mensagem de verificacao nao foi enfileirada' }
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','restart','deployment/rabbitmq')
    Invoke-FcgCluster $kubectl @('-n','fiap-cloud-games','rollout','status','deployment/rabbitmq','--timeout=180s')
    Wait-Broker
    $body = @{count=1;ackmode='ack_requeue_false';encoding='auto';truncate=1000} | ConvertTo-Json
    $messages = @(Invoke-RestMethod "$queueUri/get" -Method Post -Headers $headers -ContentType 'application/json' -Body $body)
    if ($messages.Count -ne 1 -or $messages[0].payload -ne $queue) { throw 'Mensagem persistente nao foi recuperada apos reinicio' }
    Write-Host 'RabbitMQ preservou a fila e a mensagem persistente apos recriar o Pod.'
} finally {
    if ($created) { $null = Invoke-RestMethod $queueUri -Method Delete -Headers $headers }
}
