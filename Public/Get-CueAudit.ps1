function Get-CueAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$Path,
        [switch]$Recurse
    )

    process {
        foreach ($p in $Path) {
            $files = if ($Recurse) { Get-ChildItem -LiteralPath $p -Filter *.cue -File -Recurse } else { Get-ChildItem -LiteralPath $p -Filter *.cue -File }
            foreach ($f in $files) {
                Get-CueAuditCore -CueFilePath $f.FullName
            }
        }
    }
}

Export-ModuleMember -Function Get-CueAudit
