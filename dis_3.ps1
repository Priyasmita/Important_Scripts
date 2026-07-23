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

Key points about the backup:

reg.exe export is the standard, safest way to back up a registry node. It produces a normal .reg file containing the node and everything beneath it — all 5 Bespoke Service subkeys, their Name values, everything. Note that reg.exe uses HKLM\... syntax (no :), which is why there are two path variables — $BespokeRoot for PowerShell cmdlets, $BespokeRegPath for reg.exe.
Restoring is trivial if something goes wrong:

   reg import "D:\Tmp\BespokeServices_backup_20260724_143012.reg"
(or just double-click the file). The catch block prints this exact command if the cleanup fails midway.

Timestamped filename (yyyyMMdd_HHmmss) — repeated runs never overwrite previous backups, so you keep a history in D:\Tmp.
Backup is a gate, not a courtesy — the $backupOk flag means: no successful backup → no registry modification at all. This is the behavior you want in an unattended choco install; better to skip the cleanup and log a warning than to modify the registry with no rollback path.
Exit code check + file existence check — reg.exe returns 0 on success; checking Test-Path $backupFile as well guards against edge cases (e.g., D: exists but is read-only or full, and reg.exe behaved oddly).
Start-Process -PassThru -Wait is used instead of just calling reg export ... inline so we get a reliable exit code via $regProc.ExitCode. A simpler inline alternative that also works in choco scripts:

powershell   & reg.exe export $BespokeRegPath $backupFile /y | Out-Null
   if ($LASTEXITCODE -eq 0) { $backupOk = $true }
Either is fine — pick one style and stay consistent.
One environmental check: the script assumes D: exists. If some target machines might not have a D: drive, add a Test-Path "D:\" check first and fall back to e.g. $env:TEMP so the backup gate doesn't block the cleanup on those machines.
