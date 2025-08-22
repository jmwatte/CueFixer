function New-CueModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string] $FilePath,
        [Parameter()]
        [string] $Status = 'Unknown'
    )

    return [PSCustomObject]@{
        Path = $FilePath
        Status = $Status
    }
}






