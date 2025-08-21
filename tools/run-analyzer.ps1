Import-Module PSScriptAnalyzer
$findings = Invoke-ScriptAnalyzer -Path .\Lib -Recurse -ErrorAction SilentlyContinue
# Write JSON output for historical record
$findings | ConvertTo-Json -Depth 6 | Out-File -FilePath tools/pssa-lib-findings.json -Encoding UTF8
if ($findings -and $findings.Count -gt 0) {
    foreach ($f in $findings) {
        Write-Output "$($f.RuleName): $($f.Message) ($($f.ScriptName):$($f.Line))"
    }
}
else {
    Write-Output 'No PSScriptAnalyzer findings in Lib/'
}
Write-Output 'ANALYZER_LIB_DONE'


