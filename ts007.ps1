# ---------------------------------------------------------------------------
# Remove matching Bespoke Service keys and re-sequence
#   Delete when:  Name contains "Primary"  AND  System = "G"
# ---------------------------------------------------------------------------
$BespokeRoot = "HKLM:\SOFTWARE\Wow6432Node\BespokeServices"

Write-Host "Processing Bespoke Services registry keys..." -ForegroundColor Cyan

if (-not (Test-Path $BespokeRoot)) {
    Write-Warning "Registry path '$BespokeRoot' not found. Skipping."
}
else {
    try {
        # Count is a STRING value - cast to int for the loop
        $countRaw = (Get-ItemProperty -Path $BespokeRoot -Name "Count").Count
        $count    = [int]$countRaw
        Write-Host "Current Count: $count" -ForegroundColor Cyan

        # --- Pass 1: delete keys matching BOTH conditions ---
        for ($i = 1; $i -le $count; $i++) {
            $keyPath = Join-Path $BespokeRoot "Bespoke Service $i"

            if (-not (Test-Path $keyPath)) {
                Write-Warning "Expected key 'Bespoke Service $i' not found. Skipping."
                continue
            }

            $props  = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
            $name   = $props.Name
            $system = $props.System

            # Name CONTAINS "Primary" (case-insensitive) AND System equals "G"
            if ($name -and ($name -like "*Primary*") -and ($system -ieq "G")) {
                Write-Host "  Deleting 'Bespoke Service $i' (Name: $name, System: $system)..." -ForegroundColor Yellow
                Remove-Item -Path $keyPath -Recurse -Force
                Write-Host "  Deleted." -ForegroundColor Green
            }
        }

        # --- Pass 2: re-sequence survivors so numbering is contiguous ---
        # Ascending walk; each survivor drops into the next free slot.
        # Renaming upward in order can never collide.
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

        # --- Update Count (write back as a STRING to match its value type) ---
        Set-ItemProperty -Path $BespokeRoot -Name "Count" -Value ([string]$newIndex)
        Write-Host "Updated Count: $newIndex" -ForegroundColor Green
    }
    catch {
        Write-Warning "Registry cleanup failed: $_"
    }
}
