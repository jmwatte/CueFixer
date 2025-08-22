Describe 'New-CueModel' {
    It 'creates a model with given path and status' {
        . $PSScriptRoot/../../Lib/Models.ps1

        $m = New-CueModel -FilePath 'x.cue' -Status 'Fixable'

        $m.Path | Should -Be 'x.cue'
        $m.Status | Should -Be 'Fixable'
    }
}



