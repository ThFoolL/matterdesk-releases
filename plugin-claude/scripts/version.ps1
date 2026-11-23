function Compare-MatterDeskVersion([string]$Left, [string]$Right) {
  $taskLeftParts = $Left -split '-', 2
  $taskRightParts = $Right -split '-', 2
  $taskCore = ([version]$taskLeftParts[0]).CompareTo([version]$taskRightParts[0])
  if ($taskCore -ne 0) { return [Math]::Sign($taskCore) }
  if ($taskLeftParts.Count -eq 1 -and $taskRightParts.Count -eq 1) { return 0 }
  if ($taskLeftParts.Count -eq 1) { return 1 }
  if ($taskRightParts.Count -eq 1) { return -1 }
  $taskLeftIds = @($taskLeftParts[1] -split '\.')
  $taskRightIds = @($taskRightParts[1] -split '\.')
  for ($taskIndex = 0; $taskIndex -lt [Math]::Min($taskLeftIds.Count, $taskRightIds.Count); $taskIndex++) {
    $taskLeftId = $taskLeftIds[$taskIndex]
    $taskRightId = $taskRightIds[$taskIndex]
    if ($taskLeftId -eq $taskRightId) { continue }
    $taskLeftNumeric = $taskLeftId -match '^\d+$'
    $taskRightNumeric = $taskRightId -match '^\d+$'
    if ($taskLeftNumeric -and $taskRightNumeric) { return [Math]::Sign(([long]$taskLeftId).CompareTo([long]$taskRightId)) }
    if ($taskLeftNumeric) { return -1 }
    if ($taskRightNumeric) { return 1 }
    return [Math]::Sign([string]::CompareOrdinal($taskLeftId, $taskRightId))
  }
  return [Math]::Sign($taskLeftIds.Count.CompareTo($taskRightIds.Count))
}
function Get-MatterDeskDataDirectory {
  if ($env:MATTERDESK_DATA_DIR) { return [IO.Path]::GetFullPath($env:MATTERDESK_DATA_DIR) }
  $taskLocator = Join-Path $env:LOCALAPPDATA 'MatterDesk-storage.json'
  if (-not (Test-Path -LiteralPath $taskLocator)) { return Join-Path $env:LOCALAPPDATA 'MatterDesk' }
  $taskLocation = Get-Content -LiteralPath $taskLocator -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($taskLocation.version -ne 1 -or -not [IO.Path]::IsPathRooted($taskLocation.dataDirectory) -or -not (Test-Path -LiteralPath $taskLocation.dataDirectory -PathType Container)) {
    throw '有数的数据目录不可用，请连接对应磁盘或修复存储设置；不会新建空数据。'
  }
  return $taskLocation.dataDirectory
}
