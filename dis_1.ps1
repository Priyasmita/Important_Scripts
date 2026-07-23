$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# 1. READ AND VALIDATE PACKAGE PARAMETERS
# ---------------------------------------------------------------------------
$pp = Get-PackageParameters

if (-not $pp['primaryServer']) {
    throw "Missing required package parameter 'primaryServer'. Usage: choco install <pkg> --params `"'/primaryServer:y'`""
}

$primaryServer = $pp['primaryServer'].Trim()

if ($primaryServer -notmatch '^(y|n)$') {
    throw "Invalid value '$primaryServer' for primaryServer. Must be 'y' or 'n' (case-insensitive)."
}

Write-Host "primaryServer = $primaryServer" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 2. DEFINE LIST 1
# ---------------------------------------------------------------------------
$List1 = @(
    "OrderServicePrimary",
    "OrderServiceSecondary",
    "BillingSvcPrimary",
    "BillingSvcBackup",
    "ReportingSvc"
)

# ---------------------------------------------------------------------------
# 3. FILTER BASED ON THE PARAMETER
# ---------------------------------------------------------------------------
if ($primaryServer -ieq 'y') {
    Write-Host "Targeting services ending with 'Primary'" -ForegroundColor Cyan
    $ServicesToDisable = $List1 | Where-Object { $_ -like "*Primary" }
}
else {
    Write-Host "Targeting services NOT ending with 'Primary'" -ForegroundColor Cyan
    $ServicesToDisable = $List1 | Where-Object { $_ -notlike "*Primary" }
}

if (-not $ServicesToDisable) {
    Write-Warning "No services in List1 match the selection. Nothing to do."
    return
}

Write-Host "Services selected: $($ServicesToDisable -join ', ')" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 4. Close the Services console (mmc.exe) if open
# ---------------------------------------------------------------------------
Write-Host "`nChecking for open Services console..." -ForegroundColor Cyan

$mmcProcesses = Get-Process -Name "mmc" -ErrorAction SilentlyContinue

foreach ($proc in $mmcProcesses) {
    try {
        if ($proc.MainWindowTitle -match "Services") {
            Write-Host "Closing Services console (PID $($proc.Id))..." -ForegroundColor Yellow
            Stop-Process -Id $proc.Id -Force
        }
    }
    catch {
        Write-Warning "Could not inspect/close process $($proc.Id): $_"
    }
}

# ---------------------------------------------------------------------------
# 5. Stop and disable each selected service
# ---------------------------------------------------------------------------
foreach ($svcName in $ServicesToDisable) {

    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue

    if (-not $svc) {
        Write-Warning "Service '$svcName' not found on this system. Skipping."
        continue
    }

    Write-Host "`nProcessing service: $($svc.DisplayName) ($svcName)" -ForegroundColor Cyan

    if ($svc.Status -ne 'Stopped') {
        try {
            Write-Host "  Stopping..." -ForegroundColor Yellow
            Stop-Service -Name $svcName -Force
            Write-Host "  Stopped." -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed to stop $svcName : $_"
        }
    }
    else {
        Write-Host "  Already stopped." -ForegroundColor Green
    }

    try {
        Write-Host "  Disabling..." -ForegroundColor Yellow
        Set-Service -Name $svcName -StartupType Disabled
        Write-Host "  Disabled." -ForegroundColor Green
    }
    catch {
        Write-Warning "  Failed to disable $svcName : $_"
    }
}

# ---------------------------------------------------------------------------
# 6. Summary (choco-safe)
# ---------------------------------------------------------------------------
Write-Host "`n--- Summary ---" -ForegroundColor Cyan

$summary = Get-Service -Name $ServicesToDisable -ErrorAction SilentlyContinue |
    Select-Object DisplayName, Name, Status, StartType |
    Format-Table -AutoSize | Out-String -Width 200

Write-Host $summary.Trim()
Write-Host "Done." -ForegroundColor Green
