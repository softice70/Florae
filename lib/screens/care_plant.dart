import 'dart:io';

import 'package:florae/data/plant.dart';
import 'package:florae/screens/picture_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../data/care.dart';
import '../data/care_history.dart';
import '../data/temporary_care.dart';
import '../data/default.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'manage_plant.dart';

class CarePlantScreen extends StatefulWidget {
  const CarePlantScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<CarePlantScreen> createState() => _CarePlantScreen();
}

class _CarePlantScreen extends State<CarePlantScreen> {
  int periodicityInHours = 1;
  bool _isPlantDetailsExpanded = false; // 植物详情卡片默认折叠
  Map<Care, bool?> careCheck = {};
  Map<Care, TextEditingController> careDetailsControllers = {};
  DateTime selectedCareDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  
  // 临时养护任务相关状态
  Map<TemporaryCare, bool?> temporaryCareCheck = {};
  Map<TemporaryCare, TextEditingController> temporaryCareDetailsControllers = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // 释放所有文本控制器
    for (final controller in careDetailsControllers.values) {
      controller.dispose();
    }
    for (final controller in temporaryCareDetailsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String buildCareMessage(int daysToCare) {
    if (daysToCare == 0) {
      return AppLocalizations.of(context)!.now;
    } else if (daysToCare < 0) {
      return "${AppLocalizations.of(context)!.daysLate} ${daysToCare.abs()} ${AppLocalizations.of(context)!.days}";
    } else {
      return "$daysToCare ${AppLocalizations.of(context)!.daysLeft}";
    }
  }

  List<Widget> _buildCares(BuildContext context, Plant plant) {
    List<Widget> careWidgets = [];

    // 获取标准的养护类型顺序
    final standardCareOrder = [
      'water',
      'spray', 
      'rotate',
      'prune',
      'fertilise',
      'transplant',
      'clean'
    ];

    // 按照标准顺序遍历养护类型
    for (String careType in standardCareOrder) {
      // 查找植物是否有这种养护类型
      Care? care = plant.cares.firstWhere(
        (c) => c.name == careType,
        orElse: () => Care(name: '', cycles: 0, effected: null, id: 0),
      );
      
      // 如果植物没有这种养护类型，跳过
      if (care.name.isEmpty) continue;
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      int daysToCare = care.cycles - care.daysSinceLastCare(today);

      if (careCheck[care] == null) {
        careCheck[care] = false;
      }

      // 为每个养护任务创建文本控制器
      if (careDetailsControllers[care] == null) {
        careDetailsControllers[care] = TextEditingController();

        // 查找今天已有的养护记录
        final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final todayRecord = plant.careHistory.firstWhere(
          (history) =>
              history.careName == care.name &&
              history.careDate.year == today.year &&
              history.careDate.month == today.month &&
              history.careDate.day == today.day,
          orElse: () => CareHistory(careDate: today, careName: care.name),
        );

        // 如果今天已有记录，预填详情
        if (todayRecord.details != null) {
          careDetailsControllers[care]!.text = todayRecord.details!;
        }
      }

      careWidgets.add(
        CheckboxListTile(
          title: Row(
            children: [
              Text(DefaultValues.getCare(context, care.name)!.translatedName),
              const SizedBox(width: 8),
              Text(
                '每${care.cycles}天一次',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          subtitle: Text(
            buildCareMessage(daysToCare),
            style: TextStyle(
              color: daysToCare < 0 ? Colors.red : null,
            ),
          ),
          value: careCheck[care],
          onChanged: (bool? value) {
            setState(() {
              careCheck[care] = value;

              // 当checkbox状态改变时，查找今天的记录
              if (value == true) {
                final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                final todayRecord = plant.careHistory.firstWhere(
                  (history) =>
                      history.careName == care.name &&
                      history.careDate.year == today.year &&
                      history.careDate.month == today.month &&
                      history.careDate.day == today.day,
                  orElse: () =>
                      CareHistory(careDate: today, careName: care.name),
                );

                if (todayRecord.details != null) {
                  careDetailsControllers[care]!.text = todayRecord.details!;
                }
              }
            });
          },
          secondary: Icon(DefaultValues.getCare(context, care.name)!.icon,
              color: DefaultValues.getCare(context, care.name)!.color),
        ),
      );

      // 如果养护任务被选中，显示详情输入框
      if (careCheck[care] == true) {
        careWidgets.add(
          Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: TextField(
              controller: careDetailsControllers[care],
              decoration: InputDecoration(
                hintText:
                    '记录${DefaultValues.getCare(context, care.name)!.translatedName}详情（可选）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.all(12.0),
              ),
              maxLines: 10,
              minLines: 1,
            ),
          ),
        );
      }
    }

    // 如果有选中的养护任务，显示日期选择、取消和保存按钮
      final hasSelectedCares =
          careCheck.values.any((selected) => selected == true);
      if (hasSelectedCares) {
        careWidgets.add(
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 日期选择按钮
                TextButton.icon(
                  onPressed: () async {
                    // 获取上一条养护记录的日期（如果有的话）
                    DateTime? previousRecordDate;
                    final sortedHistory = List<CareHistory>.from(plant.careHistory)
                      ..sort((a, b) => b.careDate.compareTo(a.careDate));

                    if (sortedHistory.isNotEmpty) {
                      previousRecordDate = sortedHistory.first.careDate;
                    }

                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedCareDate,
                      firstDate: previousRecordDate
                              ?.add(const Duration(days: 1)) ??
                          DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(const Duration(days: 365)),
                      lastDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
                      locale: Localizations.localeOf(context),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedCareDate = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    DateFormat('MM-dd').format(selectedCareDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      // 重置所有复选框为未选中状态
                      for (var care in plant.cares) {
                        careCheck[care] = false;
                      }
                      
                      // 清空所有文本控制器的文本内容
                      for (var controller in careDetailsControllers.values) {
                        controller.clear();
                      }
                      
                      // 重置日期为今天
                      selectedCareDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                    });
                  },
                  child: Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    if (!careCheck.containsValue(true)) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text(AppLocalizations.of(context)!.noCaresError)));
                      return;
                    }
                    
                    final selectedDateStart =
                        DateTime(selectedCareDate.year, selectedCareDate.month, selectedCareDate.day);

                    careCheck.forEach((key, value) {
                      if (value == true) {
                        var careIndex = plant.cares
                            .indexWhere((element) => element.name == key.name);
                        if (careIndex != -1) {
                          plant.cares[careIndex].effected = selectedDateStart; // 确保只精确到天级别

                          // 获取养护详情
                          String? details =
                              careDetailsControllers[key]?.text.trim();
                          if (details != null && details.isEmpty) {
                            details = null;
                          }

                          // 移除选定日期已有的同种养护记录
                          plant.careHistory.removeWhere((history) {
                            if (history.careName != key.name) return false;
                            
                            // 将历史记录的日期也精确到天级别进行比较
                            DateTime historyDate = DateTime(
                              history.careDate.year,
                              history.careDate.month,
                              history.careDate.day,
                            );
                            
                            return historyDate.isAtSameMomentAs(selectedDateStart);
                          });

                          // 添加新的养护记录
                          plant.careHistory.add(CareHistory(
                            careDate: selectedDateStart, // 确保只精确到天级别
                            careName: key.name,
                            details: details,
                          ));
                        }
                      }
                    });

                    await garden.updatePlant(plant);

                    // 重置养护卡片状态
                    setState(() {
                      // 重置所有复选框为未选中状态
                      for (var care in plant.cares) {
                        careCheck[care] = false;
                      }
                      
                      // 清空所有文本控制器的文本内容
                      for (var controller in careDetailsControllers.values) {
                        controller.clear();
                      }
                      
                      // 重置日期为今天
                      selectedCareDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                    });

                    // 显示成功提示
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text(AppLocalizations.of(context)!.careSuccess)));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('确定'),
                ),
              ],
            ),
          ),
        );
      }

    return careWidgets;
  }

  List<Widget> _buildTemporaryCares(BuildContext context, Plant plant) {
    List<Widget> temporaryCareWidgets = [];

    if (plant.temporaryCares.isEmpty) {
      temporaryCareWidgets.add(
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '暂无临时养护任务',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
      return temporaryCareWidgets;
    }

    // 按日期排序临时任务
    final sortedTemporaryCares = List<TemporaryCare>.from(plant.temporaryCares)
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    for (TemporaryCare temporaryCare in sortedTemporaryCares) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      int daysUntilScheduled = temporaryCare.daysUntilScheduled(today);

      if (temporaryCareCheck[temporaryCare] == null) {
        temporaryCareCheck[temporaryCare] = false;
      }

      // 为每个临时养护任务创建文本控制器
      if (temporaryCareDetailsControllers[temporaryCare] == null) {
        temporaryCareDetailsControllers[temporaryCare] = TextEditingController();
        if (temporaryCare.description != null) {
          temporaryCareDetailsControllers[temporaryCare]!.text = temporaryCare.description!;
        }
      }

      String statusMessage;
      Color? statusColor;
      if (daysUntilScheduled == 0) {
        statusMessage = '今天';
        statusColor = Colors.orange;
      } else if (daysUntilScheduled < 0) {
        statusMessage = '已过期 ${daysUntilScheduled.abs()} 天';
        statusColor = Colors.red;
      } else {
        statusMessage = '还有 $daysUntilScheduled 天';
        statusColor = null;
      }

      temporaryCareWidgets.add(
        CheckboxListTile(
          title: Row(
            children: [
              Text(DefaultValues.getCare(context, temporaryCare.name)!.translatedName),
              const SizedBox(width: 8),
              Text(
                '临时任务',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          subtitle: Text(
            statusMessage,
            style: TextStyle(
              color: statusColor,
            ),
          ),
          value: temporaryCareCheck[temporaryCare],
          onChanged: (bool? value) {
            setState(() {
              temporaryCareCheck[temporaryCare] = value;
              // 确保文本控制器存在并包含正确的描述内容
              if (temporaryCareDetailsControllers[temporaryCare] == null) {
                temporaryCareDetailsControllers[temporaryCare] = TextEditingController();
              }
              if (temporaryCare.description != null) {
                temporaryCareDetailsControllers[temporaryCare]!.text = temporaryCare.description!;
              } else {
                temporaryCareDetailsControllers[temporaryCare]!.clear();
              }
            });
          },
          secondary: Icon(DefaultValues.getCare(context, temporaryCare.name)!.icon,
              color: DefaultValues.getCare(context, temporaryCare.name)!.color),
        ),
      );

      // 如果临时养护任务被选中，显示详情输入框和操作按钮
      if (temporaryCareCheck[temporaryCare] == true) {
        temporaryCareWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: TextField(
              controller: temporaryCareDetailsControllers[temporaryCare],
              decoration: InputDecoration(
                hintText: '记录${DefaultValues.getCare(context, temporaryCare.name)!.translatedName}详情（可选）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.all(12.0),
              ),
              maxLines: 10,
              minLines: 1,
            ),
          ),
        );

        // 添加操作按钮
        temporaryCareWidgets.add(
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      temporaryCareCheck[temporaryCare] = false;
                      temporaryCareDetailsControllers[temporaryCare]?.clear();
                    });
                  },
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    // 删除临时任务
                    setState(() {
                      plant.temporaryCares.remove(temporaryCare);
                      temporaryCareCheck.remove(temporaryCare);
                      temporaryCareDetailsControllers[temporaryCare]?.dispose();
                      temporaryCareDetailsControllers.remove(temporaryCare);
                    });
                    await garden.updatePlant(plant);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('临时任务已删除')),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('删除'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    // 完成临时任务
                    final selectedDateStart = DateTime(
                      selectedCareDate.year,
                      selectedCareDate.month,
                      selectedCareDate.day,
                    );

                    // 获取养护详情
                    String? details = temporaryCareDetailsControllers[temporaryCare]?.text.trim();
                    if (details != null && details.isEmpty) {
                      details = null;
                    }

                    // 检查当天是否已有相同类型的养护记录
                    final existingRecordIndex = plant.careHistory.indexWhere(
                      (record) => record.careDate == selectedDateStart && record.careName == temporaryCare.name
                    );

                    if (existingRecordIndex != -1) {
                      // 如果存在记录且详情不为空，则更新详情
                      if (details != null) {
                        plant.careHistory[existingRecordIndex] = CareHistory(
                          careDate: selectedDateStart,
                          careName: temporaryCare.name,
                          details: details,
                        );
                      }
                    } else {
                      // 如果不存在记录，则添加新记录
                      plant.careHistory.add(CareHistory(
                        careDate: selectedDateStart,
                        careName: temporaryCare.name,
                        details: details,
                      ));
                    }

                    // 更新对应类型的定期养护任务的effected字段
                    var careIndex = plant.cares
                        .indexWhere((element) => element.name == temporaryCare.name);
                    if (careIndex != -1) {
                      plant.cares[careIndex].effected = selectedDateStart; // 确保只精确到天级别
                    }

                    // 删除临时任务
                    plant.temporaryCares.remove(temporaryCare);
                    temporaryCareCheck.remove(temporaryCare);
                    temporaryCareDetailsControllers[temporaryCare]?.dispose();
                    temporaryCareDetailsControllers.remove(temporaryCare);

                    await garden.updatePlant(plant);

                    setState(() {});

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('临时任务已完成')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('确定'),
                ),
              ],
            ),
          ),
        );
      }
    }

    return temporaryCareWidgets;
  }

  Widget _buildCareHistory(Plant plant) {
    if (plant.careHistory.isEmpty) {
      return SizedBox(
          width: double.infinity,
          child: Card(
                  semanticContainer: true,
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(
                    children: [
                      // 添加标题
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('养护记录'),
                        tileColor: Colors.green.shade50,
                      ),
                      const Divider(height: 1, thickness: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            '暂无养护记录',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
          ))
      );
    }

    // 按日期排序，最新的在前
    final sortedHistory = List<CareHistory>.from(plant.careHistory)
      ..sort((a, b) => b.careDate.compareTo(a.careDate));

    // 按日期分组
    final groupedHistory = <String, List<CareHistory>>{};
    for (var history in sortedHistory) {
      final dateKey = DateFormat.Md().format(history.careDate);
      if (!groupedHistory.containsKey(dateKey)) {
        groupedHistory[dateKey] = [];
      }
      groupedHistory[dateKey]!.add(history);
    }

    // 找到最近一天的日期
    final latestDate = sortedHistory.isNotEmpty
        ? DateTime(
            sortedHistory.first.careDate.year,
            sortedHistory.first.careDate.month,
            sortedHistory.first.careDate.day)
        : null;

    return SizedBox(
        width: double.infinity,
        child: Card(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('养护记录'),
                  tileColor: Colors.green.shade50,
                  trailing: latestDate != null
                      ? IconButton(
                          icon: const Icon(Icons.history_edu, size: 20),
                          onPressed: () {
                            _editLatestDayCareHistory(context, plant, latestDate);
                          },
                          tooltip: '修改最近一天的养护记录',
                        )
                      : null,
                ),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 8),
                ...groupedHistory.entries.map((entry) {
                  final date = entry.key;
                  final histories = entry.value;
                  final isLatestDay = latestDate != null &&
                      DateFormat.Md().format(latestDate) == date;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40, // 日期列宽度 - 适中宽度
                          child: Text(
                            date,
                            textAlign: TextAlign.right, // 日期文字右对齐
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                      fontWeight: isLatestDay
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: histories.map((history) {
                              final careInfo = DefaultValues.getCare(
                                  context, history.careName);
                              final icon = careInfo?.icon ?? Icons.help_outline;
                              final color = careInfo?.color ?? Colors.grey;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24, // 固定图标容器宽度
                                      child: Icon(
                                        icon,
                                        size: 16,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${DefaultValues.getCare(context, history.careName)?.translatedName ?? history.careName}${history.details?.isNotEmpty == true ? ' ${history.details}' : ''}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
        ));
  }

  Plant? _currentPlant;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_currentPlant == null) {
      _currentPlant = ModalRoute.of(context)!.settings.arguments as Plant;
    }
  }

  Future<void> _reloadPlantData() async {
    if (_currentPlant != null) {
      final allPlants = await garden.getAllPlants();
      final updatedPlant = allPlants.firstWhere(
        (p) => p.id == _currentPlant!.id,
        orElse: () => _currentPlant!,
      );
      setState(() {
        _currentPlant = updatedPlant;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plant = _currentPlant ?? (ModalRoute.of(context)!.settings.arguments as Plant);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: FittedBox(fit: BoxFit.fitWidth, child: Text(plant.name)),
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            iconSize: 25,
            color: Theme.of(context).colorScheme.primary,
            tooltip: AppLocalizations.of(context)!.tooltipEdit,
            onPressed: () async {
              final result = await Navigator.push(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (context) => ManagePlantScreen(
                        title: "Manage plant", update: true, plant: plant),
                  ));
              
              // 如果编辑成功，重新加载植物数据
              if (result == true) {
                await _reloadPlantData();
              }
            },
          )
        ],
        titleTextStyle: Theme.of(context).textTheme.displayLarge,
      ),
      //passing in the ListView.builder
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: <Widget>[
              Card(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    if (!plant.picture!.contains("assets/")) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PictureViewer(
                                  picture: plant.picture,
                                )),
                      );
                    }
                  },
                  child: SizedBox(
                      child: Column(
                    children: <Widget>[
                      ClipRRect(
                        child: SizedBox(
                          height: 220,
                          child: plant.picture!.contains("assets/")
                              ? Image.asset(
                                  plant.picture!,
                                  fit: BoxFit.fitHeight,
                                )
                              : Image.file(
                                  File(plant.picture!),
                                  fit: BoxFit.fitWidth,
                                ),
                        ),
                      ),
                    ],
                  )),
                ),
              ),
              Card(
                semanticContainer: true,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('植物详情'),
                      trailing: Icon(_isPlantDetailsExpanded 
                          ? Icons.expand_less 
                          : Icons.expand_more),
                      tileColor: Colors.green.shade50,
                      onTap: () {
                        setState(() {
                          _isPlantDetailsExpanded = !_isPlantDetailsExpanded;
                        });
                      },
                    ),
                    if (_isPlantDetailsExpanded)
                      Column(
                        children: [
                          const Divider(height: 1, thickness: 1),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 第一行：图标和标题（保持原有的左右边距）
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.topic),
                                    const SizedBox(width: 16.0),
                                    Text(
                                      AppLocalizations.of(context)!.labelDescription,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                              // 第二行：详情文字内容（减少左右边距，增加显示宽度）
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 0,
                                  right: 0,
                                  bottom: 8.0,
                                ),
                                child: Markdown(
                                  data: plant.description,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  styleSheet: MarkdownStyleSheet(
                                    p: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ListTile(
                            leading: const Icon(Icons.location_on),
                            title: Text(AppLocalizations.of(context)!.labelLocation),
                            subtitle: Text(plant.location ?? ""),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.eco),
                            title:
                                Text(AppLocalizations.of(context)!.labelDayPlanted),
                            subtitle: Text(DateFormat.yMMMMd(
                                    Localizations.localeOf(context).languageCode)
                                .format(plant.createdAt)),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Card(
                  semanticContainer: true,
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(
                    children: [
                      // 添加标题
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('定期养护任务'),
                        tileColor: Colors.green.shade50,
                      ),
                      const Divider(height: 1, thickness: 1),
                      ..._buildCares(context, plant),
                    ],
                  )),
              const SizedBox(height: 16),
              // 临时养护任务卡片
              Card(
                  semanticContainer: true,
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(
                    children: [
                      // 临时养护任务标题
                      ListTile(
                        leading: const Icon(Icons.add_task),
                        title: const Text('临时养护任务'),
                        tileColor: Colors.green.shade50,
                        trailing: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            _showAddTemporaryCareDialog(context, plant);
                          },
                          tooltip: '添加临时任务',
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),
                      ..._buildTemporaryCares(context, plant),
                    ],
                  )),
              const SizedBox(height: 16),
              // 历史养护记录
              _buildCareHistory(plant),
              const SizedBox(height: 70),
            ],
          ),
        ),
      ),
    );
  }

  void _editLatestDayCareHistory(
      BuildContext context, Plant plant, DateTime latestDate) {
    final careDetailsControllers = <String, TextEditingController>{};
    DateTime selectedDate = latestDate;

    // 获取当天有记录的养护类型
    final dayRecords = plant.careHistory
        .where((h) =>
            h.careDate.day == latestDate.day &&
            h.careDate.month == latestDate.month &&
            h.careDate.year == latestDate.year)
        .toList();

    // 获取唯一的养护类型名称
    final recordedCareTypes = dayRecords.map((h) => h.careName).toSet();

    // 为每个有记录的养护类型创建控制器
    final careTypes = DefaultValues.getCares(context);
    for (var careName in recordedCareTypes) {
      final existingHistory = dayRecords.firstWhere(
          (h) => h.careName == careName,
          orElse: () => CareHistory(careDate: latestDate, careName: careName));

      careDetailsControllers[careName] =
          TextEditingController(text: existingHistory.details ?? '');
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('修改 ${DateFormat.Md().format(latestDate)} 的养护记录'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('日期'),
                      subtitle: Text(DateFormat.yMd().format(selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        // 获取上一条养护记录的日期（如果有的话）
                        DateTime? previousRecordDate;
                        final sortedHistory = plant.careHistory
                            .where((h) =>
                                h.careDate.year != latestDate.year ||
                                h.careDate.month != latestDate.month ||
                                h.careDate.day != latestDate.day)
                            .toList()
                          ..sort((a, b) => b.careDate.compareTo(a.careDate));

                        if (sortedHistory.isNotEmpty) {
                          previousRecordDate = sortedHistory.first.careDate;
                        }

                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: previousRecordDate
                                  ?.add(const Duration(days: 1)) ??
                              DateTime.now()
                                  .subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ...recordedCareTypes.map((careName) {
                      final care = careTypes[careName];
                      if (care == null) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TextField(
                          controller: careDetailsControllers[careName],
                          decoration: InputDecoration(
                            labelText: care.translatedName,
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(care.icon, color: care.color),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 10,
                          minLines: 2,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    // 删除当前正在编辑的特定日期的记录
                    plant.careHistory.removeWhere((h) =>
                        h.careDate.year == latestDate.year &&
                        h.careDate.month == latestDate.month &&
                        h.careDate.day == latestDate.day &&
                        recordedCareTypes.contains(h.careName));
                    garden.updatePlant(plant);
                    Navigator.of(context).pop();
                    setState(() {});
                  },
                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    // 删除当前正在编辑的特定日期的记录
                    plant.careHistory.removeWhere((h) =>
                        h.careDate.year == latestDate.year &&
                        h.careDate.month == latestDate.month &&
                        h.careDate.day == latestDate.day &&
                        recordedCareTypes.contains(h.careName));

                    // 添加更新后的记录
                    for (var careName in recordedCareTypes) {
                      final details =
                          careDetailsControllers[careName]?.text.trim();
                      plant.careHistory.add(CareHistory(
                        careName: careName,
                        careDate: selectedDate,
                        details: (details != null && details.isNotEmpty)
                            ? details
                            : null,
                      ));
                    }

                    garden.updatePlant(plant);
                    Navigator.of(context).pop();
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddTemporaryCareDialog(BuildContext context, Plant plant) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AddTemporaryCareDialog(
          plant: plant,
          onTaskAdded: () {
            setState(() {});
          },
        );
      },
    );
  }
}

class _AddTemporaryCareDialog extends StatefulWidget {
  final Plant plant;
  final VoidCallback onTaskAdded;

  const _AddTemporaryCareDialog({
    required this.plant,
    required this.onTaskAdded,
  });

  @override
  State<_AddTemporaryCareDialog> createState() => _AddTemporaryCareDialogState();
}

class _AddTemporaryCareDialogState extends State<_AddTemporaryCareDialog> {
  String? selectedCareType;
  DateTime selectedDate = DateTime.now();
  final TextEditingController descriptionController = TextEditingController();

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加临时养护任务'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 任务类型选择
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '养护类型',
                border: OutlineInputBorder(),
              ),
              value: selectedCareType,
              items: DefaultValues.getCares(context).entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(entry.value.icon, color: entry.value.color, size: 20),
                      const SizedBox(width: 8),
                      Text(entry.value.translatedName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? value) {
                setState(() {
                  selectedCareType = value;
                });
              },
            ),
            const SizedBox(height: 16),
            // 日期选择
            ListTile(
              title: const Text('计划日期'),
              subtitle: Text(DateFormat.yMd().format(selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            // 描述输入
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: selectedCareType == null
              ? null
              : () async {
                  // 创建新的临时任务
                  final temporaryCare = TemporaryCare(
                    id: DateTime.now().millisecondsSinceEpoch,
                    name: selectedCareType!,
                    scheduledDate: selectedDate,
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  );

                  // 添加到植物的临时任务列表
                  widget.plant.temporaryCares.add(temporaryCare);
                  await garden.updatePlant(widget.plant);

                  Navigator.of(context).pop();

                  // 刷新界面
                  widget.onTaskAdded();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('临时任务已添加')),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('添加'),
        ),
      ],
    );
  }
}
