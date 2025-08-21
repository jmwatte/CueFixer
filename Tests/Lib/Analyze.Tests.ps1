. '$PSScriptRoot/../Lib/Analyze.ps1'

Describe 'Get-AuditMetrics' {
    It 'calculates counts and percentages correctly' {
        $results = @(
            @{ Path = 'a.cue'; Status = 'Clean' }
            @{ Path = 'b.cue'; Status = 'Fixable' }
            @{ Path = 'c.cue'; Status = 'Fixable' }
            @{ Path = 'd.cue'; Status = 'Unfixable' }
        )

        $metrics = Get-AuditMetrics -Results $results

        $metrics.Clean | Should -Be 1
        $metrics.Fixable | Should -Be 2
        $metrics.Unfixable | Should -Be 1
        $metrics.Total | Should -Be 4
        $metrics.FixablePercent | Should -Be 50
    }
}
