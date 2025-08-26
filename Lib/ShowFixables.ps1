function Show-Fixables {
	param ($results)
	foreach ($cue in $results | Where-Object { $_.Status -eq 'Fixable' }) {
		Write-Host "`n🔍 Processing: $($cue.Path)" -ForegroundColor Cyan
		foreach ($fix in $cue.Fixes) {
			Write-Host "❌ OLD: $($fix.Old)" -ForegroundColor DarkYellow
			Write-Host "✅ NEW: $($fix.New)" -ForegroundColor Yellow
		}
		if ($DryRun) {
			Write-Host "🧪 Dry-run mode — no changes saved." -ForegroundColor DarkCyan
		}
	}
}