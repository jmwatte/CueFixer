function Show-Unfixables {
	param ($results)
	foreach ($cue in $results | Where-Object { $_.Status -eq 'Unfixable' }) {
		Write-Host "`n🛑 Manual Fix Needed: $($cue.Path)" -ForegroundColor Red
	}
}