// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Save _$SaveFromJson(Map<String, dynamic> json) => Save(
      binaries: (json['binaries'] as List<dynamic>)
          .map((e) => Binary.fromJson(e as Map<String, dynamic>))
          .toList(),
      garden: (json['garden'] as List<dynamic>)
          .map((e) => Plant.fromJson(e as Map<String, dynamic>))
          .toList(),
      journals: (json['journals'] as List<dynamic>?)
              ?.map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <JournalEntry>[],
      currentCity: json['currentCity'] as String? ?? '',
    )
      ..version = (json['version'] as num).toInt()
      ..createdAt = DateTime.parse(json['createdAt'] as String);

Map<String, dynamic> _$SaveToJson(Save instance) => <String, dynamic>{
      'version': instance.version,
      'createdAt': instance.createdAt.toIso8601String(),
      'binaries': instance.binaries.map((e) => e.toJson()).toList(),
      'garden': instance.garden.map((e) => e.toJson()).toList(),
      'journals': instance.journals.map((e) => e.toJson()).toList(),
      'currentCity': instance.currentCity,
    };
