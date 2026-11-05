$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Text.UTF8Encoding]::new($false)
$taskDataDirectory = if ($env:MATTERDESK_DATA_DIR) { $env:MATTERDESK_DATA_DIR } else { Join-Path $env:LOCALAPPDATA 'MatterDesk' }
$taskRegistration = Join-Path $taskDataDirectory 'install.json'
$taskNode = $null
$taskComponent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\component.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (Test-Path -LiteralPath $taskRegistration) {
  $taskInstallation = Get-Content -LiteralPath $taskRegistration -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($taskInstallation.executable -and (Test-Path -LiteralPath $taskInstallation.executable)) {
    $taskCandidate = Join-Path (Split-Path -Parent $taskInstallation.executable) 'runtime\node.exe'
    if ((Test-Path -LiteralPath $taskCandidate) -and (Split-Path -Leaf (Split-Path -Parent $taskInstallation.executable)) -eq $taskComponent.version) { $taskNode = $taskCandidate }
  }
}
if (-not $taskNode -and -not $taskComponent.sha256 -and $taskInstallation.pluginId -eq 'matterdesk@matterdesk-local') {
  $taskCommand = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($taskCommand) { $taskNode = $taskCommand.Source }
}
if (-not $taskNode) {
  & (Join-Path $PSScriptRoot 'bootstrap.ps1')
  exit $LASTEXITCODE
}
$taskBridge = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\dist\bridge.mjs'))
& $taskNode $taskBridge
exit $LASTEXITCODE
