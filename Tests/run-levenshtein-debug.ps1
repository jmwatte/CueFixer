. .\..\Lib\Heuristics\FuzzyNameMatch.ps1
try {
    $d = Get-LevenshteinDistance -s 'track01' -t 'completelydifferent'
    Write-Host "DIST=$d"
} catch {
    Write-Host 'EXCEPTION:'
    $_ | Format-List -Force
}
