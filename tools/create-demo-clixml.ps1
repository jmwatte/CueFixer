try {
    $repo = Resolve-Path -LiteralPath '.' | Select-Object -ExpandProperty Path
    $fixtures = Get-ChildItem -Path (Join-Path $repo 'Tests\Fixtures') -Filter *.cue -File -ErrorAction Stop
    $out = Join-Path $env:TEMP 'cuefixer-demo-unfixables.clixml'
    $arr = @()
    foreach ($f in $fixtures) { $arr += [PSCustomObject]@{ Path = $f.FullName; Status = 'Unfixable' } }
    $arr | Export-Clixml -Path $out -Force
    Write-Host "Wrote demo CLIXML: $out"
} catch {
    Write-Host 'ERROR:' $_.Exception.Message -ForegroundColor Red
    exit 2
}
