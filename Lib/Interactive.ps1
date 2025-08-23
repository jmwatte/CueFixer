function Invoke-InteractiveFixImpl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [System.Collections.ArrayList]$CueFiles
    )

    begin {
        # Tracing (write JSON events when CUEFIXER_TRACE=1)
        $traceEnabled = $false
        if ($env:CUEFIXER_TRACE -eq '1') {
            $traceEnabled = $true
            $logPath = Join-Path $env:TEMP 'cuefixer-interactive-log.json'
            if (Test-Path $logPath) { Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue }
            function Log-Event { param($obj) if ($traceEnabled) { $obj | ConvertTo-Json -Depth 6 | Add-Content -LiteralPath $logPath } }
        }

        if (-not $CueFiles) { return }
    }

    process {
        $groupedByFolder = $CueFiles | Group-Object { $_.DirectoryName }

        foreach ($group in $groupedByFolder) {
            Clear-Host
            $folderPath = $group.Name
            $filesInFolder = $group.Group

            Write-Verbose "`n📁 Folder: $folderPath"
            Write-Verbose "Found $($filesInFolder.Count) .cue file(s):"
            $filesInFolder | ForEach-Object { Write-Verbose "  - $($_.Name)" }

            # Analyze all files in folder
            $results = foreach ($cue in $filesInFolder) { Get-CueAuditCore -CueFilePath $cue.FullName }
            if ($traceEnabled) { Log-Event @{ Event='FolderStart'; Folder=$folderPath; Files=($filesInFolder | ForEach-Object { $_.Name }) } }

            if ((($results | Where-Object { $_.Status -ne 'Clean' }) | Measure-Object).Count -eq 0) {
                Write-Verbose "✅ All files are clean. Skipping folder..."
                continue
            }

            $retry = $false
            do {
                Write-Verbose "`n🧪 Previewing changes (DryRun)..."
                    Show-Fixable -Results $results -DryRun
                    Show-Unfixable -Results $results
                    if ($traceEnabled) { Log-Event @{ Event='Preview'; Folder=$folderPath; ResultsCount=($results.Count) } }

                # Support non-interactive tests via CUEFIXER_TEST_CHOICE environment variable
                if ($env:CUEFIXER_TEST_CHOICE) {
                    $choice = $env:CUEFIXER_TEST_CHOICE
                } else {
                    $choice = Read-Host "`nApply changes? [A] Apply  [S] Skip  [E] Edit  [P] Play  [Q] Quit  [R] Retry (Enter = Skip)"
                }
                if ($traceEnabled) { Log-Event @{ Event='Prompt'; Folder=$folderPath; Choice=$choice } }

                switch ($choice.ToUpper()) {
                    '' { Write-Verbose "⏭️ Skipping folder..."; $retry = $false }
                    'S' { Write-Verbose "⏭️ Skipping folder..."; $retry = $false }
                    'A' {
                        if ($traceEnabled) { Log-Event @{ Event='Branch'; Folder=$folderPath; Action='Apply' } }
                        Invoke-ApplyFix -Results $results
                        $retry = $false
                    }
                    'E' {
                        if ($traceEnabled) { Log-Event @{ Event='Branch'; Folder=$folderPath; Action='Edit'; File=$filesInFolder[0].FullName } }
                        Write-Verbose "📝 Opening first cue file in default editor..."
                        Open-InEditor $filesInFolder[0].FullName
                        $retry = $true
                    }
                    'P' {
                        if ($traceEnabled) { Log-Event @{ Event='Branch'; Folder=$folderPath; Action='Play'; File=$filesInFolder[0].FullName } }
                        Write-Verbose "🎵 Playing first cue file..."
                        Start-Process $filesInFolder[0].FullName
                        $retry = $true
                    }
                    'Q' { Write-Verbose "👋 Quitting script."; exit }
                    'R' {
                        if ($traceEnabled) { Log-Event @{ Event='Branch'; Folder=$folderPath; Action='Retry' } }
                        Write-Verbose "🔁 Retrying analysis..."
                        # Re-analyze before retrying
                        $results = foreach ($cue in $filesInFolder) { Get-CueAuditCore -CueFilePath $cue.FullName }
                        $retry = $true
                    }
                    default { Write-Verbose "❓ Invalid choice. Please try again..."; $retry = $true }
                }
            } while ($retry)
        }
    }
}










