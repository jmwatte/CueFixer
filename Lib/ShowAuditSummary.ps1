function Show-AuditSummary {
	param ($results)
	$clean = ($results | Where-Object { $_.Status -eq 'Clean' }).Count
	$fixable = ($results | Where-Object { $_.Status -eq 'Fixable' }).Count
	$unfixable = ($results | Where-Object { $_.Status -eq 'Unfixable' }).Count

	Write-Host "`n📊 Cue File Audit Summary:"
	Write-Host "✅ Clean: $clean"
	Write-Host "🛠 Fixable: $fixable"
	Write-Host "🛑 Manual Fix Needed: $unfixable"
}