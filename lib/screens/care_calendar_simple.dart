import 'dart:io';

import 'package:florae/data/plant.dart';
import 'package:florae/screens/care_plant.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/care.dart';
import '../data/default.dart';
import '../data/temporary_care.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

class CareCalendarScreen extends StatefulWidget {
  const CareCalendarScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<CareCalendarScreen> createState() => _CareCalendarScreenState();
}

class _CareCalendarScreenState extends State<CareCalendarScreen> {
  List<CareScheduleDay> _careSchedule = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCareSchedule();
  }

  Future<void> _loadCareSchedule() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Plant> allPlants = await garden.getAllPlants();
      List<CareScheduleDay> schedule = _calculateCareSchedule(allPlants);

      setState(() {
        _careSchedule = schedule;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading care schedule: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<CareScheduleDay> _calculateCareSchedule(List<Plant> plants) {
    // 使用Map嵌套结构：dateKey -> plantId -> careName -> PlantCareTask
    // 这样可以方便地合并同一天同一植物同一类型的任务
    Map<String, Map<int, Map<String, PlantCareTask>>> scheduleMap = {};
    DateTime today = DateTime.now();
    DateTime currentDate = DateTime(today.year, today.month, today.day);

    print('=== 开始计算养护计划，植物数量: ${plants.length} ===');

    // 计算每个植物的每类养护任务的待执行日期
    for (Plant plant in plants) {
      print('处理植物: ${plant.name}, 养护类型数量: ${plant.cares.length}, 临时任务数量: ${plant.temporaryCares.length}');

      // 1. 处理定期任务
      for (Care care in plant.cares) {
        print(
            '  定期任务 - 养护类型: ${care.name}, 周期: ${care.cycles}天, 生效日期: ${care.effected}');

        if (care.cycles <= 0 || care.effected == null) continue;

        // 计算下次应该执行的日期 - 确保只精确到天级别
        DateTime lastCareDate = DateTime(
          care.effected!.year,
          care.effected!.month,
          care.effected!.day,
        );

        // 找到这个养护类型的最后一次执行日期
        DateTime? lastSpecificCareDate;
        for (var history in plant.careHistory.reversed) {
          if (history.careName == care.name) {
            lastSpecificCareDate = history.careDate;
            break;
          }
        }

        // 使用更精确的最后一次执行日期 - 确保只精确到天级别
        if (lastSpecificCareDate != null) {
          lastCareDate = DateTime(
            lastSpecificCareDate.year,
            lastSpecificCareDate.month,
            lastSpecificCareDate.day,
          );
          print('    使用历史记录日期: $lastCareDate');
        }

        // 智能计算下次待执行日期
        DateTime nextCareDate = lastCareDate;
        bool isOverdue = false;

        // 计算从最后执行日期到现在应该执行的次数 - 确保只精确到天级别
        int daysSinceLastCare = currentDate.difference(lastCareDate).inDays;

        if (daysSinceLastCare > care.cycles) {
          // 已经逾期，计算逾期了多少个周期
          int overdueCycles = (daysSinceLastCare / care.cycles).floor();

          // 下次执行日期应该是当前日期（逾期任务）
          nextCareDate = currentDate;
          isOverdue = true;

          print('    已逾期 $overdueCycles 个周期，设为今日');
        } else {
          // 还未逾期，按正常周期计算
          nextCareDate = lastCareDate.add(Duration(days: care.cycles));
          print('    正常计算，下次执行日期: $nextCareDate');
        }

        print('    计算结果: 下次${care.name}日期: $nextCareDate');

        // 添加定期任务到计划中
        _addToSchedule(scheduleMap, plant, care, nextCareDate, isOverdue, false);
      }

      // 2. 处理临时任务
      for (TemporaryCare tempCare in plant.temporaryCares) {
        // 确保临时任务的日期只精确到天级别
        DateTime tempCareDate = DateTime(
          tempCare.scheduledDate.year,
          tempCare.scheduledDate.month,
          tempCare.scheduledDate.day,
        );
        
        // 检查临时任务是否已过期
        bool isOverdue = tempCare.isOverdue(currentDate);
        
        // 如果临时任务已过期，则将待执行日期设为今日
        DateTime displayDate = isOverdue ? 
          DateTime(currentDate.year, currentDate.month, currentDate.day) : tempCareDate;
        
        print('  临时任务 - 养护类型: ${tempCare.name}, 原计划日期: $tempCareDate, 显示日期: $displayDate, 是否已逾期: $isOverdue');
        
        // 添加临时任务到计划中
        Care care = Care(
          name: tempCare.name,
          id: tempCare.id,
          cycles: 0,
          effected: tempCareDate, // 保留原始日期用于记录
        );
        _addToSchedule(scheduleMap, plant, care, displayDate, isOverdue, true);
      }
    }

    // 转换为有序列表，按日期排序
    List<CareScheduleDay> result = [];
    List<String> sortedDates = scheduleMap.keys.toList()..sort();

    // 按日期排序显示
    for (String dateKey in sortedDates) {
      DateTime date = DateTime.parse(dateKey);
      
      // 扁平化任务列表
      List<PlantCareTask> tasks = [];
      scheduleMap[dateKey]?.forEach((plantId, careTasks) {
        tasks.addAll(careTasks.values);
      });
      
      result.add(CareScheduleDay(
        date: date,
        tasks: tasks,
      ));
    }

    print('=== 计算完成，显示${result.length}天的数据 ===');
    return result;
  }
  
  // 辅助方法：添加任务到计划中，并处理合并逻辑
  void _addToSchedule(
    Map<String, Map<int, Map<String, PlantCareTask>>> scheduleMap,
    Plant plant,
    Care care,
    DateTime careDate,
    bool isOverdue,
    bool isTemporary,
  ) {
    String dateKey = DateFormat('yyyy-MM-dd').format(careDate);
    
    // 初始化嵌套Map结构
    if (scheduleMap[dateKey] == null) {
      scheduleMap[dateKey] = {};
    }
    if (scheduleMap[dateKey]![plant.id] == null) {
      scheduleMap[dateKey]![plant.id] = {};
    }
    
    // 检查是否已存在该类型任务
    PlantCareTask? existingTask = scheduleMap[dateKey]![plant.id]![care.name];
    
    if (existingTask != null) {
      // 如果已存在相同日期、相同植物、相同类型的任务，则合并
      print('    合并任务: 植物${plant.name}的${care.name}任务已存在，保留较早的时间');
      
      // 保留较早的时间（这里由于我们已经精确到天级别，所以直接保留现有任务即可）
      // 保持isOverdue状态，如果任一任务已逾期，则合并后任务也视为逾期
      bool mergedIsOverdue = existingTask.isOverdue || isOverdue;
      
      scheduleMap[dateKey]![plant.id]![care.name] = PlantCareTask(
        plant: plant,
        care: care,
        isOverdue: mergedIsOverdue,
      );
    } else {
      // 添加新任务
      scheduleMap[dateKey]![plant.id]![care.name] = PlantCareTask(
        plant: plant,
        care: care,
        isOverdue: isOverdue,
      );
      print('    添加到计划: $dateKey, 植物: ${plant.name}, 任务: ${care.name}');
    }
  }

  String _formatDate(DateTime date) {
    DateTime today = DateTime.now();
    DateTime tomorrow = today.add(Duration(days: 1));

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return "今天";
    } else if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return "明天";
    } else {
      String weekday =
          DateFormat.EEEE(Localizations.localeOf(context).languageCode)
              .format(date);
      String dateStr = DateFormat('M月d日').format(date);
      return '$dateStr $weekday';
    }
  }

  Widget _buildDateText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    final daysDifference = checkDate.difference(today).inDays;

    String mainText = _formatDate(date);

    // 如果是今天，不显示天数差
    if (daysDifference == 0) {
      return Text(
        mainText,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      );
    }

    // 未来日期显示天数差
    String daysText = '';
    if (daysDifference > 0) {
      daysText = '     ${daysDifference}天后';
    } else {
      // 过去日期显示天数差（虽然养护计划通常不会有过去的日期）
      daysText = '     ${-daysDifference}天前';
    }

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: mainText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          TextSpan(
            text: daysText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }

  void _onPlantTap(Plant plant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarePlantScreen(title: plant.name),
        settings: RouteSettings(arguments: plant),
      ),
    );
    // 从详情页返回时重新加载数据
    _loadCareSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: FittedBox(
          fit: BoxFit.fitWidth,
          child: Text('养护计划'),
        ),
        titleTextStyle: Theme.of(context).textTheme.displayLarge,
        backgroundColor: Colors.transparent,
        elevation: 0.0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _careSchedule.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _careSchedule.length,
                  itemBuilder: (context, index) {
                    return _buildDayCard(_careSchedule[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无养护计划',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '您的植物目前都不需要养护',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(CareScheduleDay day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: _buildDateText(day.date),
          ),
          ..._buildGroupedTaskItems(day.tasks),
        ],
      ),
    );
  }

  Widget _buildTaskItem(PlantCareTask task) {
    // 计算逾期天数 - 确保只精确到天级别
    int overdueDays = 0;
    if (task.isOverdue) {
      DateTime today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      DateTime lastCareDate = DateTime(
        task.care.effected!.year,
        task.care.effected!.month,
        task.care.effected!.day,
      );

      // 找到这个养护类型的最后一次执行日期
      DateTime? lastSpecificCareDate;
      for (var history in task.plant.careHistory.reversed) {
        if (history.careName == task.care.name) {
          lastSpecificCareDate = history.careDate;
          break;
        }
      }

      // 使用更精确的最后一次执行日期 - 确保只精确到天级别
      if (lastSpecificCareDate != null) {
        lastCareDate = DateTime(
          lastSpecificCareDate.year,
          lastSpecificCareDate.month,
          lastSpecificCareDate.day,
        );
      }

      DateTime expectedDate =
          lastCareDate.add(Duration(days: task.care.cycles));
      overdueDays = today.difference(expectedDate).inDays;
    }

    return InkWell(
      onTap: () => _onPlantTap(task.plant),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // 植物缩略图
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: _buildPlantImage(task.plant),
              ),
            ),
            const SizedBox(width: 12),
            // 植物名称和养护类型
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.plant.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DefaultValues.getCare(context, task.care.name)
                            ?.translatedName ??
                        task.care.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: task.isOverdue ? Colors.red : Colors.grey[600],
                          fontWeight: task.isOverdue
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                  ),
                  if (task.isOverdue && overdueDays > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '已逾期$overdueDays天',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 养护任务图标
            Icon(
              DefaultValues.getCare(context, task.care.name)?.icon ??
                  Icons.help,
              color: task.isOverdue
                  ? Colors.red
                  : DefaultValues.getCare(context, task.care.name)?.color,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantImage(Plant plant) {
    if (plant.picture == null || plant.picture!.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Icon(Icons.local_florist, color: Colors.grey[600]),
      );
    }

    if (plant.picture!.contains("florae_avatar")) {
      return Image.asset(
        plant.picture!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.local_florist, color: Colors.grey[600]),
          );
        },
      );
    } else {
      return Image.file(
        File(plant.picture!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.local_florist, color: Colors.grey[600]),
          );
        },
      );
    }
  }

  // 将同一植物的多个养护任务合并显示
  List<Widget> _buildGroupedTaskItems(List<PlantCareTask> tasks) {
    // 按植物分组
    Map<String, List<PlantCareTask>> groupedTasks = {};
    for (var task in tasks) {
      String plantKey = task.plant.id.toString();
      if (groupedTasks[plantKey] == null) {
        groupedTasks[plantKey] = [];
      }
      groupedTasks[plantKey]!.add(task);
    }

    // 为每个植物创建一个合并的列表项
    return groupedTasks.values.map((plantTasks) {
      return _buildGroupedTaskItem(plantTasks);
    }).toList();
  }

  Widget _buildGroupedTaskItem(List<PlantCareTask> plantTasks) {
    Plant plant = plantTasks.first.plant;
    bool hasOverdueTasks = plantTasks.any((task) => task.isOverdue);

    return InkWell(
      onTap: () => _onPlantTap(plant),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // 植物缩略图
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: _buildPlantImage(plant),
              ),
            ),
            const SizedBox(width: 12),
            // 植物名称和养护图标
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plant.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 养护图标行
                  Row(
                    children: plantTasks.map((task) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Icon(
                          DefaultValues.getCare(context, task.care.name)
                                  ?.icon ??
                              Icons.help,
                          color: task.isOverdue
                              ? Colors.red
                              : DefaultValues.getCare(context, task.care.name)
                                  ?.color,
                          size: 20,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // 如果有逾期任务，显示警告图标
            if (hasOverdueTasks) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.warning,
                color: Colors.red,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 数据模型类
class CareScheduleDay {
  final DateTime date;
  final List<PlantCareTask> tasks;

  CareScheduleDay({
    required this.date,
    required this.tasks,
  });
}

class PlantCareTask {
  final Plant plant;
  final Care care;
  final bool isOverdue;

  PlantCareTask({
    required this.plant,
    required this.care,
    required this.isOverdue,
  });
}
