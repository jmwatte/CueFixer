<#
.SYNOPSIS
Interactive review and application of repairs for .cue files in a folder.

.DESCRIPTION
`Invoke-InteractiveFix` groups incoming .cue file objects by folder, runs the
audit for each folder, shows fixable and unfixable issues, and offers an
interactive prompt to apply fixes, edit files, or retry analysis. This helper
is intended for interactive use only and delegates heavy lifting to the
`Get-CueAuditCore`, `Apply-Fixes` and Show-* helpers.

.PARAMETER CueFiles
An array of fileinfo-like objects (for example the output of `Get-ChildItem`) or
objects with a `FullName`/`DirectoryName` property. Accepts pipeline input.

.EXAMPLE
Get-ChildItem -Filter *.cue | Invoke-InteractiveFix

.NOTES
This function calls `Apply-Fixes` when the user chooses to apply changes. Use
`Get-CueAudit` and `Repair-CueFile -DryRun` for non-interactive automation.
#>
function Invoke-InteractiveFix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [System.Collections.ArrayList]$CueFiles
    )

    begin {
        if (-not $CueFiles) { return }
    }

    process {
        $groupedByFolder = $CueFiles | Group-Object { $_.DirectoryName }

        foreach ($group in $groupedByFolder) {
            Clear-Host
            $folderPath = $group.Name
            $filesInFolder = $group.Group

            Write-Host "`n📁 Folder: $folderPath" -ForegroundColor Cyan
            Write-Host "Found $($filesInFolder.Count) .cue file(s):"
            $filesInFolder | ForEach-Object { Write-Host "  - $($_.Name)" }

            # Analyze all files in folder
            $results = foreach ($cue in $filesInFolder) { Get-CueAuditCore -CueFilePath $cue.FullName }

            if ((($results | Where-Object { $_.Status -ne 'Clean' }) | Measure-Object).Count -eq 0) {
                Write-Host "✅ All files are clean. Skipping folder..." -ForegroundColor Green
                continue
            }

            $retry = $false
            do {
                Write-Host "`n🧪 Previewing changes (DryRun)..."
                Show-Fixables -Results $results -DryRun
                Show-Unfixables -Results $results

                $choice = Read-Host "`nApply changes? [A] Apply  [S] Skip  [E] Edit  [P] Play  [Q] Quit  [R] Retry (Enter = Skip)"

                switch ($choice.ToUpper()) {
                    '' { Write-Host "⏭️ Skipping folder..." -ForegroundColor DarkGray; $retry = $false }
                    'S' { Write-Host "⏭️ Skipping folder..." -ForegroundColor DarkGray; $retry = $false }
                    'A' {
                        Apply-Fixes -Results $results
                        $retry = $false
                    }
                    'E' {
                        Write-Host "📝 Opening first cue file in default editor..." -ForegroundColor Yellow
                        Open-InEditor $filesInFolder[0].FullName
                        $retry = $true
                    }
                    'P' {
                        Write-Host "🎵 Playing first cue file..." -ForegroundColor Yellow
                        Start-Process $filesInFolder[0].FullName
                        $retry = $true
                    }
                    'Q' { Write-Host "👋 Quitting script." -ForegroundColor Magenta; exit }
                    'R' {
                        Write-Host "🔁 Retrying analysis..." -ForegroundColor Cyan
                        # Re-analyze before retrying
                        $results = foreach ($cue in $filesInFolder) { Get-CueAuditCore -CueFilePath $cue.FullName }
                        $retry = $true
                    }
                    default { Write-Host "❓ Invalid choice. Please try again..." -ForegroundColor Red; $retry = $true }
                }
            } while ($retry)
        }
    }
}
