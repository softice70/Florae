# 环境配置指南 - Florae项目

## 推荐软件环境（2023-2024年版本）

### 1. Flutter SDK
- **推荐版本**: 3.7.12 或 3.10.x
- **安装命令**: 
  ```bash
  flutter downgrade 3.7.12
  ```

### 2. Android Studio
- **版本**: Android Studio Giraffe (2022.3.1) Patch 4
- **下载链接**: https://developer.android.com/studio/archive

### 3. Java Development Kit
- **版本**: Java 11 (必须)
- **推荐**: OpenJDK 11.0.18
- **设置环境变量**:
  ```bash
  JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
  ```

### 4. Android SDK
- **API Level**: 34 (Android 14)
- **构建工具**: 34.0.0
- **NDK**: 25.1.8937393

## 项目特定配置

### Background Fetch 插件配置

#### 1. 添加TransistorSoft仓库
在 `android/build.gradle` 中已经添加了：
```gradle
maven { url 'https://maven.transistorsoft.com' }
```

#### 2. 必要的依赖
在 `android/app/build.gradle` 中已经包含：
```gradle
implementation 'com.transistorsoft:tsbackgroundfetch:1.3.0'
```

#### 3. ProGuard配置
已创建 `android/app/proguard-rules.pro` 文件，包含必要的混淆规则。

## 安装步骤

### 1. 安装Flutter SDK
```bash
# 下载Flutter 3.7.12
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.7.12-stable.zip

# 解压到 C:\flutter
# 添加环境变量
export PATH="$PATH:C:\flutter\bin"
```

### 2. 配置Android Studio
1. 安装Android Studio Giraffe (2022.3.1)
2. 安装Android SDK 34
3. 安装NDK 25.1.8937393
4. 配置SDK路径

### 3. 项目配置
```bash
# 在项目根目录执行
flutter clean
flutter pub get
flutter pub upgrade

# 构建APK
flutter build apk --debug
flutter build apk --release
```

## 常见问题解决

### 1. background_fetch依赖问题
如果仍然遇到 `tsbackgroundfetch` 依赖问题：

1. 确保网络可以访问 https://maven.transistorsoft.com
2. 检查防火墙设置
3. 使用VPN（如果需要）

### 2. Java版本问题
确保使用Java 11：
```bash
java -version
# 应该显示 openjdk version "11.0.x"
```

### 3. 构建失败
如果遇到构建失败：
```bash
flutter clean
flutter pub get
flutter build apk --debug --verbose
```

## 验证环境

### 1. 检查Flutter环境
```bash
flutter doctor
flutter doctor --android-licenses
```

### 2. 测试构建
```bash
# 测试debug构建
flutter build apk --debug

# 测试release构建
flutter build apk --release
```

## 降级指南

如果当前环境版本过高，可以使用以下降级方案：

### Flutter降级
```bash
flutter downgrade 3.7.12
```

### 创建兼容环境
1. 使用Docker创建隔离环境
2. 使用特定版本的Flutter Docker镜像
3. 使用FVM (Flutter Version Manager)

```bash
# 安装FVM
pub global activate fvm

# 使用项目兼容版本
fvm use 3.7.12
fvm flutter build apk
```

## 联系方式

如果遇到环境问题，请检查：
1. 网络连接（特别是访问maven.transistorsoft.com）
2. Java版本（必须是11）
3. Flutter版本（推荐3.7.12）
4. Android SDK版本（推荐34）