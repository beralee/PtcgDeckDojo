# train_gardevoir_pipeline.ps1
# 沙奈朵 Value Net 一键训练管线：采集 → 训练 → 部署
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts\training\train_gardevoir_pipeline.ps1
#
# 可选参数：
#   -Games 200          每轮采集对局数
#   -DeckA 578647       己方卡组 ID
#   -DeckB 578647       对手卡组 ID
#   -Epochs 200         训练轮数
#   -TeacherWeight 0.3  蒸馏权重
#   -SkipCollect        跳过采集（已有数据时）

param(
    [int]$Games = 200,
    [int]$DeckA = 578647,
    [int]$DeckB = 578647,
    [int]$Epochs = 200,
    [float]$TeacherWeight = 0.3,
    [switch]$SkipCollect
)

$ErrorActionPreference = "Stop"

$GodotBin = "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe"
$ProjectDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$TrainingDataDir = "$env:APPDATA\Godot\app_userdata\PTCG Train\training_data\gardevoir"
$OutputWeights = "$env:APPDATA\Godot\app_userdata\PTCG Train\ai_agents\gardevoir_value_net.json"
$TrainScript = "$ProjectDir\scripts\training\train_value_net.py"

Write-Host "===== 沙奈朵 Value Net 训练管线 =====" -ForegroundColor Cyan
Write-Host "Godot: $GodotBin"
Write-Host "项目: $ProjectDir"
Write-Host "数据: $TrainingDataDir"
Write-Host "输出: $OutputWeights"

# ===== 第一步：采集 =====
if (-not $SkipCollect) {
    Write-Host ""
    Write-Host ">>> 第一步：采集训练数据 ($Games 局)" -ForegroundColor Yellow

    & $GodotBin --headless --path $ProjectDir --quit-after 9999 `
        -s res://scenes/tuner/ValueNetDataRunner.gd `
        -- --games=$Games --deck-a=$DeckA --deck-b=$DeckB

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 数据采集失败 (exit code: $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }

    $jsonCount = (Get-ChildItem "$TrainingDataDir\game_*.json" -ErrorAction SilentlyContinue).Count
    Write-Host "[采集完成] $jsonCount 个 JSON 文件" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host ">>> 跳过采集（使用现有数据）" -ForegroundColor Yellow
}

# ===== 第二步：训练 =====
Write-Host ""
Write-Host ">>> 第二步：训练 Value Net" -ForegroundColor Yellow

# 确保输出目录存在
$outputDir = Split-Path $OutputWeights
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

python $TrainScript `
    --data-dir $TrainingDataDir `
    --output $OutputWeights `
    --hidden1 128 --hidden2 64 --hidden3 32 `
    --epochs $Epochs `
    --teacher-weight $TeacherWeight `
    --patience 10 `
    --batch-size 256 `
    --lr 0.001

if ($LASTEXITCODE -ne 0) {
    Write-Host "[错误] 训练失败 (exit code: $LASTEXITCODE)" -ForegroundColor Red
    exit 1
}

Write-Host "[训练完成] 权重已保存到 $OutputWeights" -ForegroundColor Green

# ===== 第三步：验证 =====
Write-Host ""
Write-Host ">>> 第三步：验证部署" -ForegroundColor Yellow

if (Test-Path $OutputWeights) {
    $fileSize = (Get-Item $OutputWeights).Length
    Write-Host "[部署成功] gardevoir_value_net.json ($fileSize bytes)" -ForegroundColor Green
    Write-Host "下次启动对战时，沙奈朵 MCTS 将自动加载 Value Net" -ForegroundColor Cyan
} else {
    Write-Host "[警告] 权重文件未找到" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "===== 管线完成 =====" -ForegroundColor Cyan
