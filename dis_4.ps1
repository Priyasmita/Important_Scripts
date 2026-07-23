$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
$TargetScript = "D:\Scripts\StartupTasks.ps1"      # the .ps1 file to modify
$BackupDir    = "D:\Tmp"

# Lines containing any of these service names will be commented out
$ServiceNames = @(
    "OrderServicePrimary",
    "BillingSvcPrimary"
)

Write-Host "Processing script file: $TargetScript" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. Validate the target file exists
# ---------------------------------------------------------------------------
if (-not (Test-Path $TargetScript -PathType Leaf)) {
    Write-Warning "Target script '$TargetScript' not found. Nothing to do."
    return
}

# ---------------------------------------------------------------------------
# 2. Back up the file before modifying it
# ---------------------------------------------------------------------------
if (-not (Test-Path $BackupDir)) {
    New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
}

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$baseName   = [System.IO.Path]::GetFileNameWithoutExtension($TargetScript)
$backupFile = Join-Path $BackupDir "${baseName}_backup_$timestamp.ps1"

Copy-Item -Path $TargetScript -Destination $backupFile -Force
Write-Host "Backup created: $backupFile" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3. Read the file, comment out matching lines
# ---------------------------------------------------------------------------
$lines         = Get-Content -Path $TargetScript
$modifiedLines = New-Object System.Collections.Generic.List[string]
$changeCount   = 0

foreach ($line in $lines) {

    $trimmed = $line.TrimStart()

    # Does this line mention any of the service names?
    $matchedService = $ServiceNames | Where-Object { $line -match [regex]::Escape($_) } | Select-Object -First 1

    if ($matchedService -and -not $trimmed.StartsWith("#")) {
        # Comment it out, preserving original leading whitespace
        $indent = $line.Substring(0, $line.Length - $trimmed.Length)
        $modifiedLines.Add("$indent# $trimmed")
        $changeCount++
        Write-Host "  Commented (matched '$matchedService'): $trimmed" -ForegroundColor Yellow
    }
    else {
        # Unchanged: no match, or already a comment
        $modifiedLines.Add($line)
    }
}

# ---------------------------------------------------------------------------
# 4. Write the file back (only if something changed)
# ---------------------------------------------------------------------------
if ($changeCount -eq 0) {
    Write-Host "No matching lines found. File left unchanged." -ForegroundColor Green
    return
}

Set-Content -Path $TargetScript -Value $modifiedLines -Encoding UTF8
Write-Host "`n$changeCount line(s) commented out in '$TargetScript'." -ForegroundColor Green
Write-Host "Original preserved at: $backupFile" -ForegroundColor Cyan
Write-Host "Done." -ForegroundColor Green


Indentation preservation. $line -replace '^(\s*)', '$1# ' captures the leading whitespace and puts the # after it, so     Start-Service Foo becomes     # Start-Service Foo rather than #    Start-Service Foo. Keeps the file readable and diff-friendly.
Idempotency. The '^\s*#' check means running the package twice doesn't produce # # Start-Service Foo. This matters because choco packages get re-run — choco upgrade, reinstalls, forced installs. A script that isn't idempotent corrupts the file a little more each time.
Encoding is specified explicitly. This is a genuine trap: Set-Content's default encoding is ASCII in Windows PowerShell 5.1 but UTF-8 no BOM in PowerShell 7. If the target .ps1 contains any non-ASCII character (a curly quote, an accented name, a box-drawing character in output text), the 5.1 default silently mangles it into ?. Since choco typically runs under 5.1, -Encoding UTF8 is the safe call. Note this writes a BOM under 5.1 — fine for .ps1 files, which PowerShell handles either way.
Backup is a hard gate. No backup, no modification — throw rather than proceeding. You're editing someone's script in place; there's no undo otherwise.
Two things to consider for your case:

Matching is a plain substring test. -like "*$svc*" will match the service name anywhere in the line — including inside a comment, a string literal, or as part of a longer name. If ReportingSvc is in your list and the file also has ReportingSvcBackup, the latter's lines get commented too. If that's a problem, tighten it to a word-boundary regex:

powershell   $escaped = [regex]::Escape($svc)
   if ($line -match "\b$escaped\b") { $matchedService = $svc; break }

Multi-line statements. Commenting a single line inside a pipeline or a param() block can break the script's syntax — e.g. commenting the middle line of:

powershell   Get-Service |
       Where-Object { $_.Name -eq 'ReportingSvc' } |
       Stop-Service
leaves a dangling pipe. If your target file has that shape, add a syntax check after writing:
powershell   $errors = $null
   [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$errors) | Out-Null
   if ($errors) {
       Write-Warning "Modified file has syntax errors - restoring backup."
       Copy-Item $backupFile $ScriptPath -Force
       throw "Commenting produced invalid PowerShell. Original restored."
   }
