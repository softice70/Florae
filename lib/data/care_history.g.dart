// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'care_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CareHistory _$CareHistoryFromJson(Map<String, dynamic> json) => CareHistory(
      careDate: DateTime.parse(json['careDate'] as String),
      careName: json['careName'] as String,
      details: json['details'] as String?,
    );

Map<String, dynamic> _$CareHistoryToJson(CareHistory instance) =>
    <String, dynamic>{
      'careDate': instance.careDate.toIso8601String(),
      'careName': instance.careName,
      'details': instance.details,
    };
