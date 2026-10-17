param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotBinary = 'C:\Users\shame\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe'
if (-not (Test-Path -LiteralPath $godotBinary)) {
    throw "找不到项目固定的 Godot 4.6.3：$godotBinary"
}

# 首次克隆也先生成全局脚本类型缓存，再启动独立桌面窗口。
$importProcess = Start-Process -FilePath $godotBinary -ArgumentList @('--headless', '--path', ('"' + $projectRoot + '"'), '--editor', '--import', '--quit') -WindowStyle Hidden -Wait -PassThru
if ($importProcess.ExitCode -ne 0) {
    throw "Godot 资源导入失败，退出码：$($importProcess.ExitCode)"
}
Start-Process -FilePath $godotBinary -ArgumentList @('--path', ('"' + $projectRoot + '"'))
