class TemporaryCare {
  int id = 0;
  String name; // 养护类型名称 (water, spray, rotate, etc.)
  DateTime scheduledDate; // 计划执行日期
  String? description; // 可选的描述

  TemporaryCare({
    this.id = 0,
    required this.name,
    required this.scheduledDate,
    this.description,
  });

  factory TemporaryCare.fromJson(Map<String, dynamic> json) => TemporaryCare(
    id: json['id'] ?? 0,
    name: json['name'],
    scheduledDate: DateTime.parse(json['scheduledDate']),
    description: json['description'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'scheduledDate': scheduledDate.toIso8601String(),
    'description': description,
  };

  // 检查临时任务是否已过期
  bool isOverdue(DateTime currentDate) {
    final today = DateTime(currentDate.year, currentDate.month, currentDate.day);
    final scheduled = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    return scheduled.isBefore(today);
  }

  // 检查临时任务是否是今天
  bool isToday(DateTime currentDate) {
    final today = DateTime(currentDate.year, currentDate.month, currentDate.day);
    final scheduled = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    return scheduled.isAtSameMomentAs(today);
  }

  // 获取距离计划日期的天数
  int daysUntilScheduled(DateTime currentDate) {
    final today = DateTime(currentDate.year, currentDate.month, currentDate.day);
    final scheduled = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    return scheduled.difference(today).inDays;
  }
}