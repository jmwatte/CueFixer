function Invoke-ApplyFixImpl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [object]$Results,
        [switch]$DryRun
    )
    # Accept a single object or a collection; normalize to an array for internal processing.
    $Results = @($Results)

    foreach ($cue in $Results | Where-Object { $_.Status -eq 'Fixable' }) {
        $backupPath = "$($cue.Path).bak"
        Copy-Item -LiteralPath $cue.Path -Destination $backupPath -Force

        # If structural issues were flagged, run the structure fixer first and re-analyze
        if ($cue.NeedsStructureFix) {
            # Use canonical library fixer implementation
            Set-CueFileStructureImpl -CueFilePath $cue.Path

            # re-analyze using the core analyzer implementation to avoid wrapper recursion
            $cue = Get-CueAuditCoreImpl -CueFilePath $cue.Path
            if ($cue.Status -eq 'Unfixable') {
                Write-Verbose "⚠️ After structure fix the file is unfixable: $($cue.Path)"
                continue
            }
        }

        foreach ($fix in $cue.Fixes) {
            if ($fix.Old -match 'FILE\s+"(.+?)"\s+(WAVE|MP3|FLAC)' -and -not [System.IO.Path]::GetExtension($matches[1])) {
                $baseName = $matches[1]
                $type = $matches[2]

                $matchedFile = Get-ChildItem -LiteralPath (Split-Path $cue.Path) -File | Where-Object {
                    $_.BaseName -ieq $baseName -and ($validAudioExts -contains $_.Extension.ToLower())
                } | Select-Object -First 1

                if ($matchedFile) {
                    $correctedLine = "FILE `"$($matchedFile.Name)`" $type"
                    $cue.Fixes += [PSCustomObject]@{ Old = $fix.Old; New = $correctedLine }
                    $cue.UpdatedLines = $cue.UpdatedLines | ForEach-Object {
                        if ($_ -eq $fix.Old) { $correctedLine } else { $_ }
                    }
                    Write-Verbose "🛠 Autofixed missing extension in: $($cue.Path)"
                }
                else {
                    Write-Verbose "❌ Could not autofix missing extension for: $($cue.Path)"
                }
            }
        }

        # Apply content fixes (if any) using the new content fixer and FileIO
        if ($cue.UpdatedLines) {
            $fixResult = Get-CueContentFixImpl -CueFilePath $cue.Path -UpdatedLines $cue.UpdatedLines

            if ($fixResult.Changed) {
                # Note: previously this code checked $global:DryRun; prefer the local -DryRun parameter for explicit behavior
                if ($DryRun) {
                    Write-Verbose "🧪 Dry-run: would write fixes to $($cue.Path)"
                }
                else {
                    # Use centralized IO helper to write file and optionally backup
                    Save-FileWithBackup -Path $cue.Path -Content $fixResult.FixedText -Backup:$true | Out-Null
                    Write-Verbose "🔧 Fixed: $($cue.Path)"
                }
            }
            else {
                Write-Verbose "ℹ️ No content changes necessary for $($cue.Path)"
            }
        }
        else {
            Write-Verbose "ℹ️ No content fixes to apply for $($cue.Path)"
        }
    }
}

# New singular-approved wrapper and singular implementation shim.
function Invoke-ApplyFix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [object]$Results,
        [switch]$DryRun
    )
    # Normalize single object or collection to an array for downstream impl.
    $Results = @($Results)
    # Prefer the singular implementation shim.
    Invoke-ApplyFixImpl -Results $Results -DryRun:$DryRun
}

# (implementation is defined above as the canonical singular impl)








