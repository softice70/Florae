import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:florae/data/backup/binary.dart';
import 'package:florae/data/backup/save.dart';
import 'package:florae/main.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class BackupManager {
  static Future<bool> backup() async {
    var plants = await garden.getAllPlants();

    List<Binary> binaries = [];

    var save = Save(binaries: binaries, garden: plants);

    for (final plant in plants) {
      if (!plant.picture!.contains("assets/")) {
        File picture = File(plant.picture!);
        String base64Image = base64Encode(await picture.readAsBytes());
        binaries.add(Binary(
            id: plant.id,
            base64Data: base64Image,
            fileName: basename(picture.path)));
      }
    }

    String jsonString = jsonEncode(save);
    List<int> bytes = utf8.encode(jsonString);
    Uint8List? binaryData = Uint8List.fromList(bytes);

    String? outputFile = await FilePicker.platform.saveFile(
      fileName: 'florae-backup.json',
      bytes: binaryData,
    );

    if (outputFile == null) {
      return false;
    } else {
      return true;
    }
  }

  static Future<bool> restore() async {
    try {
      // 指定文件类型过滤器，支持 JSON 文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
        withData: true, // 确保可以读取文件数据
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        
        // 优先使用 bytes 数据，如果没有则使用文件路径
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

        // 验证文件内容是否为有效的 JSON
        Map<String, dynamic> rawSave;
        try {
          rawSave = jsonDecode(fileContent);
        } catch (e) {
          // JSON 解析失败
          return false;
        }

        // 验证是否为有效的 Florae 备份文件
        if (!rawSave.containsKey('garden') || !rawSave.containsKey('binaries')) {
          return false;
        }

        var save = Save.fromJson(rawSave);

        for (var plant in save.garden) {
          var binary = save.binaries.where((x) => x.id == plant.id);
          if (binary.isNotEmpty) {
            var picture = binary.first;

            var path = await saveBinaryToFile(
                base64Decode(picture.base64Data), picture.fileName);
            plant.picture = path;
          }

          await garden.addOrUpdatePlant(plant);
        }

        return true;
      } else {
        return false;
      }
    } catch (ex) {
      // 记录错误信息以便调试
      print('Restore error: $ex');
      return false;
    }
  }

  static Future<String> saveBinaryToFile(
      Uint8List binaryData, String fileName) async {
    final Directory directory = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();

    final path = directory.path;

    final file = File('$path/$fileName');

    await file.writeAsBytes(binaryData);

    return file.path;
  }
}
