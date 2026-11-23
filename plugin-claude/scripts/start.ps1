. (Join-Path $PSScriptRoot 'version.ps1')
$ErrorActionPreference = 'Stop'
$profileRoot = Get-MatterDeskDataDirectory
$registration = Join-Path $profileRoot 'install.json'
if (-not (Test-Path -LiteralPath $registration)) { throw '有数尚未完成首次设置，请让 Agent 帮你安装并打开配置引导。' }
$installation = Get-Content -LiteralPath $registration -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($target in @($installation.executable, $installation.entry, $installation.workingDirectory)) {
  if ($target -and ($target -match '["\r\n]' -or -not (Test-Path -LiteralPath $target))) { throw '暂时找不到有数的安装文件，请让 Agent 检查并修复安装。' }
}
# Electron hosts may use Node mode for their helpers. It must not reach the GUI.
$taskElectronNodeMode = [Environment]::GetEnvironmentVariable('ELECTRON_RUN_AS_NODE', 'Process')
try {
  [Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $null, 'Process')
  if ($installation.entry) {
    $taskLaunched = Start-Process -FilePath $installation.executable -ArgumentList ('"' + $installation.entry + '"') -WorkingDirectory $installation.workingDirectory -WindowStyle Hidden -PassThru
  } else {
    $taskLaunched = Start-Process -FilePath $installation.executable -WorkingDirectory $installation.workingDirectory -WindowStyle Hidden -PassThru
  }
} finally {
  [Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $taskElectronNodeMode, 'Process')
}
try {
  $taskRecord = @{ at = [DateTime]::UtcNow.ToString('o'); event = 'launch-requested'; pid = $taskLaunched.Id } | ConvertTo-Json -Compress
  [IO.File]::AppendAllText((Join-Path $profileRoot 'desktop.log'), $taskRecord + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
} catch { }
