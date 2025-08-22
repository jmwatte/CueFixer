Describe 'Get-AuditSummary' {
    It 'summarizes results correctly' {
        . "$PSScriptRoot/../../Lib/Reporting.ps1"
        $samples = @(
            @{ Path = 'a.cue'; Status = 'Clean' }
            @{ Path = 'b.cue'; Status = 'Fixable' }
            @{ Path = 'c.cue'; Status = 'Fixable' }
            @{ Path = 'd.cue'; Status = 'Unfixable' }
        )

        $summary = Get-AuditSummary -Results $samples

        $summary.Clean | Should -Be 1
        $summary.Fixable | Should -Be 2
        $summary.Unfixable | Should -Be 1
    }
}
