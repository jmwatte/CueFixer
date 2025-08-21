Import-Module PSScriptAnalyzer
$findings = Invoke-ScriptAnalyzer -Path . -Recurse -ErrorAction SilentlyContinue
$findings | ConvertTo-Json -Depth 6 | Out-File tools/pssa-findings.json -Encoding UTF8
if ($findings -and $findings.Count -gt 0) {
    $groups = $findings | Group-Object -Property RuleName | Sort-Object -Property Count -Descending
    foreach ($g in $groups) { Write-Output "$($g.Name): $($g.Count)" }
}
else { Write-Output 'No PSScriptAnalyzer findings in repository' }



