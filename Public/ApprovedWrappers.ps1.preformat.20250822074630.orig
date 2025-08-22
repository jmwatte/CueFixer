<#
.SYNOPSIS
Approved-verb wrappers for legacy functions to satisfy PSScriptAnalyzer and provide a stable public API.
#>

function Set-CueFileStructure {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$CueFilePath
    )

    process {
        if ($PSCmdlet.ShouldProcess($CueFilePath, 'Normalize .cue file structure')) {
            # Call legacy implementation
            # Prefer the canonical implementation if present
            if (Get-Command -Name Set-CueFileStructureImpl -ErrorAction SilentlyContinue) {
                Set-CueFileStructureImpl -CueFilePath $CueFilePath
            }
            else {
                Fix-CueFileStructure -CueFilePath $CueFilePath
            }
        }
    }
}

function Get-CueAuditCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$CueFilePath
    )

    process {
    # Thin shim to library analyzer implementation
    Get-CueAuditCoreImpl -CueFilePath $CueFilePath
    }
}

function Invoke-ApplyFix {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [object]$Results,
        [switch]$DryRun
    )

    process {
        # Prefer the canonical library implementation
        if (Get-Command -Name Invoke-ApplyFixImpl -ErrorAction SilentlyContinue) {
            Invoke-ApplyFixImpl -Results $Results -DryRun:$DryRun
        }
        else {
            Invoke-ApplyFixImpl -Results $Results -DryRun:$DryRun
        }
    }
}

# Back-compat plural wrapper — call the singular public function.
    # NOTE: plural `Invoke-ApplyFixes` removed; canonical public command is `Invoke-ApplyFix`.







