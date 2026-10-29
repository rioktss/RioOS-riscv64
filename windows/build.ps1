$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BashCommand = Get-Command bash.exe -ErrorAction SilentlyContinue
if (-not $BashCommand) { $BashCommand = Get-Command bash -ErrorAction SilentlyContinue }
if (-not $BashCommand) {
    throw "Git Bash is required. Install Git for Windows and ensure bash.exe is on PATH."
}
$ScriptPath = Join-Path $ProjectRoot "linux/build.sh"
$CygpathCommand = Get-Command cygpath.exe -ErrorAction SilentlyContinue
if ($CygpathCommand) {
    $ScriptPath = (& $CygpathCommand.Source -u $ScriptPath).Trim()
}
& $BashCommand.Source $ScriptPath @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
exit 0
