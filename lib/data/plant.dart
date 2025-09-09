import 'package:json_annotation/json_annotation.dart';
import 'care.dart';
import 'care_history.dart';

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

  Plant(
      {required this.name,
      this.id = 0,
      this.location,
      this.description = "",
      required this.createdAt,
      this.picture,
      required this.cares,
      List<CareHistory>? careHistory}) : careHistory = careHistory ?? [];

  factory Plant.fromJson(Map<String, dynamic> json) => _$PlantFromJson(json);

  Map<String, dynamic> toJson() => _$PlantToJson(this);
}
