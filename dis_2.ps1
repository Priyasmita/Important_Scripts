# ---------------------------------------------------------------------------
# 6. Remove matching Bespoke Service registry nodes and re-sequence
# ---------------------------------------------------------------------------
$BespokeRoot = "HKLM:\SOFTWARE\Wow6432Node\BespokeServices"

# Names to remove - edit as needed (compare against each node's 'Name' value)
$NamesToRemove = @(
    "OrderServicePrimary",
    "BillingSvcPrimary"
)

Write-Host "`nProcessing Bespoke Services registry nodes..." -ForegroundColor Cyan

if (-not (Test-Path $BespokeRoot)) {
    Write-Warning "Registry path '$BespokeRoot' not found. Skipping registry cleanup."
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

        # --- Pass 2: re-sequence remaining nodes so numbering is contiguous ---
        # Walk 1..original count in order; rename each surviving node to the
        # next sequential slot. Renaming upward in ascending order can never
        # collide, because lower slots are already settled or were deleted.
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

        # --- Update Count with the number of nodes remaining ---
        Set-ItemProperty -Path $BespokeRoot -Name "Count" -Value $newIndex
        Write-Host "Updated Count: $newIndex" -ForegroundColor Green
    }
    catch {
        Write-Warning "Registry cleanup failed: $_"
    }
}


How it works:
Pass 1 — deletion. Loops 1..Count, reads each node's Name value, and if it's in $NamesToRemove, deletes the whole node with Remove-Item -Recurse -Force (-Recurse removes any subkeys/values beneath it). This leaves gaps — e.g., after deleting #3 you have 1, 2, 4, 5.
Pass 2 — re-sequencing. Walks the original range in ascending order, keeping a $newIndex counter of survivors. Each surviving node gets renamed to Bespoke Service $newIndex if it's not already in the right slot. With 1, 2, 4, 5: nodes 1 and 2 stay put ($i -eq $newIndex), 4 → 3, 5 → 4. Renaming preserves the node's entire contents — all values and subkeys move with it, so Name and anything else inside is untouched.
Why ascending order can't collide: by the time you rename node 4 to slot 3, slot 3 is guaranteed empty — it was either deleted or its occupant already settled into a lower slot. This is the same reason your requirement said "shift the next node up."
Count update. $newIndex naturally ends as the survivor count, written back with Set-ItemProperty.
Two things to verify for your environment:

The path. You said "Wow64Node" — the actual registry key is spelled Wow6432Node, so I used HKLM:\SOFTWARE\Wow6432Node\BespokeServices. Adjust if your node genuinely lives elsewhere (or under HKCU).
32-bit vs 64-bit process gotcha. Wow6432Node is where the OS redirects 32-bit apps that write to HKLM:\SOFTWARE. If your Chocolatey/PowerShell runs 32-bit, then addressing HKLM:\SOFTWARE\Wow6432Node\... explicitly gets redirected again and can miss the key. Chocolatey normally runs 64-bit PowerShell, where the explicit path works fine — but if you hit "path not found" unexpectedly, that redirection is the first thing to check (a 32-bit process should address it as plain HKLM:\SOFTWARE\BespokeServices).
Count value type. Set-ItemProperty writes the value using its existing registry type. If Count is a REG_DWORD (typical), passing the int is fine. If for some reason it's REG_SZ (a string), use -Value "$newIndex" instead.
