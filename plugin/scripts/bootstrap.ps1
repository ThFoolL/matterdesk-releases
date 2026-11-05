$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Text.UTF8Encoding]::new($false)
$taskDataDirectory = if ($env:MATTERDESK_DATA_DIR) { $env:MATTERDESK_DATA_DIR } else { Join-Path $env:LOCALAPPDATA 'MatterDesk' }
$taskStatusFile = Join-Path $taskDataDirectory 'component-install.json'
$taskComponent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\component.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function Get-MatterDeskSetupStatus {
  $taskStatus = $null
  try { $taskStatus = Get-Content -LiteralPath $taskStatusFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
  if ($taskStatus -and $taskStatus.running) {
    $taskProcess = Get-Process -Id $taskStatus.pid -ErrorAction SilentlyContinue
    if (-not $taskProcess -or $taskProcess.ProcessName -ne 'powershell' -or $taskProcess.StartTime.ToUniversalTime().ToString('o') -ne $taskStatus.processStartedAt) {
      $taskStatus.running = $false
      $taskStatus.stage = 'interrupted'
      $taskStatus.message = '组件安装已中断，可以重新安装；个人数据保留。'
    }
  }
  if ($taskStatus -and $taskStatus.version -eq $taskComponent.version) {
    $taskInstalledRoot = Join-Path $env:LOCALAPPDATA ('MatterDeskApp\' + $taskComponent.version)
    $taskRegistered = $null
    try { $taskRegistered = Get-Content -LiteralPath (Join-Path $taskDataDirectory 'install.json') -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
    if ($taskStatus.stage -ne 'ready' -or ($taskRegistered.executable -eq (Join-Path $taskInstalledRoot 'MatterDesk.exe') -and (Test-Path -LiteralPath (Join-Path $taskInstalledRoot 'MatterDesk.exe')) -and (Test-Path -LiteralPath (Join-Path $taskInstalledRoot 'runtime\node.exe')))) { return $taskStatus }
  }
  return @{ version=$taskComponent.version; running=$false; stage='not_installed'; message='请安装本版桌面组件。安装完成后新开 Codex 对话，填写关注范围并连接飞书。' }
}
function Start-MatterDeskComponentInstall {
  $taskStatus = Get-MatterDeskSetupStatus
  if ($taskStatus.running) { return $taskStatus }
  $null = New-Item -ItemType Directory -Path $taskDataDirectory -Force
  $taskSetup = Join-Path $PSScriptRoot 'setup.ps1'
  $taskProcess = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -WindowStyle Hidden -ArgumentList @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-File', ('"' + $taskSetup + '"')) -PassThru
  $taskStartedState = @{ version=$taskComponent.version; running=$true; stage='starting'; pid=$taskProcess.Id; processStartedAt=$taskProcess.StartTime.ToUniversalTime().ToString('o'); message='已在后台启动组件安装。用 matterdesk_setup_status 查看进度；请等待完成后新开对话。' }
  if (-not (Get-MatterDeskSetupStatus).running) { [IO.File]::WriteAllText($taskStatusFile, ($taskStartedState | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false)) }
  return $taskStartedState
}
function Write-MatterDeskRpc($Value) { [Console]::Out.WriteLine(($Value | ConvertTo-Json -Depth 30 -Compress)) }
$taskTools = @(
  @{ name='matterdesk_setup_status'; description='查看事序桌面组件的安装或升级进度，无需 Node.js。'; inputSchema=@{type='object';properties=@{};additionalProperties=$false}; annotations=@{readOnlyHint=$true} },
  @{ name='matterdesk_install_components'; description='用户要求设置或更新事序时，在后台下载并校验官方 Release 桌面组件，保留个人数据。完成后新开对话使用完整工具。'; inputSchema=@{type='object';properties=@{};additionalProperties=$false}; annotations=@{readOnlyHint=$false;destructiveHint=$false} }
)
while ($null -ne ($taskLine = [Console]::In.ReadLine())) {
  $taskRpc = $null
  try {
    $taskRpc = $taskLine | ConvertFrom-Json
    if ($null -eq $taskRpc.id) { continue }
    $taskResult = switch ($taskRpc.method) {
      'initialize' { @{ protocolVersion=$taskRpc.params.protocolVersion; capabilities=@{tools=@{}}; serverInfo=@{name='matterdesk-setup';version=$taskComponent.version} }; break }
      'ping' { @{}; break }
      'tools/list' { @{tools=$taskTools}; break }
      'tools/call' {
        $taskState = switch ($taskRpc.params.name) {
          'matterdesk_setup_status' { Get-MatterDeskSetupStatus; break }
          'matterdesk_install_components' { Start-MatterDeskComponentInstall; break }
          default { throw 'Unknown setup tool' }
        }
        @{content=@(@{type='text';text=($taskState | ConvertTo-Json -Depth 15 -Compress)})}; break
      }
      default { throw 'Unsupported setup request' }
    }
    Write-MatterDeskRpc @{jsonrpc='2.0';id=$taskRpc.id;result=$taskResult}
  } catch {
    Write-MatterDeskRpc @{jsonrpc='2.0';id=$taskRpc.id;error=@{code=-32603;message='事序安装入口暂时不可用，请重新设置或查看插件 README。'}}
  }
}
