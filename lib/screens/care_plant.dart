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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // 释放所有文本控制器
    careDetailsControllers.values.forEach((controller) {
      controller.dispose();
    });
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

  Future<void> _showDeletePlantDialog(Plant plant) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.deletePlantTitle),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(AppLocalizations.of(context)!.deletePlantBody),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context)!.no),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context)!.yes),
              onPressed: () async {
                await garden.deletePlant(plant);

                Navigator.popUntil(context, ModalRoute.withName('/'));
              },
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildCares(BuildContext context, Plant plant) {
    List<Widget> careWidgets = [];
    
    for (Care care in plant.cares) {
      int daysToCare = care.cycles - care.daysSinceLastCare(DateTime.now());

      if (careCheck[care] == null) {
        careCheck[care] = daysToCare <= 0;
      }
      
      // 为每个养护任务创建文本控制器
      if (careDetailsControllers[care] == null) {
        careDetailsControllers[care] = TextEditingController();
      }

      careWidgets.add(
        CheckboxListTile(
          title: Text(DefaultValues.getCare(context, care.name)!.translatedName),
          subtitle: Text(buildCareMessage(daysToCare)),
          value: careCheck[care],
          onChanged: (bool? value) {
            setState(() {
              careCheck[care] = value;
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
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: TextField(
              controller: careDetailsControllers[care],
              decoration: InputDecoration(
                hintText: '记录${DefaultValues.getCare(context, care.name)!.translatedName}详情（可选）',
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
    
    return careWidgets;
  }

  Widget _buildCareHistory(Plant plant) {
    if (plant.careHistory.isEmpty) {
      return SizedBox(width: double.infinity, child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '无养护记录',
            style: Theme.of(context).textTheme.bodyMedium,
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

    return SizedBox(width: double.infinity, child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '养护记录',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...groupedHistory.entries.map((entry) {
              final date = entry.key;
              final histories = entry.value;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: histories.map((history) {
                          final careInfo = DefaultValues.getCare(context, history.careName);
                          final icon = careInfo?.icon ?? Icons.help_outline;
                          final color = careInfo?.color ?? Colors.grey;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    history.details?.isNotEmpty == true 
                                      ? history.details!
                                      : '无详细信息',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: history.details?.isNotEmpty == true 
                                        ? null 
                                        : Colors.grey,
                                    ),
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
                        title: Text(
                            AppLocalizations.of(context)!.labelDescription),
                        subtitle: Text(plant.description)),
                    ListTile(
                        leading: const Icon(Icons.location_on),
                        title:
                            Text(AppLocalizations.of(context)!.labelLocation),
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              FloatingActionButton.extended(
                heroTag: "delete",
                onPressed: () async {
                  await _showDeletePlantDialog(plant);
                },
                label: Text(AppLocalizations.of(context)!.deleteButton),
                icon: const Icon(Icons.delete),
                backgroundColor: Colors.redAccent,
              ),
              FloatingActionButton.extended(
                heroTag: "care",
                onPressed: () async {
                  if (!careCheck.containsValue(true)) {
                    print("NO CARES");
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text(AppLocalizations.of(context)!.noCaresError)));
                  } else {
                    careCheck.forEach((key, value) {
                      if (value == true) {
                        var careIndex = plant.cares
                            .indexWhere((element) => element.name == key.name);
                        if (careIndex != -1) {
                          plant.cares[careIndex].effected = DateTime.now();
                          
                          // 获取养护详情
                          String? details = careDetailsControllers[key]?.text.trim();
                          if (details != null && details.isEmpty) {
                            details = null;
                          }
                          
                          // 添加到历史记录
                          plant.careHistory.add(CareHistory(
                            careDate: DateTime.now(),
                            careName: key.name,
                            details: details,
                          ));
                        }
                      }
                    });

                    await garden.updatePlant(plant);
                    Navigator.of(context).pop();
                  }
                },
                label: Text(AppLocalizations.of(context)!.careButton),
                icon: const Icon(Icons.check),
                backgroundColor: Theme.of(context).colorScheme.secondary,
              )
            ],
          ),
        ));
  }
}
