$ErrorActionPreference = 'Stop'
$env:PSModulePath = (Join-Path $PSHOME 'Modules') + ';' + $env:PSModulePath
$taskDataDirectory = if ($env:MATTERDESK_DATA_DIR) { $env:MATTERDESK_DATA_DIR } else { Join-Path $env:LOCALAPPDATA 'MatterDesk' }
$null = New-Item -ItemType Directory -Path $taskDataDirectory -Force
$taskLock = $null
try { $taskLock = [IO.File]::Open((Join-Path $taskDataDirectory 'component-install.lock'), 'OpenOrCreate', 'ReadWrite', 'None') } catch { exit 0 }
$taskStatusFile = Join-Path $taskDataDirectory 'component-install.json'
$taskComponent = $null
$taskProcessStartedAt = [Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().ToString('o')
function Set-MatterDeskInstallStage([string]$Stage, [string]$Message, [bool]$Running = $true) {
  $script:taskCurrentStage = $Stage
  $taskState = @{version=$taskComponent.version;stage=$Stage;message=$Message;running=$Running;pid=$PID;processStartedAt=$taskProcessStartedAt;updatedAt=[DateTime]::UtcNow.ToString('o');failureStage=$script:taskFailedAt;errorType=$script:taskFailureType}
  [IO.File]::WriteAllText($taskStatusFile, ($taskState | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
}
function Get-MatterDeskArchiveHash([string]$LiteralPath) {
  $taskHasher = [Security.Cryptography.SHA256]::Create()
  $taskStream = [IO.File]::OpenRead($LiteralPath)
  try { ([BitConverter]::ToString($taskHasher.ComputeHash($taskStream))).Replace('-', '').ToLowerInvariant() } finally { $taskStream.Dispose(); $taskHasher.Dispose() }
}
try {
  $taskComponent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\component.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($taskComponent.version -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?$') { throw 'Unsupported component version' }
  $taskExpectedAsset = 'MatterDesk-' + $taskComponent.version + '-win-x64.zip'
  $taskBaseUrl = 'https://github.com/ThFoolL/matterdesk-releases/releases/download/v' + $taskComponent.version + '/'
  if ($taskComponent.asset -ne $taskExpectedAsset -or $taskComponent.url -ne ($taskBaseUrl + $taskExpectedAsset) -or $taskComponent.checksumsUrl -ne ($taskBaseUrl + 'SHA256SUMS.txt')) { throw 'Invalid release metadata' }
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $taskClient = New-Object Net.WebClient
  $taskClient.Headers.Add('User-Agent', 'MatterDesk-Setup')
  $taskCache = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA ('MatterDeskApp\downloads\' + $taskComponent.version)))
  $null = New-Item -ItemType Directory -Path $taskCache -Force
  $taskArchive = Join-Path $taskCache $taskExpectedAsset
  Set-MatterDeskInstallStage 'checking' '正在检查事序安装文件。'
  $taskExpectedHash = $taskComponent.sha256
  if (-not $taskExpectedHash) {
    $taskChecksums = $taskClient.DownloadString($taskComponent.checksumsUrl)
    foreach ($taskLine in ($taskChecksums -split "`n")) {
      if ($taskLine.Trim() -match ('^([a-f0-9]{64})  ' + [regex]::Escape($taskExpectedAsset) + '$')) { $taskExpectedHash = $Matches[1]; break }
    }
  }
  if ($taskExpectedHash -notmatch '^[a-f0-9]{64}$') { throw 'Missing release checksum' }
  if (-not (Test-Path -LiteralPath $taskArchive) -or (Get-MatterDeskArchiveHash $taskArchive) -ne $taskExpectedHash) {
    Set-MatterDeskInstallStage 'downloading' '正在后台下载事序，可继续使用 Agent。'
    $taskPartial = $taskArchive + '.partial'
    $taskClient.DownloadFile($taskComponent.url, $taskPartial)
    if ((Get-MatterDeskArchiveHash $taskPartial) -ne $taskExpectedHash) { throw 'Release checksum mismatch' }
    Move-Item -LiteralPath $taskPartial -Destination $taskArchive -Force
  }
  Set-MatterDeskInstallStage 'verifying' '下载检查通过，正在准备安装。'
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $taskExtract = Join-Path $taskCache ('package-' + [Guid]::NewGuid().ToString('N'))
  [IO.Compression.ZipFile]::ExtractToDirectory($taskArchive, $taskExtract)
  $taskInstaller = Join-Path $taskExtract 'install.ps1'
  Unblock-File -LiteralPath $taskInstaller
  Set-MatterDeskInstallStage 'installing' '正在安装事序并打开首次引导；已保存的事项和设置会保留。'
  & $taskInstaller -SkipPluginRegistration
  Set-MatterDeskInstallStage 'ready' '事序已安装并打开。请按窗口引导填写关注范围、连接飞书；以后默认随已启用插件的 Agent 启动。新开对话即可通过对话调整事序。' $false
} catch {
  $script:taskFailedAt = $script:taskCurrentStage
  $script:taskFailureType = $_.Exception.GetType().FullName
  Set-MatterDeskInstallStage 'failed' '下载或安装未完成。请检查是否能打开 GitHub 的下载页面，再让 Agent 重试；已保存的事项和设置会保留。' $false
  exit 1
} finally {
  if ($taskClient) { $taskClient.Dispose() }
  if ($taskLock) { $taskLock.Dispose() }
}
