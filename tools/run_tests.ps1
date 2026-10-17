param([switch]$Render)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotBinary = 'C:\Users\shame\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
$evidenceFolder = Join-Path $projectRoot 'production/qa/personality_tavern'
New-Item -ItemType Directory -Path $evidenceFolder -Force | Out-Null
$importLog = Join-Path $evidenceFolder 'import.log'
$testLog = Join-Path $evidenceFolder 'unit_integration.log'
& $godotBinary --headless --path $projectRoot --editor --import --quit *> $importLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR|Parse Error' -Quiet)) {
    Get-Content -LiteralPath $importLog
    throw 'Godot 导入或脚本检查失败'
}
& $godotBinary --headless --path $projectRoot --script res://tests/test_runner.gd *> $testLog
$testExit = $LASTEXITCODE
Get-Content -LiteralPath $testLog
if ($testExit -ne 0 -or (Select-String -LiteralPath $testLog -Pattern 'SCRIPT ERROR|测试失败|Parse Error' -Quiet)) {
    throw '单元或集成测试失败'
}
if ($Render) {
    $keysLog = Join-Path $evidenceFolder 'articulated_keys.log'
    & $godotBinary --path $projectRoot --position -10000,-10000 --script res://tests/desktop/render_articulated_keys.gd *> $keysLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $keysLog -Pattern 'SCRIPT ERROR|ERROR:|Parse Error' -Quiet)) {
        Get-Content -LiteralPath $keysLog
        throw '关节步态关键姿态渲染失败'
    }
    $occlusionLog = Join-Path $evidenceFolder 'leg_occlusion.log'
    & $godotBinary --path $projectRoot --position -10000,-10000 --script res://tests/desktop/render_leg_occlusion.gd *> $occlusionLog
    $occlusionExit = $LASTEXITCODE
    Get-Content -LiteralPath $occlusionLog
    if ($occlusionExit -ne 0 -or (Select-String -LiteralPath $occlusionLog -Pattern 'SCRIPT ERROR|ERROR:|Parse Error' -Quiet)) {
        throw '行走近腿/远腿交错遮挡验证失败'
    }
    $groundedLog = Join-Path $evidenceFolder 'grounded_contact.log'
    & $godotBinary --path $projectRoot --position -10000,-10000 --script res://tests/desktop/render_grounded_contact.gd *> $groundedLog
    $groundedExit = $LASTEXITCODE
    Get-Content -LiteralPath $groundedLog
    if ($groundedExit -ne 0 -or (Select-String -LiteralPath $groundedLog -Pattern 'SCRIPT ERROR|ERROR:|Parse Error' -Quiet)) {
        throw '支撑脚像素锁地或站走闪烁回归失败'
    }
    $smoothLog = Join-Path $evidenceFolder 'smooth_walk_render.log'
    & $godotBinary --path $projectRoot --position -10000,-10000 --script res://tests/desktop/render_smooth_walk.gd *> $smoothLog
    $smoothExit = $LASTEXITCODE
    Get-Content -LiteralPath $smoothLog
    if ($smoothExit -ne 0 -or (Select-String -LiteralPath $smoothLog -Pattern 'SCRIPT ERROR|ERROR:|Parse Error' -Quiet)) {
        throw '真实速度连续步态渲染失败'
    }
    $reviewLog = Join-Path $evidenceFolder 'walk_review.log'
    & $godotBinary --path $projectRoot --position -10000,-10000 --script res://tests/desktop/render_walk_review.gd *> $reviewLog
    $reviewExit = $LASTEXITCODE
    Get-Content -LiteralPath $reviewLog
    if ($reviewExit -ne 0 -or (Select-String -LiteralPath $reviewLog -Pattern 'SCRIPT ERROR|ERROR:|Parse Error' -Quiet)) {
        throw '完整人物走路检查帧生成失败'
    }
    $drinkLog = Join-Path $evidenceFolder 'drinks_render.log'
    & $godotBinary --path $projectRoot --position -10000,-10000 --script res://tests/desktop/render_drinks_and_legs.gd *> $drinkLog
    $drinkExit = $LASTEXITCODE
    Get-Content -LiteralPath $drinkLog
    if ($drinkExit -ne 0 -or (Select-String -LiteralPath $drinkLog -Pattern 'SCRIPT ERROR|ERROR:|Parse Error' -Quiet)) {
        throw '持杯与饮用动作实际渲染失败'
    }
    $renderLog = Join-Path $evidenceFolder 'render.log'
    & $godotBinary --path $projectRoot --position -10000,-10000 --script res://tests/desktop/render_poses.gd *> $renderLog
    $renderExit = $LASTEXITCODE
    Get-Content -LiteralPath $renderLog
    if ($renderExit -ne 0 -or (Select-String -LiteralPath $renderLog -Pattern 'SCRIPT ERROR|ERROR:|Parse Error' -Quiet)) {
        throw '实际渲染测试失败'
    }
    $renderJson = Get-Content -LiteralPath $renderLog | Where-Object { $_ -match '^\{' } | Select-Object -Last 1
    [System.IO.File]::WriteAllText((Join-Path $evidenceFolder 'render_report.json'), $renderJson, [System.Text.UTF8Encoding]::new($false))
    $walkLog = Join-Path $evidenceFolder 'walk_render.log'
    & $godotBinary --path $projectRoot --position -10000,-10000 --script res://tests/desktop/render_walk_cycles.gd *> $walkLog
    $walkExit = $LASTEXITCODE
    Get-Content -LiteralPath $walkLog
    if ($walkExit -ne 0 -or (Select-String -LiteralPath $walkLog -Pattern 'SCRIPT ERROR|ERROR:|Parse Error' -Quiet)) {
        throw '步态实际渲染测试失败'
    }
    $contactLog = Join-Path $evidenceFolder 'contact_render.log'
    & $godotBinary --path $projectRoot --position -10000,-10000 --script res://tests/desktop/render_actor_contacts.gd *> $contactLog
    $contactExit = $LASTEXITCODE
    Get-Content -LiteralPath $contactLog
    if ($contactExit -ne 0 -or (Select-String -LiteralPath $contactLog -Pattern 'SCRIPT ERROR|ERROR:|Parse Error' -Quiet)) {
        throw '肩部连接或坐下连续帧渲染测试失败'
    }
    $runtimeLog = Join-Path $evidenceFolder 'runtime_render.log'
    & $godotBinary --path $projectRoot --position -10000,-10000 --script res://tests/desktop/render_runtime_snapshot.gd *> $runtimeLog
    $runtimeExit = $LASTEXITCODE
    Get-Content -LiteralPath $runtimeLog
    if ($runtimeExit -ne 0 -or (Select-String -LiteralPath $runtimeLog -Pattern 'SCRIPT ERROR|ERROR:|Parse Error' -Quiet)) {
        throw '正式场景实际渲染测试失败'
    }
}
