# ---------------------------------------------------------------------------
# 6. Remove matching Bespoke Service registry nodes and re-sequence
#    (with backup to D:\Tmp before any modification)
# ---------------------------------------------------------------------------
$BespokeRoot    = "HKLM:\SOFTWARE\Wow6432Node\BespokeServices"
$BespokeRegPath = "HKLM\SOFTWARE\Wow6432Node\BespokeServices"   # reg.exe syntax (no colon)
$BackupDir      = "D:\Tmp"

# Names to remove - edit as needed
$NamesToRemove = @(
    "OrderServicePrimary",
    "BillingSvcPrimary"
)

Write-Host "`nProcessing Bespoke Services registry nodes..." -ForegroundColor Cyan

if (-not (Test-Path $BespokeRoot)) {
    Write-Warning "Registry path '$BespokeRoot' not found. Skipping registry cleanup."
}
else {
    # --- Backup the node BEFORE touching anything ---
    $backupOk = $false
    try {
        if (-not (Test-Path $BackupDir)) {
            Write-Host "Creating backup directory $BackupDir..." -ForegroundColor Yellow
            New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
        }

        $timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = Join-Path $BackupDir "BespokeServices_backup_$timestamp.reg"

        Write-Host "Backing up '$BespokeRegPath' to '$backupFile'..." -ForegroundColor Yellow

        # reg.exe export writes a standard .reg file (restorable via double-click
        # or 'reg import'). /y overwrites without prompting.
        $regProc = Start-Process -FilePath "reg.exe" `
                                 -ArgumentList "export", "`"$BespokeRegPath`"", "`"$backupFile`"", "/y" `
                                 -NoNewWindow -Wait -PassThru

        if ($regProc.ExitCode -eq 0 -and (Test-Path $backupFile)) {
            Write-Host "Backup created successfully." -ForegroundColor Green
            $backupOk = $true
        }
        else {
            Write-Warning "reg.exe export failed with exit code $($regProc.ExitCode)."
        }
    }
    catch {
        Write-Warning "Backup failed: $_"
    }

    if (-not $backupOk) {
        Write-Warning "Skipping registry cleanup because the backup could not be created."
    }
    else {
        try {
            $count = (Get-ItemProperty -Path $BespokeRoot -Name "Count").Count
            Write-Host "Current Count: $count" -ForegroundColor Cyan

            # --- Pass 1: delete nodes whose Name matches the removal list ---
            for ($i = 1; $i -le $count; $i++) {
                $nodePath = Join-Path $BespokeRoot "Bespoke Service $i"

                if (-not (Test-Path $nodePath)) {
                    Write-Warning "Expected node 'Bespoke Service $i' not found. Skipping."
                    continue
                }

                $nodeName = (Get-ItemProperty -Path $nodePath -Name "Name" -ErrorAction SilentlyContinue).Name

                if ($nodeName -and ($NamesToRemove -contains $nodeName)) {
                    Write-Host "  Deleting 'Bespoke Service $i' (Name: $nodeName)..." -ForegroundColor Yellow
                    Remove-Item -Path $nodePath -Recurse -Force
                    Write-Host "  Deleted." -ForegroundColor Green
                }
            }

            # --- Pass 2: re-sequence remaining nodes ---
            $newIndex = 0
            for ($i = 1; $i -le $count; $i++) {
                $oldPath = Join-Path $BespokeRoot "Bespoke Service $i"

                if (Test-Path $oldPath) {
                    $newIndex++
                    if ($i -ne $newIndex) {
                        $newName = "Bespoke Service $newIndex"
                        Write-Host "  Renaming 'Bespoke Service $i' -> '$newName'" -ForegroundColor Yellow
                        Rename-Item -Path $oldPath -NewName $newName
                    }
                }
            }

            # --- Update Count ---
            Set-ItemProperty -Path $BespokeRoot -Name "Count" -Value $newIndex
            Write-Host "Updated Count: $newIndex" -ForegroundColor Green
        }
        catch {
            Write-Warning "Registry cleanup failed: $_"
            Write-Warning "A backup exists at: $backupFile - restore with: reg import `"$backupFile`""
        }
    }
}
