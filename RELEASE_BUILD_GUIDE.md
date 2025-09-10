# Florae Release版本构建指南

## 当前配置状态

✅ **已配置完成：**
- build.gradle中release签名配置已正确设置
- 版本信息：3.1.0+6
- 应用ID：cat.naval.florae
- ProGuard规则已配置（proguard-rules.pro）
- 多语言支持已完善
- 所有依赖项已更新到兼容版本

⚠️ **需要手动配置：**
- 签名密钥文件（keystore）需要创建
- key.properties文件需要配置实际密码

## 生成签名密钥

### 方法1：使用Android Studio
1. 打开Android Studio
2. Build → Generate Signed Bundle/APK
3. 选择APK → Next
4. 点击"Create new..."
5. 填写密钥信息：
   - Key store path: `e:\Workspace\MyProjects\andriod\flower\Florae\keystore\florae-release.keystore`
   - Password: [设置您的密码]
   - Key alias: florae-release
   - Key password: [设置您的密钥密码]
   - Validity: 25年
   - Certificate信息：
     - First and Last Name: Naval Alcalá
     - Organization Unit: Florae
     - Organization: Naval Alcalá
     - City/Locality: [您的城市]
     - State/Province: [您的省份]
     - Country Code: [您的国家代码]

### 方法2：使用命令行
```bash
cd e:\Workspace\MyProjects\andriod\flower\Florae
keytool -genkey -v -keystore keystore/florae-release.keystore -alias florae-release -keyalg RSA -keysize 2048 -validity 9125
```

## 配置签名信息

编辑 `android/key.properties` 文件，替换为实际值：

```properties
storeFile=../keystore/florae-release.keystore
storePassword=您的keystore密码
keyAlias=florae-release
keyPassword=您的密钥密码
```

## Release构建步骤

### 1. 清理项目
```bash
flutter clean
flutter pub get
```

### 2. 构建Release APK
```bash
flutter build apk --release
```

构建完成后，APK文件将位于：
`build/app/outputs/flutter-apk/app-release.apk`

### 3. 构建App Bundle（推荐用于Google Play）
```bash
flutter build appbundle --release
```

构建完成后，AAB文件将位于：
`build/app/outputs/bundle/release/app-release.aab`

## 验证构建

### 检查APK信息
```bash
cd e:\Workspace\MyProjects\andriod\flower\Florae
keytool -list -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

### 安装测试
```bash
flutter install build/app/outputs/flutter-apk/app-release.apk
```

## 版本更新

### 更新版本号
编辑 `pubspec.yaml`：
```yaml
version: 3.1.1+7  # 增加版本号和构建号
```

### 更新local.properties
```properties
flutter.versionName=3.1.1
flutter.versionCode=7
```

## 注意事项

1. **安全警告**：永远不要将keystore文件或key.properties文件提交到版本控制
2. **备份**：安全备份您的keystore文件和密码
3. **Google Play**：如果上传到Google Play，确保keystore信息准确无误
4. **F-Droid**：如果发布到F-Droid，需要特殊配置

## 常见问题

### 签名错误
如果构建时出现签名相关错误，请检查：
- key.properties文件路径是否正确
- keystore文件是否存在
- 密码是否正确

### 构建失败
如果构建失败，尝试：
```bash
flutter clean
flutter pub get
flutter build apk --release --verbose
```

## 发布渠道

- **Google Play Store**: 使用app-release.aab文件
- **F-Droid**: 使用特殊构建配置
- **GitHub Releases**: 使用app-release.apk文件
- **直接分发**: 使用app-release.apk文件