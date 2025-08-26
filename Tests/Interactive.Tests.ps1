Describe 'Invoke-InteractiveFixImpl' {
    BeforeAll {
    Write-Output "[BeforeAll] Dot-sourcing libs"
    # Provide lightweight stubs for external IO operations so tests can mock/override them
    function Open-InEditor { }
    function Show-Fixable { param($Results) $null = $Results }
    function Show-Unfixable { param($Results) $null = $Results }
    function Show-AuditSummary { }
    function Clear-Host { }

    # load the library implementations directly
        . (Join-Path $PSScriptRoot '..\Lib\Interactive.ps1')
        . (Join-Path $PSScriptRoot '..\Lib\Analyze.ps1')
        . (Join-Path $PSScriptRoot '..\Lib\ApplyFixes.ps1')
    Write-Output "[BeforeAll] Done dot-sourcing"
    }

    It 'applies fixes when user chooses A' {
    Write-Verbose "Starting test It block"
        # Prepare a fake cue file object
        $cue = [PSCustomObject]@{ FullName = 'C:\tmp\album.cue'; DirectoryName = 'C:\tmp'; Name = 'album.cue' }

        # Stub Get-CueAuditCore to return a fixable result
        Mock -CommandName Get-CueAuditCore -MockWith {
            Write-Verbose "Get-CueAuditCore mock called"
            return ,([PSCustomObject]@{ Path = 'C:\tmp\album.cue'; Status = 'Fixable'; Fixes = @([PSCustomObject]@{ Old='x'; New='y' }); UpdatedLines = @('a'); NeedsStructureFix = $false })
        }

    # Provide a lightweight local implementation to capture calls (shadows the lib impl)
    $script:applied = $false
    function Invoke-ApplyFixImpl { param($Results) $null = $Results; $script:applied = $true }

        # Stub interactive operations
    Mock -CommandName Read-Host -MockWith { Write-Verbose "Read-Host mock called"; 'A' }
        Mock -CommandName Open-InEditor -MockWith { }
        Mock -CommandName Start-Process -MockWith { }

        # Run the impl with an arraylist input
        $list = [System.Collections.ArrayList]::new(); $list.Add($cue) | Out-Null
    Write-Verbose "Invoking implementation"
    Invoke-InteractiveFixImpl -CueFiles $list
    Write-Verbose "Returned from implementation"

    # Assert that the apply function was called
    $script:applied | Should -BeTrue
    }
}









