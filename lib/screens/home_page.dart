import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:florae/data/plant.dart';
import 'package:florae/data/settings/settings_manager.dart';
import 'package:florae/notifications.dart' as notify;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

import '../background_task.dart';
import '../data/care.dart';
import '../data/default.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'care_plant.dart';
import 'care_calendar_simple.dart';
import 'manage_plant.dart';
import 'settings.dart';
import 'care_history_screen.dart';

enum Page { today, garden }

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Plant> _plants = [];
  Map<String, List<String>> _cares = {};
  bool _dateFilterEnabled = false;
  DateTime _dateFilter = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  Page _currentPage = Page.today;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPlants();
    initializeDateFormatting();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    // Configure settings.
    await SettingsManager.initializeSettings();

    // Initialize settings.
    notify.initNotifications(AppLocalizations.of(context)!.careNotificationName,
        AppLocalizations.of(context)!.careNotificationDescription);

    // Configure BackgroundFetch.
    try {
      var status = await BackgroundFetch.configure(
          BackgroundFetchConfig(
              minimumFetchInterval: 60,
              stopOnTerminate: false,
              startOnBoot: true,
              enableHeadless: true,
              requiredNetworkType: NetworkType.NONE),
          _onBackgroundFetch,
          _onBackgroundFetchTimeout);
      print('[BackgroundFetch] configure success: $status');
    } on Exception catch (e) {
      print("[BackgroundFetch] configure ERROR: $e");
    }

    if (!mounted) return;
  }

  void _onBackgroundFetch(String taskId) async {
    print("[BackgroundFetch] Event received: $taskId");

    if (taskId == "flutter_background_fetch") {
      await checkCaresAndNotify();
    }
    BackgroundFetch.finish(taskId);
  }

  void _onBackgroundFetchTimeout(String taskId) {
    print("[BackgroundFetch] TIMEOUT: $taskId");
    BackgroundFetch.finish(taskId);
  }

  Future<void> _showWaterAllPlantsDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.careAll),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(AppLocalizations.of(context)!.careAllBody),
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
                await _careAllPlants();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget noPlants() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              _currentPage == Page.today
                  ? (Theme.of(context).brightness == Brightness.dark)
                      ? "assets/undraw_different_love_a-3-rg.svg"
                      : "assets/undraw_fall_thyk.svg"
                  : (Theme.of(context).brightness == Brightness.dark)
                      ? "assets/undraw_flowers_vx06.svg"
                      : "assets/undraw_blooming_re_2kc4.svg",
              semanticsLabel: 'Fall',
              alignment: Alignment.center,
              height: 250,
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              //apply padding to all four sides
              child: Text(
                _currentPage == Page.today
                    ? AppLocalizations.of(context)!.mainNoCares
                    : AppLocalizations.of(context)!.mainNoPlants,
                style: TextStyle(
                  fontFamily: 'NotoSans',
                  fontWeight: FontWeight.w500,
                  fontSize: 0.065 * MediaQuery.of(context).size.width,
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String titleSelector() {
    if (_dateFilterEnabled) {
      return DateFormat.EEEE(Localizations.localeOf(context).languageCode)
              .format(_dateFilter) +
          " " +
          DateFormat('d').format(_dateFilter);
    } else if (_currentPage == Page.garden) {
      return AppLocalizations.of(context)!.buttonGarden;
    } else {
      return AppLocalizations.of(context)!.buttonToday;
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.

    String title = titleSelector();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 70,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: FittedBox(fit: BoxFit.fitWidth, child: Text(title)),
        titleTextStyle: Theme.of(context).textTheme.displayLarge,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.event_note),
            iconSize: 25,
            color: Theme.of(context).colorScheme.primary,
            tooltip: "养护计划",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const CareCalendarScreen(
                    title: "养护计划",
                  ),
                ),
              );
              setState(() {
                _loadPlants();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            iconSize: 25,
            color: Theme.of(context).colorScheme.primary,
            tooltip: AppLocalizations.of(context)!.careHistory,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const CareHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            iconSize: 25,
            color: Theme.of(context).colorScheme.primary,
            tooltip: AppLocalizations.of(context)!.tooltipSettings,
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        const SettingsScreen(title: "Settings Screen"),
                  ));
              setState(() {
                _loadPlants();
              });
            },
          ),
        ],
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0.0,
      ),
      body: _plants.isEmpty
          ? noPlants()
          : ResponsiveGridList(
              // Horizontal space between grid items
              horizontalGridSpacing: 10,
              // Vertical space between grid items
              verticalGridSpacing: 10,
              // Horizontal space around the grid
              horizontalGridMargin: 10,
              // Vertical space around the grid
              verticalGridMargin: 10,
              // The minimum item width (can be smaller, if the layout constraints are smaller)
              minItemWidth: 150,
              // The minimum items to show in a single row. Takes precedence over minItemWidth
              minItemsPerRow: 2,
              // The maximum items to show in a single row. Can be useful on large screens
              maxItemsPerRow: 6,
              children: _buildPlantCards(context) // Changed code
              ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            _dateFilterEnabled = false;
            _currentPage = Page.values[index];
            _loadPlants();
          });
        },
        selectedIndex: _currentPage.index,
        destinations: <Widget>[
          NavigationDestination(
            selectedIcon:
                Icon(Icons.eco, color: Theme.of(context).colorScheme.surface),
            icon: const Icon(Icons.eco_outlined),
            label: AppLocalizations.of(context)!.buttonToday,
          ),
          NavigationDestination(
            selectedIcon:
                Icon(Icons.grass, color: Theme.of(context).colorScheme.surface),
            icon: const Icon(Icons.grass_outlined),
            label: AppLocalizations.of(context)!.buttonGarden,
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const ManagePlantScreen(
                    title: "Manage plant", update: false),
              ));
          setState(() {
            _currentPage = Page.garden;
            _loadPlants();
          });
        },
        tooltip: AppLocalizations.of(context)!.tooltipNewPlant,
        child: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _loadPlants({DateTime? dateCheck}) async {
    List<Plant> plants = [];
    Map<String, List<String>> cares = {};

    List<Plant> allPlants = await garden.getAllPlants();
    DateTime checkDate = dateCheck ?? DateTime.now();
    DateTime currentDate = DateTime(checkDate.year, checkDate.month, checkDate.day);

    if (_currentPage == Page.today) {
      for (Plant plant in allPlants) {
        cares[plant.name] = [];
        bool hasTodayTask = false;
        
        // 检查每种养护类型
        for (Care care in plant.cares) {
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
          }
          
          // 智能计算下次待执行日期
          int daysSinceLastCare = currentDate.difference(lastCareDate).inDays;
          
          if (daysSinceLastCare > care.cycles) {
            // 已经逾期，应该今天执行
            hasTodayTask = true;
            cares[plant.name]!.add(care.name);
          } else {
            // 计算正常下次执行日期
            DateTime nextCareDate = lastCareDate.add(Duration(days: care.cycles));
            DateTime nextDate = DateTime(nextCareDate.year, nextCareDate.month, nextCareDate.day);
            DateTime checkDay = DateTime(currentDate.year, currentDate.month, currentDate.day);
            
            if (nextDate == checkDay) {
              hasTodayTask = true;
              cares[plant.name]!.add(care.name);
            }
          }
        }
        
        // 如果有需要养护的任务，添加植物
        if (cares[plant.name]!.isNotEmpty) {
          plants.add(plant);
        }
      }
    } else {
      plants = allPlants;
      // 按字母排序
      plants.sort((a, b) => a.name.compareTo(b.name));
      for (Plant plant in allPlants) {
        cares[plant.name] = [];
        for (Care care in plant.cares) {
          cares[plant.name]!.add(care.name);
        }
      }
    }

    setState(() {
      _cares = cares;
      _plants = plants;
    });
  }

  _careAllPlants() async {
    List<Plant> allPlants = await garden.getAllPlants();

    for (Plant p in allPlants) {
      for (Care c in p.cares) {
        final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        if (c.isRequired(today, false)) {
          c.effected = today;
        }
      }
      await garden.updatePlant(p);
    }

    setState(() {
      _dateFilterEnabled = false;
      _loadPlants();
    });
  }

  _openPlant(Plant plant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarePlantScreen(title: plant.name),
        // Pass the arguments as part of the RouteSettings. The
        // DetailScreen reads the arguments from these settings.
        settings: RouteSettings(
          arguments: plant,
        ),
      ),
    );
    setState(() {
      _loadPlants();
    });
  }

  List<Icon> _buildCares(BuildContext context, Plant plant) {
    List<Icon> list = [];

    for (var care in _cares[plant.name]!) {
      // 检查该养护任务是否逾期
      bool isOverdue = false;
      
      for (Care careInfo in plant.cares) {
        if (careInfo.name == care) {
          if (careInfo.cycles <= 0 || careInfo.effected == null) continue;
          
          // 计算下次应该执行的日期
          DateTime lastCareDate = DateTime(
            careInfo.effected!.year,
            careInfo.effected!.month,
            careInfo.effected!.day,
          );
          
          // 找到这个养护类型的最后一次执行日期
          DateTime? lastSpecificCareDate;
          for (var history in plant.careHistory.reversed) {
            if (history.careName == care) {
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
          }
          
          // 判断是否逾期
          DateTime currentDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          int daysSinceLastCare = currentDate.difference(lastCareDate).inDays;
          
          if (daysSinceLastCare > careInfo.cycles) {
            isOverdue = true;
          }
          break;
        }
      }

      list.add(
        Icon(DefaultValues.getCare(context, care)!.icon,
            color: isOverdue ? Colors.red : DefaultValues.getCare(context, care)!.color),
      );
    }

    return list;
  }

  List<GestureDetector> _buildPlantCards(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _plants.map((plant) {
      return GestureDetector(
          onLongPressCancel: () async {
            await _openPlant(plant);
          },
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            elevation: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 18 / 12,
                  child: plant.picture!.contains("florae_avatar")
                      ? Image.asset(
                          plant.picture!,
                          fit: BoxFit.fitHeight,
                        )
                      : Image.file(
                          File(plant.picture!),
                          fit: BoxFit.fitWidth,
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        FittedBox(
                          fit: BoxFit.fitWidth,
                          child: Text(
                            plant.name,
                            style: theme.textTheme.titleLarge,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          plant.description,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8.0),
                        SizedBox(
                            height: 20.0,
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              child: plant.cares.isNotEmpty
                                  ? Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: _buildCares(context, plant))
                                  : null,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ));
    }).toList();
  }
}
