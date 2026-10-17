param([switch]$Test, [switch]$Capture)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = 'C:/Users/shame/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe'
$logDir = Join-Path $projectRoot 'production/qa/manager_blender'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$importLog = Join-Path $logDir 'import.log'
& $godot --headless --path $projectRoot --editor --import --quit *> $importLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR|Parse Error|ERROR:' -Quiet)) {
    Get-Content -LiteralPath $importLog
    throw '店长验证工程导入失败'
}
if ($Test) {
    & $godot --headless --path $projectRoot --script res://tests/animation_lab/test_manager_animation.gd
    if ($LASTEXITCODE -ne 0) { throw '店长验证测试失败' }
}
if ($Capture) {
    & $godot --path $projectRoot --position -10000,-10000 --script res://tests/animation_lab/render_manager_lab.gd
    if ($LASTEXITCODE -ne 0) { throw '店长预览渲染失败' }
}
if (-not $Test -and -not $Capture) {
    $gui = 'C:/Users/shame/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe'
    # 此进程是供用户观察和操作的验证窗口，使用可见窗口模式。
    Start-Process -FilePath $gui -ArgumentList @('--path', ('"' + $projectRoot + '"'), 'res://features/animation_lab/manager_lab.tscn') -WindowStyle Normal
}
