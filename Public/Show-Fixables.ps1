<#
.SYNOPSIS
Display fixable issues discovered by `Get-CueAudit`.

.DESCRIPTION
`Show-Fixables` accepts audit result objects (the output from `Get-CueAudit`)
and prints a human-friendly list of files with proposed fixes. Use the
`-DryRun` switch to include proposed replacement text.

.PARAMETER Results
Audit result objects produced by `Get-CueAudit`.

.PARAMETER DryRun
If specified, show proposed replacement content for fixable files.

.EXAMPLE
Get-CueAudit -Path . | Show-Fixables -DryRun
#>
function Show-Fixable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)] $Results,
        [switch]$DryRun
    )

    process {
        foreach ($cue in $Results | Where-Object { $_.Status -eq 'Fixable' }) {
            Write-Verbose "`n\ud83d\udd0d Processing: $($cue.Path)"
            foreach ($fix in $cue.Fixes) {
                Write-Verbose "\u274c OLD: $($fix.Old)"
                Write-Verbose "\u2705 NEW: $($fix.New)"
            }
            if ($DryRun) { Write-Verbose "\ud83e\uddea Dry-run mode \u2014 no changes saved." }
        }
    }
}










