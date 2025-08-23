param(
    [string]$CsvPath = 'C:\Temp\cue-audit-d-drive.csv',
    [int]$Sample = 10
)

Import-Module "$PSScriptRoot\..\CueFixer.psd1" -Force

# Ensure library functions are available when running this script directly (dot-source)
$lib = Join-Path $PSScriptRoot '..' | Join-Path -ChildPath 'Lib'
$reporting = Join-Path $lib 'Reporting.ps1'
if (Test-Path $reporting) { . $reporting }

if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV not found: $CsvPath"
    exit 2
}

$data = Import-Csv -Path $CsvPath
$summary = Get-AuditSummary -Results $data

# Print JSON summary
Write-Host "Summary (JSON):"
$summary | ConvertTo-Json -Depth 3

# Print grouped counts
Write-Host "\nCounts by Status:"
$data | Group-Object -Property Status | ForEach-Object { Write-Host ("{0}: {1}" -f $_.Name, $_.Count) }

# Print sample Fixable files
Write-Host "\nFirst $Sample Fixable files:"
$fixables = $data | Where-Object { ($_.'Status' -as [string]) -match 'fixable' } | Select-Object -First $Sample -ExpandProperty Path
if ($fixables) { $fixables | ForEach-Object { Write-Host $_ } } else { Write-Host "(none)" }

# Print sample Unfixable files
Write-Host "\nFirst $Sample Unfixable files:"
$unfix = $data | Where-Object { ($_.'Status' -as [string]) -match 'unfixable' } | Select-Object -First $Sample -ExpandProperty Path
if ($unfix) { $unfix | ForEach-Object { Write-Host $_ } } else { Write-Host "(none)" }

# Exit with non-zero if there are unfixable files
if ($summary.Unfixable -gt 0) { exit 3 }
