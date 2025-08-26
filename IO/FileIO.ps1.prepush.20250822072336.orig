function Get-FileContentRaw {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)] [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) { throw "Path not found: $Path" }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function Save-FileWithBackup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$Content,
        [switch]$Backup
    )

    if ($PSCmdlet.ShouldProcess($Path, 'Write fixed cue file')) {
        if ($Backup) {
            Copy-Item -LiteralPath $Path -Destination "$Path.bak" -Force
        }
        Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8 -Force
        return $true
    }

    return $false
}

