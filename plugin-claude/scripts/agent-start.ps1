param([ValidateSet('codex','claude','dsh')][string]$Agent='claude',[int]$AgentProcessId=0)
$ErrorActionPreference='Stop'
$taskDirectory=if($env:MATTERDESK_DATA_DIR){$env:MATTERDESK_DATA_DIR}else{Join-Path $env:LOCALAPPDATA 'MatterDesk'}
$taskRegistration=Join-Path $taskDirectory 'install.json'
if(-not(Test-Path -LiteralPath $taskRegistration)){exit 0}
try{$taskSettings=Get-Content -LiteralPath (Join-Path $taskDirectory 'settings.json') -Raw -Encoding UTF8|ConvertFrom-Json;if($taskSettings.desktop.autoStartWithAgent -eq $false){exit 0}}catch{}
if($AgentProcessId -le 0){
  $taskProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
  for($taskDepth=0;$taskDepth -lt 6 -and $taskProcess;$taskDepth++){
    $taskProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$($taskProcess.ParentProcessId)"
    if($taskProcess -and ($taskProcess.Name -eq 'claude.exe' -or $taskProcess.CommandLine -match '(?i)@anthropic-ai[\\/]claude-code')){$AgentProcessId=[int]$taskProcess.ProcessId;break}
  }
}
$taskHost=if($AgentProcessId -gt 0){Get-CimInstance Win32_Process -Filter "ProcessId=$AgentProcessId"}else{$null}
if(-not $taskHost){exit 0}
$taskKey=$Agent+':'+$AgentProcessId+':'+$taskHost.CreationDate.ToUniversalTime().ToString('o')
$taskStampDirectory=Join-Path $taskDirectory 'agent-startup'
$null=New-Item -ItemType Directory -Path $taskStampDirectory -Force
$taskStampFile=Join-Path $taskStampDirectory ('host-'+$Agent+'.json')
try{$taskPrevious=Get-Content -LiteralPath $taskStampFile -Raw -Encoding UTF8|ConvertFrom-Json;if($taskPrevious.key -eq $taskKey){exit 0}}catch{}
[IO.File]::WriteAllText($taskStampFile,(@{key=$taskKey}|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
try{
  $taskRuntime=Get-Content -LiteralPath (Join-Path $taskDirectory 'runtime.json') -Raw -Encoding UTF8|ConvertFrom-Json
  if($taskRuntime.port -gt 0 -and $taskRuntime.port -le 65535 -and $taskRuntime.token -match '^[a-f0-9]{64}$'){
    $null=Invoke-RestMethod -Uri "http://127.0.0.1:$($taskRuntime.port)/api/window/status" -Headers @{Authorization=('Bearer '+$taskRuntime.token)} -TimeoutSec 2
    exit 0
  }
}catch{}
$env:MATTERDESK_AGENT=$Agent
& (Join-Path $PSScriptRoot 'start.ps1')
