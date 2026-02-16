function Set-QueueCredentials {
    param (
        [string]$qDetails
    )

    if (-not $qDetails) {
        return
    }

    $qParts = $qDetails -split ':', 2
    if ($qParts.Length -ne 2) {
        Write-Warning "Invalid qDetails format. Expected username:password"
        return
    }

    $mqUser = $qParts[0]
    $mqPass = $qParts[1]
    $mqConfigPath = Join-Path $env:ProgramData 'mq-config.json'

    if (-not (Test-Path $mqConfigPath)) {
        Write-Warning "mq-config.json not found at $mqConfigPath"
        return
    }

    $content = Get-Content $mqConfigPath -Raw
    $content = $content -replace '\{USER_NAME\}', $mqUser
    $content = $content -replace '\{PASSWORD\}', $mqPass
    Set-Content -Path $mqConfigPath -Value $content -Encoding UTF8
    Write-Host "mq-config.json updated with provided queue credentials."
}

# Handle -qDetails parameter for mq-config.json
Set-QueueCredentials -qDetails $pp['qDetails']
