import 'dart:io';

import 'package:florae/data/plant.dart';
import 'package:florae/screens/care_plant.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/care.dart';
import '../data/default.dart';
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
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  int _loadedDays = 0;
  static const int _daysPerLoad = 7;

  @override
  void initState() {
    super.initState();
    _loadCareSchedule();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMoreData) {
      _loadMoreCareSchedule();
    }
  }

  Future<void> _loadCareSchedule() async {
    setState(() {
      _isLoading = true;
      _careSchedule.clear();
      _loadedDays = 0;
    });

    await _loadMoreCareSchedule();
  }

  Future<void> _loadMoreCareSchedule() async {
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<Plant> allPlants = await garden.getAllPlants();
      DateTime startDate = DateTime.now().add(Duration(days: _loadedDays));
      List<CareScheduleDay> newSchedule = _calculateCareSchedule(
        allPlants,
        startDate,
        _daysPerLoad,
      );

      setState(() {
        _careSchedule.addAll(newSchedule);
        _loadedDays += _daysPerLoad;
        _hasMoreData = newSchedule.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading care schedule: $e');
      setState(() {
        _isLoading = false;
        _hasMoreData = false;
      });
    }
  }

  List<CareScheduleDay> _calculateCareSchedule(List<Plant> plants) {
    Map<String, List<PlantCareTask>> scheduleMap = {};
    DateTime today = DateTime.now();
    DateTime currentDate = DateTime(today.year, today.month, today.day);

    print('=== 完整版开始计算养护计划，植物数量: ${plants.length} ===');
    
    // 计算每个植物的每类养护任务的待执行日期
    for (Plant plant in plants) {
      print('完整版处理植物: ${plant.name}, 养护类型数量: ${plant.cares.length}');
      
      if (plant.cares.isEmpty) continue;

      for (Care care in plant.cares) {
        print('完整版 养护类型: ${care.name}, 周期: ${care.cycles}天, 生效日期: ${care.effected}');
        
        if (care.cycles <= 0 || care.effected == null) continue;

        // 计算下次应该执行的日期
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
        
        // 使用更精确的最后一次执行日期
        if (lastSpecificCareDate != null) {
          lastCareDate = DateTime(
            lastSpecificCareDate.year,
            lastSpecificCareDate.month,
            lastSpecificCareDate.day,
          );
          print('完整版 使用历史记录日期: $lastCareDate');
        }

        // 智能计算下次待执行日期
        DateTime nextCareDate = lastCareDate;
        bool isOverdue = false;
        
        // 计算从最后执行日期到现在应该执行的次数
        int daysSinceLastCare = currentDate.difference(lastCareDate).inDays;
        
        if (daysSinceLastCare > care.cycles) {
          // 已经逾期，计算逾期了多少个周期
          int overdueCycles = (daysSinceLastCare / care.cycles).floor();
          
          // 下次执行日期应该是当前日期（逾期任务）
          nextCareDate = currentDate;
          isOverdue = true;
          
          print('完整版 已逾期 $overdueCycles 个周期，设为今日');
        } else {
          // 还未逾期，按正常周期计算
          nextCareDate = lastCareDate.add(Duration(days: care.cycles));
          print('完整版 正常计算，下次执行日期: $nextCareDate');
        }

        print('完整版 计算结果: 下次${care.name}日期: $nextCareDate');
        
        // 只添加这一个待执行日期
        String dateKey = DateFormat('yyyy-MM-dd').format(nextCareDate);
        
        if (scheduleMap[dateKey] == null) {
          scheduleMap[dateKey] = [];
        }

        scheduleMap[dateKey]!.add(PlantCareTask(
          plant: plant,
          care: care,
          isOverdue: isOverdue,
        ));
        
        print('完整版 添加到计划: $dateKey');
      }
    }

    // 转换为有序列表，按日期排序
    List<CareScheduleDay> result = [];
    List<String> sortedDates = scheduleMap.keys.toList()..sort();
    
    // 按日期排序显示
    for (String dateKey in sortedDates) {
      DateTime date = DateTime.parse(dateKey);
      result.add(CareScheduleDay(
        date: date,
        tasks: scheduleMap[dateKey]!,
      ));
    }

    print('完整版 计算完成，显示${result.length}天的数据 ===');
    return result;
  }

String _formatDate(DateTime date) {
  DateTime today = DateTime.now();
  DateTime tomorrow = today.add(Duration(days: 1));
  
  if (date.year == today.year && 
      date.month == today.month && 
      date.day == today.day) {
    return AppLocalizations.of(context)!.buttonToday;
  } else if (date.year == tomorrow.year && 
             date.month == tomorrow.month && 
             date.day == tomorrow.day) {
    return "明天";
  } else {
    String weekday = DateFormat.EEEE(Localizations.localeOf(context).languageCode).format(date);
    String dateStr = DateFormat('M月d日').format(date);
    return '$dateStr $weekday';
  }
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
    body: _careSchedule.isEmpty && !_isLoading
        ? _buildEmptyState()
        : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount: _careSchedule.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _careSchedule.length) {
                return _buildLoadingIndicator();
              }
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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    ),
  );
}

Widget _buildLoadingIndicator() {
  return Container(
    padding: const EdgeInsets.all(16.0),
    alignment: Alignment.center,
    child: const CircularProgressIndicator(),
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
          child: Text(
            _formatDate(day.date),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...day.tasks.map((task) => _buildTaskItem(task)).toList(),
      ],
    ),
  );
}

Widget _buildTaskItem(PlantCareTask task) {
  return InkWell(
    onTap: () => _onPlantTap(task.plant),
    child: Container(
      padding: const EdgeInsets.all(16.0),
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
              width: 50,
              height: 50,
              child: task.plant.picture != null && task.plant.picture!.isNotEmpty
                  ? (task.plant.picture!.contains("florae_avatar")
                      ? Image.asset(
                          task.plant.picture!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.local_florist, color: Colors.grey[600]),
                            );
                          },
                        )
                      : Image.file(
                          File(task.plant.picture!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.local_florist, color: Colors.grey[600]),
                            );
                          },
                        ))
                  : Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.local_florist, color: Colors.grey[600]),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // 植物名称
          Expanded(
            child: Text(
              task.plant.name,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // 养护任务图标们
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildCareIcons(task),
          ),
        ],
      ),
        ),
      ),
    );
  }

  List<Widget> _buildCareIcons(PlantCareTask task) {
    List<Care> cares = task.allCares ?? [task.care];
    List<Widget> icons = [];
    
    for (int i = 0; i < cares.length && i < 4; i++) {
      Care care = cares[i];
       
      // 计算逾期天数 - 确保只精确到天级别
      int overdueDays = 0;
      if (task.isOverdue) {
        DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        DateTime lastCareDate = DateTime(
          care.effected!.year,
          care.effected!.month,
          care.effected!.day,
        );
        
        // 找到这个养护类型的最后一次执行日期
        DateTime? lastSpecificCareDate;
        for (var history in task.plant.careHistory.reversed) {
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
        }
        
        DateTime expectedDate = lastCareDate.add(Duration(days: care.cycles));
        overdueDays = today.difference(expectedDate).inDays;
      }
      
      icons.add(
        Padding(
          padding: EdgeInsets.only(left: i > 0 ? 4.0 : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                DefaultValues.getCare(context, care.name)?.icon ?? Icons.help,
                color: task.isOverdue 
                    ? Colors.red 
                    : DefaultValues.getCare(context, care.name)?.color,
                size: 20,
              ),
              if (task.isOverdue && overdueDays > 0) ...[
                Text(
                  '$overdueDays天',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    // 如果有更多任务，显示省略号
    if (cares.length > 4) {
      icons.add(
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            '...',
            style: TextStyle(
              color: task.isOverdue ? Colors.red : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    
    return icons;
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
  final List<Care>? allCares;

  PlantCareTask({
    required this.plant,
    required this.care,
    required this.isOverdue,
    this.allCares,
  });
}