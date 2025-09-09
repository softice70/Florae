import 'package:json_annotation/json_annotation.dart';

part 'care_history.g.dart';

@JsonSerializable()
class CareHistory {
  DateTime careDate;
  String careName;
  String? details;

  CareHistory({
    required this.careDate,
    required this.careName,
    this.details,
  });

  factory CareHistory.fromJson(Map<String, dynamic> json) => _$CareHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$CareHistoryToJson(this);
}