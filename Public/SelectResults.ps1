# Example to paste into session or add to a helper file
function Select-Unfixables {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)][string]$ClixmlPath
    )

    begin {
        $buffer = @()
    }

    process {
        # If the caller piped in result objects, collect them here
        if (-not $PSBoundParameters.ContainsKey('ClixmlPath')) {
            $buffer += $_
        }
    }

    end {
        if ($PSBoundParameters.ContainsKey('ClixmlPath')) {
            if (-not (Test-Path -LiteralPath $ClixmlPath)) { throw "CLIXML not found: $ClixmlPath" }
            $buffer = Import-Clixml -Path $ClixmlPath -ErrorAction Stop
        }

        foreach ($r in ($buffer | Where-Object { $_.Status -ieq 'Unfixable' })) {
            $p = $r.Path
            if ($p -and (Test-Path -LiteralPath $p)) {
                # Emit actual FileInfo so consumers can use real filesystem info
                Write-Output (Get-Item -LiteralPath $p -ErrorAction SilentlyContinue)
            } else {
                # Emit a small FileInfo-like PSCustomObject for missing files
                Write-Output [PSCustomObject]@{
                    FullName      = $p
                    DirectoryName = if ($p) { Split-Path -Path $p -Parent } else { $null }
                    Name          = if ($p) { [System.IO.Path]::GetFileName($p) } else { $null }
                }
            }
        }
    }
}

function Select-Fixables {
[CmdletBinding()]
    param(
        [Parameter(Position=0)][string]$ClixmlPath
    )

    begin {
        $buffer = @()
    }

    process {
        # If the caller piped in result objects, collect them here
        if (-not $PSBoundParameters.ContainsKey('ClixmlPath')) {
            $buffer += $_
        }
    }

    end {
        if ($PSBoundParameters.ContainsKey('ClixmlPath')) {
            if (-not (Test-Path -LiteralPath $ClixmlPath)) { throw "CLIXML not found: $ClixmlPath" }
            $buffer = Import-Clixml -Path $ClixmlPath -ErrorAction Stop
        }

        foreach ($r in ($buffer | Where-Object { $_.Status -ieq 'Fixable' })) {
            $p = $r.Path
            if ($p -and (Test-Path -LiteralPath $p)) {
                # Emit actual FileInfo so consumers can use real filesystem info
                Write-Output (Get-Item -LiteralPath $p -ErrorAction SilentlyContinue)
            } else {
                # Emit a small FileInfo-like PSCustomObject for missing files
                Write-Output [PSCustomObject]@{
                    FullName      = $p
                    DirectoryName = if ($p) { Split-Path -Path $p -Parent } else { $null }
                    Name          = if ($p) { [System.IO.Path]::GetFileName($p) } else { $null }
                }
            }
        }
    }
}

function Select-Cleans {
[CmdletBinding()]
    param(
        [Parameter(Position=0)][string]$ClixmlPath
    )

    begin {
        $buffer = @()
    }

    process {
        # If the caller piped in result objects, collect them here
        if (-not $PSBoundParameters.ContainsKey('ClixmlPath')) {
            $buffer += $_
        }
    }

    end {
        if ($PSBoundParameters.ContainsKey('ClixmlPath')) {
            if (-not (Test-Path -LiteralPath $ClixmlPath)) { throw "CLIXML not found: $ClixmlPath" }
            $buffer = Import-Clixml -Path $ClixmlPath -ErrorAction Stop
        }

        foreach ($r in ($buffer | Where-Object { $_.Status -ieq 'Clean' })) {
            $p = $r.Path
            if ($p -and (Test-Path -LiteralPath $p)) {
                # Emit actual FileInfo so consumers can use real filesystem info
                Write-Output (Get-Item -LiteralPath $p -ErrorAction SilentlyContinue)
            } else {
                # Emit a small FileInfo-like PSCustomObject for missing files
                Write-Output [PSCustomObject]@{
                    FullName      = $p
                    DirectoryName = if ($p) { Split-Path -Path $p -Parent } else { $null }
                    Name          = if ($p) { [System.IO.Path]::GetFileName($p) } else { $null }
                }
            }
        }
    }
}