# Base helpers and contract for heuristics

function Invoke-HeuristicStub {
    param(
        [hashtable]$Input
    )
    # Example stub: return no opinion
    return @()
}

function Get-HeuristicName {
    param([string]$Path)
    return [System.IO.Path]::GetFileNameWithoutExtension($Path)
}
