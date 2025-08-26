function Invoke-Editor {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$filePath
	)

	# Determine editor: env override wins
	$editor = $env:CUEFIXER_EDITOR
	if (-not $editor) { $editor = $preferredEditor }

	Write-Verbose ([string]::Format('Opening file {0} with editor: {1}', $filePath, $editor))

	if ([string]::IsNullOrWhiteSpace($editor)) {
		# No editor configured; open by file association
		try { Start-Process -FilePath $filePath -ErrorAction Stop } catch { Write-Verbose "Failed to open file: $($_.Exception.Message)" }
		return
	}

	# Prefer launching the named editor if it's resolvable on PATH
	$cmd = Get-Command -Name $editor -ErrorAction SilentlyContinue
	if ($null -ne $cmd) {
		try {
			$exe = $cmd.Path
			if ([string]::IsNullOrWhiteSpace($exe)) { $exe = $editor }
			Start-Process -FilePath $exe -ArgumentList $filePath -ErrorAction Stop
			return
		}
		catch {
			Write-Verbose ([string]::Format('Failed to launch editor {0}: {1}', $editor, $_.Exception.Message))
		}
	}

	# Try starting the editor directly (maybe it's a full path)
	try {
		Start-Process -FilePath $editor -ArgumentList $filePath -ErrorAction Stop
		return
	}
	catch {
		Write-Verbose ([string]::Format('Could not start configured editor {0}: {1}', $editor, $_.Exception.Message))
	}

	# Fallback: open by file association
	try { Start-Process -FilePath $filePath -ErrorAction Stop } catch { Write-Verbose "Final fallback failed: $($_.Exception.Message)" }
}