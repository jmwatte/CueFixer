try {
    $repo = Resolve-Path -LiteralPath '.' | Select-Object -ExpandProperty Path
    $cue = Join-Path $repo 'Tests\Fixtures\album.cue'
    $entry = [PSCustomObject]@{ Path = $cue; Status = 'Unfixable' }
    $tmp = Join-Path $env:TEMP 'cuefixer-test-unfixable.clixml'
    $entry | Export-Clixml -Path $tmp -Force
    Write-Host "Wrote test CLIXML: $tmp"
    $helper = Join-Path $repo '.vscode\invoke-interactive-unfixables.ps1'
    Write-Host "Invoking helper: $helper -InputFile $tmp"
    if (Test-Path $helper) {
        & $helper -InputFile $tmp
    } else {
        Write-Host "Helper script not found: $helper" -ForegroundColor Red
        exit 2
    }
} catch {
    Write-Host 'ERROR:' $_.Exception.Message -ForegroundColor Red
    exit 2
}
