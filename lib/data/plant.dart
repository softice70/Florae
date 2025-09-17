import 'dart:convert';
import 'care.dart';
import 'care_history.dart';
import 'temporary_care.dart';
import 'package:json_annotation/json_annotation.dart';

part 'plant.g.dart';

@JsonSerializable(explicitToJson: true)
class Plant {
  int id = 0;
  String name;
  String? location;
  String description;
  DateTime createdAt;
  String? picture;
  List<Care> cares = [];
  List<CareHistory> careHistory = [];
  List<TemporaryCare> temporaryCares = [];

  Plant(
      {required this.name,
      this.id = 0,
      this.location,
      this.description = "",
      required this.createdAt,
      this.picture,
      required this.cares,
      List<CareHistory>? careHistory,
      List<TemporaryCare>? temporaryCares}) : 
      careHistory = careHistory ?? [],
      temporaryCares = temporaryCares ?? [];

  // 手动实现fromJson方法，确保temporaryCares字段被正确反序列化
  factory Plant.fromJson(Map<String, dynamic> json) {
    var plant = _$PlantFromJson(json);
    // 手动处理temporaryCares字段
    if (json.containsKey('temporaryCares') && json['temporaryCares'] != null) {
      var tempCaresJson = json['temporaryCares'] as List<dynamic>;
      plant.temporaryCares = tempCaresJson
          .map((e) => TemporaryCare.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return plant;
  }

  // 手动实现toJson方法，确保temporaryCares字段被正确序列化
  Map<String, dynamic> toJson() {
    var json = _$PlantToJson(this);
    // 手动添加temporaryCares字段
    json['temporaryCares'] = temporaryCares.map((e) => e.toJson()).toList();
    return json;
  }
}
