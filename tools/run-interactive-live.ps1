<#
.SYNOPSIS
  Safe runner to exercise the interactive implementation on real folders.

.DESCRIPTION
  Calls Invoke-InteractiveFixImpl directly with a list of .cue files found under
  the specified folders. By default this script is dry-run: it stubs the apply
  step so nothing is changed. Use -Live to allow editors/players to open, and
  -Apply to permit real fixes to be applied.

.PARAMETER Folders
  One or more folders to scan for .cue files. Defaults to the current directory.

.PARAMETER Live
  When set, allow launching editors and media players. Otherwise those actions
  are stubbed for safety.

.PARAMETER Apply
  When set, permit the script to call the real Apply step. Otherwise the
  apply action is stubbed (dry-run).

.PARAMETER Trace
  When set, enables internal tracing which writes JSON events to $env:TEMP\cuefixer-interactive-log.json

.EXAMPLE
  .\tools\run-interactive-live.ps1 -Folders 'C:\Music\Album' -Trace
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string[]]$Folders = @((Get-Location).Path),
    [switch]$Live,
    [switch]$Apply,
    [switch]$Trace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Ensure the interactive impl is loaded
$moduleRoot = Split-Path $PSScriptRoot -Parent
$interactive = Join-Path $moduleRoot 'Lib\Interactive.ps1'
if (Test-Path $interactive) { . $interactive } else { Write-Error "Missing implementation: $interactive"; exit 2 }

# Enable tracing if requested
if ($Trace) { $env:CUEFIXER_TRACE = '1' }

# Safety: stub apply/editor/play unless allowed
if (-not $Apply) {
    function Invoke-ApplyFix { param($Results) Write-Verbose "(dry-run) Would apply fixes for $($Results.Count) file(s)" }
}
if (-not $Live) {
    function Open-InEditor { param($fp) Write-Verbose "(stub) Open-InEditor $fp" }
  function Start-Process { param($fp,$arguments) Write-Verbose "(stub) Start-Process $fp $arguments" }
}

foreach ($folder in $Folders) {
    if (-not (Test-Path -LiteralPath $folder)) { Write-Warning "Folder not found: $folder"; continue }
    $cueFiles = Get-ChildItem -Path $folder -Filter *.cue -File -Recurse:$false -ErrorAction SilentlyContinue
    if (-not $cueFiles) { Write-Verbose "No .cue files in $folder"; continue }

    $alist = [System.Collections.ArrayList]::new()
    foreach ($f in $cueFiles) { [void]$alist.Add($f) }

    Write-Host "Running interactive impl for folder: $folder`n  Found $($alist.Count) .cue file(s)"
    Invoke-InteractiveFixImpl -CueFiles $alist
}

if ($Trace) { Write-Host "Trace log: $(Join-Path $env:TEMP 'cuefixer-interactive-log.json')" }
