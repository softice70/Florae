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
import 'package:shared_preferences/shared_preferences.dart';

import '../background_task.dart';
import '../data/care.dart';
import '../data/default.dart';
import '../data/temporary_care.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'care_plant.dart';
import 'care_calendar_simple.dart';
import 'manage_plant.dart';
import 'settings.dart';
import 'care_history_screen.dart';
import 'journal_screen.dart';
import '../components/weather_card.dart';
import '../data/weather_model.dart';
import '../services/weather_service.dart';

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
  DateTime _dateFilter =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  Page _currentPage = Page.today;

  // 天气相关状态
  Weather? _currentWeather;
  WeatherForecast? _weatherForecast;
  final WeatherService _weatherService = WeatherService();
  String _currentCity = '';
  bool _isLoadingWeather = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting();
    _loadPlants();
    _configureBackgroundFetch();
    notify.initNotifications(
        'Care reminder', 'Receive plants care notifications');
    // 加载城市后再获取天气数据，解决时序问题
    _loadSavedCity().then((_) {
      _fetchWeatherData();
    });
  }

  // 配置后台任务
  void _configureBackgroundFetch() {
    // 后台任务的配置已在main.dart中完成
    // 这里可以添加额外的后台任务配置逻辑
  }

  // 加载保存的城市
  Future<void> _loadSavedCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString('currentCity');
      print('DEBUG: Loading saved city from SharedPreferences: $savedCity');
      if (savedCity != null && savedCity.isNotEmpty) {
        setState(() {
          _currentCity = savedCity;
        });
        print('DEBUG: City loaded successfully: $_currentCity');
      } else {
        // 如果没有保存的城市，设置一个默认城市（北京）
        const defaultCity = '北京';
        print('DEBUG: No saved city found, using default: $defaultCity');
        setState(() {
          _currentCity = defaultCity;
        });
        // 保存默认城市
        await _saveCity(defaultCity);
      }
    } catch (e) {
      print('DEBUG: Error loading saved city: $e');
    }
  }

  // 保存城市
  _saveCity(String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentCity', city);
      // 验证保存是否成功
      final savedValue = prefs.getString('currentCity');
      if (savedValue == city) {
        print('DEBUG: City saved successfully to SharedPreferences: $city');
      } else {
        print(
            'DEBUG: WARNING - City save verification failed. Expected: $city, Got: $savedValue');
      }
    } catch (e) {
      print('DEBUG: Error saving city to SharedPreferences: $e');
    }
  }

  // 获取天气数据
  Future<void> _fetchWeatherData() async {
    if (_isLoadingWeather) {
      print('DEBUG: Weather data fetch already in progress, skipping...');
      return;
    }

    // 确保只有当城市不为空时才获取天气数据
    if (_currentCity.isEmpty) {
      print('DEBUG: Current city is empty, cannot fetch weather data');
      setState(() {
        _isLoadingWeather = false;
      });
      return;
    }

    // SoJSON接口不需要API密钥配置，此检查已由WeatherService.isApiKeyConfigured()内部处理

    print('DEBUG: Starting weather data fetch for city: "$_currentCity"');
    setState(() {
      _isLoadingWeather = true;
    });

    try {
      print(
          'DEBUG: Before calling WeatherService.getWeatherData with city: "$_currentCity"');
      final (weather, forecast) =
          await _weatherService.getWeatherData(_currentCity);
      print(
          'DEBUG: After calling WeatherService.getWeatherData, received city: "${weather.cityName}"');

      print(
          'DEBUG: Weather data received: cityName=${weather.cityName}, temp=${weather.temperature}');

      setState(() {
        _currentWeather = weather;
        _weatherForecast = forecast;
        print(
            'DEBUG: Weather state updated inside setState. Current weather city: "${_currentWeather?.cityName}"');
      });
      print(
          'DEBUG: Weather state updated successfully. Now UI should display city: "${weather.cityName}"');
    } catch (e) {
      print('DEBUG: Failed to load weather data: $e');
      // 显示错误消息给用户
      _showErrorMessage(
        '无法获取天气数据',
        e.toString().contains('未找到城市')
            ? '"$_currentCity" 不是一个有效的城市名称，请输入正确的城市名。'
            : '获取天气数据失败: $e',
      );
    } finally {
      setState(() {
        _isLoadingWeather = false;
      });
    }
  }

  // SoJSON接口不需要API密钥，此方法已废弃但保留以确保兼容性

  // 显示错误消息对话框
  void _showErrorMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 修改城市
  _changeCity() async {
    print(
        'DEBUG: Opening city selection dialog with current city: $_currentCity');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => CitySelectDialog(currentCity: _currentCity),
    );

    print('DEBUG: City selection dialog returned: "$result"');
    if (result != null && result.isNotEmpty) {
      print('DEBUG: Dialog returned non-empty city: "$result"');
      if (result != _currentCity) {
        print('DEBUG: Changing city from "$_currentCity" to "$result"');
        setState(() {
          _currentCity = result;
          print('DEBUG: _currentCity state inside setState: "$_currentCity"');
        });
        print(
            'DEBUG: City state updated locally to "$_currentCity". Now saving to SharedPreferences...');
        await _saveCity(result);
        print('DEBUG: City saved. Now fetching weather data for new city...');
        // 添加await以明确等待天气数据获取完成
        await _fetchWeatherData();
      } else {
        print('DEBUG: Same city "$result" selected, no change needed');
      }
    } else if (result == null) {
      print('DEBUG: City change canceled by user');
    } else {
      print('DEBUG: Empty city input, no change needed');
    }
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
            icon: const Icon(Icons.book),
            iconSize: 25,
            color: Theme.of(context).colorScheme.primary,
            tooltip: "养护随笔",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const JournalScreen(),
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
                // 重新加载城市和天气数据，确保从设置页面返回后城市名称正确显示
                _loadSavedCity().then((_) {
                  _fetchWeatherData();
                });
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
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 天气卡片
                  _buildWeatherCard(),
                  // 植物卡片网格
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // 使用LayoutBuilder获取可用宽度，确保GridList有明确的尺寸约束
                      return SizedBox(
                        width: constraints.maxWidth,
                        // 基于屏幕高度减去其他组件高度设置合理的高度
                        height: 480,
                        child: ResponsiveGridList(
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
                          children: _buildPlantCards(context), // Changed code
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 80), // 底部空间，确保内容不被FAB遮挡
                ],
              ),
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

  // 构建天气卡片
  Widget _buildWeatherCard() {
    if (_isLoadingWeather) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentWeather != null && _weatherForecast != null) {
      return Column(
        children: [
          WeatherCard(
            currentWeather: _currentWeather!,
            forecast: _weatherForecast!,
            onCityEditPress: _changeCity,
            onUpdateWeather: _fetchWeatherData,
          ),
        ],
      );
    }

    // 显示加载失败或初始状态的占位符
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentCity,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _changeCity,
                  tooltip: '修改城市',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _loadPlants({DateTime? dateCheck}) async {
    List<Plant> plants = [];
    Map<String, List<String>> cares = {};

    List<Plant> allPlants = await garden.getAllPlants();
    DateTime checkDate = dateCheck ?? DateTime.now();
    DateTime currentDate =
        DateTime(checkDate.year, checkDate.month, checkDate.day);

    if (_currentPage == Page.today) {
      for (Plant plant in allPlants) {
        cares[plant.name] = [];
        bool hasTodayTask = false;
        // 使用Map来存储每种养护类型的最早时间
        Map<String, DateTime> careTypeEarliestTimes = {};

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

          // 确定任务日期
          DateTime taskDate;
          if (daysSinceLastCare > care.cycles) {
            // 已经逾期，应该今天执行
            taskDate = currentDate;
            hasTodayTask = true;
          } else {
            // 计算正常下次执行日期
            DateTime nextCareDate =
                lastCareDate.add(Duration(days: care.cycles));
            taskDate = DateTime(
                nextCareDate.year, nextCareDate.month, nextCareDate.day);

            // 检查是否是今天
            if (taskDate == currentDate) {
              hasTodayTask = true;
            } else {
              // 不是今天的任务，跳过
              continue;
            }
          }

          // 记录这个养护类型的最早时间
          if (!careTypeEarliestTimes.containsKey(care.name) ||
              taskDate.isBefore(careTypeEarliestTimes[care.name]!)) {
            careTypeEarliestTimes[care.name] = taskDate;
          }
        }

        // 检查临时养护任务
        for (TemporaryCare tempCare in plant.temporaryCares) {
          // 检查临时任务是否是今天或已逾期
          if (tempCare.isToday(currentDate) ||
              tempCare.isOverdue(currentDate)) {
            hasTodayTask = true;

            // 如果临时任务已过期，则将待执行日期设为今日
            DateTime tempTaskDate = tempCare.isOverdue(currentDate)
                ? DateTime(currentDate.year, currentDate.month, currentDate.day)
                : tempCare.scheduledDate;

            // 记录这个养护类型的最早时间
            if (!careTypeEarliestTimes.containsKey(tempCare.name) ||
                tempTaskDate.isBefore(careTypeEarliestTimes[tempCare.name]!)) {
              careTypeEarliestTimes[tempCare.name] = tempTaskDate;
            }
          }
        }

        // 将合并后的任务类型添加到列表中
        cares[plant.name]!.addAll(careTypeEarliestTimes.keys);

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
        final today = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day);
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
          DateTime currentDate = DateTime(
              DateTime.now().year, DateTime.now().month, DateTime.now().day);
          int daysSinceLastCare = currentDate.difference(lastCareDate).inDays;

          if (daysSinceLastCare > careInfo.cycles) {
            isOverdue = true;
          }
          break;
        }
      }

      list.add(
        Icon(DefaultValues.getCare(context, care)!.icon,
            color: isOverdue
                ? Colors.red
                : DefaultValues.getCare(context, care)!.color),
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
                  aspectRatio: 1.08,
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
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          plant.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            height: 1.0, // 进一步减少植物名称的行高
                            fontSize: 16, // 减小字体大小
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(
                            height: 20.0,
                            child: FittedBox(
                              alignment: Alignment.topLeft,
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
