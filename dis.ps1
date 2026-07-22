<#
.SYNOPSIS
    Stops and disables services from List1 based on the -primaryServer parameter:
      -primaryServer y  -> services whose name ENDS WITH "Primary"
      -primaryServer n  -> all OTHER services in List1
    Closes the Services (services.msc / mmc) console first if it is open.

.EXAMPLE
    .\Disable-Services.ps1 -primaryServer y
    .\Disable-Services.ps1 -primaryServer N

.NOTES
    Must be run as Administrator.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("y", "n")]          # case-insensitive by default -> Y, y, N, n all accepted
    [string]$primaryServer
)

#Requires -RunAsAdministrator

# ---------------------------------------------------------------------------
# 1. DEFINE LIST 1 (edit service names as needed)
# ---------------------------------------------------------------------------
$List1 = @(
    "OrderServicePrimary",
    "OrderServiceSecondary",
    "BillingSvcPrimary",
    "BillingSvcBackup",
    "ReportingSvc"
)

# ---------------------------------------------------------------------------
# 2. FILTER THE LIST BASED ON THE PARAMETER
# ---------------------------------------------------------------------------
if ($primaryServer -ieq "y") {
    Write-Host "primaryServer = y -> targeting services ending with 'Primary'" -ForegroundColor Cyan
    $ServicesToDisable = $List1 | Where-Object { $_ -like "*Primary" }
}
else {
    Write-Host "primaryServer = n -> targeting services NOT ending with 'Primary'" -ForegroundColor Cyan
    $ServicesToDisable = $List1 | Where-Object { $_ -notlike "*Primary" }
}

if (-not $ServicesToDisable) {
    Write-Warning "No services in List1 match the selection. Nothing to do."
    exit 0
}

Write-Host "Services selected: $($ServicesToDisable -join ', ')" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 3. Close the Services console (mmc.exe hosting services.msc) if open
# ---------------------------------------------------------------------------
Write-Host "`nChecking for open Services console..." -ForegroundColor Cyan

$mmcProcesses = Get-Process -Name "mmc" -ErrorAction SilentlyContinue

foreach ($proc in $mmcProcesses) {
    try {
        if ($proc.MainWindowTitle -match "Services") {
            Write-Host "Closing Services console (PID $($proc.Id))..." -ForegroundColor Yellow
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Warning "Could not inspect/close process $($proc.Id): $_"
    }
}

# ---------------------------------------------------------------------------
# 4. Stop and disable each selected service
# ---------------------------------------------------------------------------
foreach ($svcName in $ServicesToDisable) {

    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue

    if (-not $svc) {
        Write-Warning "Service '$svcName' not found on this system. Skipping."
        continue
    }

    Write-Host "`nProcessing service: $($svc.DisplayName) ($svcName)" -ForegroundColor Cyan

    # Stop the service if it's running
    if ($svc.Status -ne 'Stopped') {
        try {
            Write-Host "  Stopping..." -ForegroundColor Yellow
            Stop-Service -Name $svcName -Force -ErrorAction Stop
            Write-Host "  Stopped." -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed to stop $svcName : $_"
        }
    }
    else {
        Write-Host "  Already stopped." -ForegroundColor Green
    }

    # Disable the service
    try {
        Write-Host "  Disabling..." -ForegroundColor Yellow
        Set-Service -Name $svcName -StartupType Disabled -ErrorAction Stop
        Write-Host "  Disabled." -ForegroundColor Green
    }
    catch {
        Write-Warning "  Failed to disable $svcName : $_"
    }
}

# ---------------------------------------------------------------------------
# 5. Summary (choco-safe: Out-String + Write-Host)
# ---------------------------------------------------------------------------
Write-Host "`n--- Summary ---" -ForegroundColor Cyan

$summary = Get-Service -Name $ServicesToDisable -ErrorAction SilentlyContinue |
    Select-Object DisplayName, Name, Status, StartType |
    Format-Table -AutoSize | Out-String -Width 200

Write-Host $summary.Trim()
Write-Host "Done." -ForegroundColor Green
