# 导入导出功能修复说明

## 问题描述

在测试导入导出功能时发现，通过手机导出的文件可以识别并显示在导入的界面中，但从其他手机传过来的本应用导出文件时，无法在导入界面看到该文件，同一目录下的本机导出文件则可以看到。

## 问题原因分析

经过代码分析，发现问题主要出现在以下几个方面：

### 1. 文件选择器配置不完整
- 原始的 `FilePicker.platform.pickFiles()` 没有指定文件类型过滤器
- 没有启用 `withData: true` 选项，导致无法读取从其他应用传来的文件数据
- 缺少对不同文件来源的处理逻辑

### 2. 文件权限问题
- AndroidManifest.xml 中缺少必要的文件访问权限
- 没有声明 Android 13+ 的新媒体权限

### 3. 错误处理不完善
- 缺少详细的错误信息反馈
- 没有验证文件格式的有效性

## 解决方案

### 1. 改进文件选择器配置

修改了 `lib/data/backup/backup_manager.dart` 中的 `restore()` 方法：

```dart
FilePickerResult? result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['json'],
  allowMultiple: false,
  withData: true, // 关键：确保可以读取文件数据
);
```

### 2. 增强文件读取逻辑

添加了对不同文件来源的支持：

```dart
String fileContent;
if (pickedFile.bytes != null) {
  // 从内存中读取文件内容（适用于从其他应用传来的文件）
  fileContent = utf8.decode(pickedFile.bytes!);
} else if (pickedFile.path != null) {
  // 从文件路径读取（适用于本地文件）
  File file = File(pickedFile.path!);
  fileContent = await file.readAsString();
} else {
  return false;
}
```

### 3. 添加文件格式验证

增加了对备份文件格式的验证：

```dart
// 验证文件内容是否为有效的 JSON
Map<String, dynamic> rawSave;
try {
  rawSave = jsonDecode(fileContent);
} catch (e) {
  return false;
}

// 验证是否为有效的 Florae 备份文件
if (!rawSave.containsKey('garden') || !rawSave.containsKey('binaries')) {
  return false;
}
```

### 4. 完善 Android 权限配置

在 `android/app/src/main/AndroidManifest.xml` 中添加了必要权限：

```xml
<!-- 文件访问权限 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<!-- Android 13+ 的媒体权限 -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<!-- 其他必要权限 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### 5. 改进用户界面反馈

在 `lib/screens/settings.dart` 中添加了：

- 加载指示器显示操作进度
- 详细的成功/失败消息提示
- 更好的错误处理和用户引导

## 修复效果

经过以上修改，导入导出功能现在应该能够：

1. **正确识别从其他设备传来的备份文件**
   - 支持通过各种方式（微信、QQ、邮件等）传输的文件
   - 正确处理不同文件系统路径

2. **提供更好的用户体验**
   - 明确的文件类型过滤（只显示 .json 文件）
   - 实时的操作进度反馈
   - 详细的错误信息提示

3. **增强文件安全性**
   - 验证文件格式有效性
   - 防止导入无效或损坏的文件

## 测试建议

1. **本地测试**：在同一设备上导出后立即导入
2. **跨设备测试**：通过微信、QQ等方式传输备份文件到其他设备
3. **格式测试**：尝试导入非 JSON 文件，验证错误处理
4. **权限测试**：在不同 Android 版本上测试文件访问权限

## 注意事项

- 需要重新编译应用以使 AndroidManifest.xml 的权限修改生效
- 在 Android 6.0+ 设备上，可能需要用户手动授予存储权限
- 建议在应用首次启动时请求必要的权限