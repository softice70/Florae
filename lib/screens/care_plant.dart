import 'dart:io';

import 'package:florae/data/plant.dart';
import 'package:florae/screens/picture_viewer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/care.dart';
import '../data/care_history.dart';
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
  Map<Care, bool?> careCheck = {};
  Map<Care, TextEditingController> careDetailsControllers = {};
  DateTime selectedCareDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

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

    for (Care care in plant.cares) {
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
          title:
              Text(DefaultValues.getCare(context, care.name)!.translatedName),
          subtitle: Text(buildCareMessage(daysToCare)),
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
              maxLines: 3,
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
                    final selectedDateEnd = selectedDateStart.add(const Duration(days: 1));

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
                          plant.careHistory.removeWhere((history) =>
                              history.careName == key.name &&
                              history.careDate.isAfter(selectedDateStart) &&
                              history.careDate.isBefore(selectedDateEnd));

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

  Widget _buildCareHistory(Plant plant) {
    if (plant.careHistory.isEmpty) {
      return SizedBox(
          width: double.infinity,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    '无养护记录',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ));
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      '养护记录',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (latestDate != null)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          _editLatestDayCareHistory(context, plant, latestDate);
                        },
                        tooltip: '修改最近一天的养护记录',
                      ),
                  ],
                ),
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
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final plant = ModalRoute.of(context)!.settings.arguments as Plant;

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
              await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => ManagePlantScreen(
                        title: "Manage plant", update: true, plant: plant),
                  ));
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
                child: Column(children: <Widget>[
                  ListTile(
                      leading: const Icon(Icons.topic),
                      title:
                          Text(AppLocalizations.of(context)!.labelDescription),
                      subtitle: Text(plant.description)),
                  ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(AppLocalizations.of(context)!.labelLocation),
                      subtitle: Text(plant.location ?? "")),
                  ListTile(
                      leading: const Icon(Icons.cake),
                      title:
                          Text(AppLocalizations.of(context)!.labelDayPlanted),
                      subtitle: Text(DateFormat.yMMMMd(
                              Localizations.localeOf(context).languageCode)
                          .format(plant.createdAt))),
                ]),
              ),
              Card(
                  semanticContainer: true,
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(children: _buildCares(context, plant))),
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
                          maxLines: 4,
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
}
