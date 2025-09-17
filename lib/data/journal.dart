import 'dart:convert';

class JournalEntry {
  int id;
  DateTime createdAt;
  String content;

  JournalEntry({
    this.id = 0,
    required this.createdAt,
    required this.content,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] ?? 0,
        createdAt: DateTime.parse(json['createdAt']),
        content: json['content'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'content': content,
      };

  // 获取月份标题格式: xxxx年xx月
  String getMonthTitle() {
    return '${createdAt.year}年${createdAt.month.toString().padLeft(2, '0')}月';
  }

  // 获取日期时间格式: MM/DD hh:mm
  String getDateTimeFormat() {
    return '${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}