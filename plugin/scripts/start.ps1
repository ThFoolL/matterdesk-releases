$ErrorActionPreference = 'Stop'
$profileRoot = if ($env:MATTERDESK_DATA_DIR) { $env:MATTERDESK_DATA_DIR } else { Join-Path $env:LOCALAPPDATA 'MatterDesk' }
$registration = Join-Path $profileRoot 'install.json'
if (-not (Test-Path -LiteralPath $registration)) { throw '事序尚未完成首次设置，请让 Agent 帮你安装并打开配置引导。' }
$installation = Get-Content -LiteralPath $registration -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($target in @($installation.executable, $installation.entry, $installation.workingDirectory)) {
  if ($target -and ($target -match '["\r\n]' -or -not (Test-Path -LiteralPath $target))) { throw '暂时找不到事序的安装文件，请让 Agent 检查并修复安装。' }
}
$launch = '"' + $installation.executable + '"'
if ($installation.entry) { $launch += ' "' + $installation.entry + '"' }
$startup = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]1 }
$result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine=$launch;CurrentDirectory=$installation.workingDirectory;ProcessStartupInformation=$startup}
if ($result.ReturnValue -ne 0) { throw '事序未能打开，请重试或让 Agent 检查安装。' }
