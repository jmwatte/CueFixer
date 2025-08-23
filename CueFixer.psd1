@{
	# Basic module manifest for CueFixer
	ModuleVersion = '0.1.0'
	GUID = 'd4a8b3b3-6c1f-4d2b-a9f2-3f9b8b6a1c2e'
	Author = 'CueFixer Maintainer'
	CompanyName = ''
	Copyright = '(c) 2025'
	Description = 'CueFixer PowerShell module - audit and repair .cue files for audio libraries'
	RootModule = 'CueFixer.psm1'
	# Minimum PowerShell version required to import the module (left permissive)
	PowerShellVersion = '5.1'
	FileList = @(
		'CueFixer.psm1',
		'cleanCueFiles.ps1'
	)
	FunctionsToExport = @('*')
	AliasesToExport = @()
	CmdletsToExport = @()
	VariablesToExport = @()
	PrivateData = @{}
}






