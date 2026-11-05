$ErrorActionPreference = 'Stop'
$profileRoot = if ($env:MATTERDESK_DATA_DIR) { $env:MATTERDESK_DATA_DIR } else { Join-Path $env:LOCALAPPDATA 'MatterDesk' }
$registration = Join-Path $profileRoot 'install.json'
if (-not (Test-Path -LiteralPath $registration)) { throw 'Run the MatterDesk desktop app once before using this plugin.' }
$installation = Get-Content -LiteralPath $registration -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($target in @($installation.executable, $installation.entry, $installation.workingDirectory)) {
  if ($target -and ($target -match '["\r\n]' -or -not (Test-Path -LiteralPath $target))) { throw 'Invalid installation path. Run the desktop app again.' }
}
$launch = '"' + $installation.executable + '"'
if ($installation.entry) { $launch += ' "' + $installation.entry + '"' }
$startup = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]1 }
$result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine=$launch;CurrentDirectory=$installation.workingDirectory;ProcessStartupInformation=$startup}
if ($result.ReturnValue -ne 0) { throw 'MatterDesk launch failed.' }
