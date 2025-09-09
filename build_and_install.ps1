# Florae APK构建和安装脚本
# 作者: CodeBuddy
# 用途: 构建Flutter APK并可选择安装到连接的Android设备
#
# 默认构建（不清理）
# .\build_and_install.ps1
# 构建release版本（不清理）
# .\build_and_install.ps1 -BuildType release
# 构建时执行清理
# .\build_and_install.ps1 -Clean
# 构建release版本并执行清理
# .\build_and_install.ps1 -BuildType release -Clean


param(
    [string]$BuildType = "debug",  # 构建类型: debug, release
    [switch]$Clean = $false        # 执行清理步骤
)

# 颜色输出函数
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# 检查Flutter是否安装
function Test-FlutterInstalled {
    try {
        $flutterVersion = flutter --version 2>$null
        return $true
    }
    catch {
        return $false
    }
}

# 检查ADB是否可用
function Test-AdbAvailable {
    try {
        $adbVersion = adb version 2>$null
        return $true
    }
    catch {
        return $false
    }
}

# 获取连接的Android设备
function Get-ConnectedDevices {
    try {
        $devices = adb devices | Select-String -Pattern "device$" | ForEach-Object { $_.Line.Split()[0] }
        return $devices
    }
    catch {
        return @()
    }
}

# 主脚本开始
Write-ColorOutput "=== Florae APK 构建和安装脚本 ===" "Cyan"
Write-ColorOutput "构建类型: $BuildType" "Yellow"

# 检查Flutter安装
if (-not (Test-FlutterInstalled)) {
    Write-ColorOutput "错误: Flutter未安装或不在PATH中" "Red"
    exit 1
}

Write-ColorOutput "✓ Flutter已安装" "Green"

# 清理项目（可选）
if ($Clean) {
    Write-ColorOutput "正在清理项目..." "Yellow"
    flutter clean
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "警告: 清理过程中出现问题，继续构建..." "Yellow"
    }
}

# 获取依赖
Write-ColorOutput "正在获取依赖..." "Yellow"
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "错误: 获取依赖失败" "Red"
    exit 1
}

# 构建APK
Write-ColorOutput "正在构建 $BuildType APK..." "Yellow"
$buildCommand = if ($BuildType -eq "release") { "flutter build apk --release" } else { "flutter build apk --debug" }

Invoke-Expression $buildCommand
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "错误: APK构建失败" "Red"
    exit 1
}

Write-ColorOutput "✓ APK构建成功!" "Green"

# 查找生成的APK文件
$apkPath = if ($BuildType -eq "release") { 
    "build\app\outputs\flutter-apk\app-release.apk" 
} else { 
    "build\app\outputs\flutter-apk\app-debug.apk" 
}

if (-not (Test-Path $apkPath)) {
    Write-ColorOutput "错误: 找不到生成的APK文件: $apkPath" "Red"
    exit 1
}

$apkFullPath = Resolve-Path $apkPath
Write-ColorOutput "APK文件位置: $apkFullPath" "Cyan"

# 获取APK文件大小
$apkSize = [math]::Round((Get-Item $apkPath).Length / 1MB, 2)
Write-ColorOutput "APK文件大小: ${apkSize} MB" "Cyan"

# 检查是否要安装到设备
Write-ColorOutput "`n是否要安装APK到连接的Android设备? (y/N)" "Yellow"
$installChoice = Read-Host

if ($installChoice -match "^[Yy]") {
    # 检查ADB是否可用
    if (-not (Test-AdbAvailable)) {
        Write-ColorOutput "错误: ADB未安装或不在PATH中，无法安装到设备" "Red"
        Write-ColorOutput "APK已构建完成，您可以手动安装: $apkFullPath" "Cyan"
        exit 0
    }

    # 获取连接的设备
    $devices = Get-ConnectedDevices
    
    if ($devices.Count -eq 0) {
        Write-ColorOutput "错误: 没有检测到连接的Android设备" "Red"
        Write-ColorOutput "请确保:" "Yellow"
        Write-ColorOutput "1. 设备已连接并启用USB调试" "Yellow"
        Write-ColorOutput "2. 已安装设备驱动程序" "Yellow"
        Write-ColorOutput "3. 在设备上允许此计算机进行调试" "Yellow"
        Write-ColorOutput "`nAPK已构建完成，您可以手动安装: $apkFullPath" "Cyan"
        exit 0
    }

    Write-ColorOutput "检测到 $($devices.Count) 个设备:" "Green"
    for ($i = 0; $i -lt $devices.Count; $i++) {
        Write-ColorOutput "  [$($i+1)] $($devices[$i])" "Cyan"
    }

    $deviceIndex = 0
    if ($devices.Count -gt 1) {
        Write-ColorOutput "请选择要安装的设备 (1-$($devices.Count)):" "Yellow"
        $selection = Read-Host
        try {
            $deviceIndex = [int]$selection - 1
            if ($deviceIndex -lt 0 -or $deviceIndex -ge $devices.Count) {
                throw "Invalid selection"
            }
        }
        catch {
            Write-ColorOutput "无效选择，使用第一个设备" "Yellow"
            $deviceIndex = 0
        }
    }

    $selectedDevice = $devices[$deviceIndex]
    Write-ColorOutput "正在安装到设备: $selectedDevice" "Yellow"

    # 安装APK
    adb -s $selectedDevice install -r $apkPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ APK安装成功!" "Green"
        
        # 询问是否启动应用
        Write-ColorOutput "`n是否要启动Florae应用? (y/N)" "Yellow"
        $launchChoice = Read-Host
        
        if ($launchChoice -match "^[Yy]") {
            Write-ColorOutput "正在启动应用..." "Yellow"
            adb -s $selectedDevice shell am start -n cat.naval.florae/.MainActivity
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✓ 应用启动成功!" "Green"
            } else {
                Write-ColorOutput "警告: 应用启动失败，请手动启动" "Yellow"
            }
        }
    } else {
        Write-ColorOutput "错误: APK安装失败" "Red"
        Write-ColorOutput "您可以手动安装: $apkFullPath" "Cyan"
    }
} else {
    Write-ColorOutput "APK已构建完成: $apkFullPath" "Cyan"
    Write-ColorOutput "您可以手动传输到设备并安装" "Yellow"
}

Write-ColorOutput "`n=== 构建完成 ===" "Cyan"