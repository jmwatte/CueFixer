Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -AllowClobber
$findings = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning -ErrorAction SilentlyContinue
if ($findings -and $findings.Count -gt 0) {
    foreach ($i in $findings) { Write-Output ("{0}: {1} ({2}:{3})" -f $i.RuleName, $i.Message, $i.ScriptPath, $i.Line) }
    exit 1
}
else {
    Write-Output 'Analyzer OK'
    exit 0
}


