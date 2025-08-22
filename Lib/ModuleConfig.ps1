# ModuleConfig.ps1
# Centralized module configuration for CueFixer.
# Defines a small set of script-scoped variables that library files may read when dot-sourced.
<#
ModuleConfig.ps1
Centralized module configuration for CueFixer.
Defines a small set of script-scoped variables that library files may read when dot-sourced.
#>

# Approved audio extensions used throughout the library
$script:validAudioExts = @('.flac', '.mp3', '.wav', '.aac', '.ogg', '.m4a', '.aiff', '.ape')

# Preferred external editor (user can override by setting $script:preferredEditor before dot-sourcing)
$script:preferredEditor = 'hx'
# ModuleConfig.ps1
# Centralized module configuration for CueFixer.
# Defines variables in the script: scope so dot-sourced library files can access them.

# Approved audio extensions used throughout the library
$script:validAudioExts = @('.flac', '.mp3', '.wav', '.aac', '.ogg', '.m4a', '.aiff', '.ape')

# Preferred external editor (user can override by setting $script:preferredEditor before dot-sourcing)
$script:preferredEditor = 'hx'







