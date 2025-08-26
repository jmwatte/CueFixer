# Base helpers and contract for heuristics

function Invoke-HeuristicStub {
    param(
        [hashtable]$InputData
    )
    # Reference the input to avoid PSScriptAnalyzer 'ReviewUnusedParameter' warnings
    # and avoid using the automatic variable name 'Input'
    $null = $InputData
    # Example stub: return no opinion
    return @()
}

function Get-HeuristicName {
    param([string]$Path)
    return [System.IO.Path]::GetFileNameWithoutExtension($Path)
}









