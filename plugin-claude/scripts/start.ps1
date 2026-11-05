$ErrorActionPreference = 'Stop'
$profileRoot = if ($env:MATTERDESK_DATA_DIR) { $env:MATTERDESK_DATA_DIR } else { Join-Path $env:LOCALAPPDATA 'MatterDesk' }
$registration = Join-Path $profileRoot 'install.json'
if (-not (Test-Path -LiteralPath $registration)) { throw '事序尚未完成首次设置，请让 Agent 帮你安装并打开配置引导。' }
$installation = Get-Content -LiteralPath $registration -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($target in @($installation.executable, $installation.entry, $installation.workingDirectory)) {
  if ($target -and ($target -match '["\r\n]' -or -not (Test-Path -LiteralPath $target))) { throw '暂时找不到事序的安装文件，请让 Agent 检查并修复安装。' }
}
if ($installation.entry) {
  Start-Process -FilePath $installation.executable -ArgumentList ('"' + $installation.entry + '"') -WorkingDirectory $installation.workingDirectory -WindowStyle Hidden
} else {
  Start-Process -FilePath $installation.executable -WorkingDirectory $installation.workingDirectory -WindowStyle Hidden
}
