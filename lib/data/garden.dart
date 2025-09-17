import 'dart:convert';
import 'package:florae/data/plant.dart';
import 'package:florae/data/temporary_care.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class Garden {
  late final SharedPreferences store;

  Garden(this.store);

  static Future<Garden> load() async {
    var store = await SharedPreferences.getInstance();

    await store.reload();

    return (Garden(store));
  }

  Future<List<Plant>> getAllPlants() async {
    List<Plant> allPlants = [];
    var rawPlants = store.getString("plants");
    if (kDebugMode) {
      print('--- 加载所有植物数据 ---');
      print('原始JSON数据: ${rawPlants != null ? '存在' : '不存在'}');
    }
    if (rawPlants != null) {
      try {
        Iterable l = json.decode(rawPlants);
        allPlants = List<Plant>.from(l.map((model) => Plant.fromJson(model)));
        if (kDebugMode) {
          print('成功解析植物数据，共 ${allPlants.length} 株植物');
          // 打印每株植物的临时任务数量
          allPlants.forEach((plant) {
            print('植物: ${plant.name}, 临时任务数量: ${plant.temporaryCares.length}');
            plant.temporaryCares.forEach((tempCare) {
              print('  - ${tempCare.name}, 日期: ${tempCare.scheduledDate}');
            });
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('解析植物数据失败: $e');
        }
      }
    }
    return allPlants;
  }

  // Returns true if update
  // Return false if create
  Future<bool> addOrUpdatePlant(Plant plant) async {
    List<Plant> allPlants = await getAllPlants();
    bool alreadyExists;

    var plantIndex = allPlants.indexWhere((element) => element.id == plant.id);
    if (plantIndex == -1) {
      allPlants.add(plant);
      alreadyExists = false;
    } else {
      allPlants[plantIndex] = plant;
      alreadyExists = true;
    }
    String jsonPlants = jsonEncode(allPlants);
    await store.setString("plants", jsonPlants);

    return alreadyExists;
  }

  Future<bool> deletePlant(Plant plant) async {
    List<Plant> allPlants = await getAllPlants();

    var plantIndex = allPlants.indexWhere((element) => element.id == plant.id);
    if (plantIndex != -1) {
      allPlants.removeAt(plantIndex);

      String jsonPlants = jsonEncode(allPlants);
      await store.setString("plants", jsonPlants);

      return true;
    } else {
      return false;
    }
  }

  Future<bool> updatePlant(Plant plant) async {
    if (kDebugMode) {
      print('--- 开始保存植物数据 ---');
      print('植物ID: ${plant.id}, 名称: ${plant.name}');
      print('临时养护任务数量: ${plant.temporaryCares.length}');
      plant.temporaryCares.forEach((tempCare) {
        print('临时任务: ${tempCare.name}, 日期: ${tempCare.scheduledDate}, ID: ${tempCare.id}');
      });
    }

    List<Plant> allPlants = await getAllPlants();
    if (kDebugMode) {
      print('当前所有植物数量: ${allPlants.length}');
    }

    var plantIndex = allPlants.indexWhere((element) => element.id == plant.id);
    if (plantIndex != -1) {
      allPlants[plantIndex] = plant;
      if (kDebugMode) {
        print('植物已存在，更新索引: $plantIndex');
      }

      String jsonPlants = jsonEncode(allPlants);
      if (kDebugMode && jsonPlants.length < 5000) { // 避免日志过长
        print('保存的JSON数据: $jsonPlants');
      }
      await store.setString("plants", jsonPlants);
      if (kDebugMode) {
        print('数据保存成功');
      }
      return true;
    } else {
      if (kDebugMode) {
        print('植物不存在，无法更新');
      }
      return false;
    }
  }

  // 清空所有花园数据
  Future<bool> clearAllData() async {
    try {
      await store.remove("plants");
      return true;
    } catch (e) {
      return false;
    }
  }
}
