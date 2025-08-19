function Repair-CueFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)] [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Throw "Path not found: $Path"
    }

    $res = Set-CueFileStructure -CueFilePath $Path

    if ($res.Changed) {
        Write-Verbose "Changes detected for $Path"
        # create backup and write changes
        Copy-Item -LiteralPath $Path -Destination "$Path.bak" -Force
        Set-Content -LiteralPath $Path -Value $res.FixedText -Encoding UTF8 -Force
        Write-Output @{ Path = $Path; Changed = $true }
    }
    else {
        Write-Output @{ Path = $Path; Changed = $false }
    }
}
