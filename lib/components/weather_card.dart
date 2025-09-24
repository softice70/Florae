// 天气卡片组件 - 展示当前天气信息和未来5天天气预报的UI组件，包含城市选择功能
import 'package:flutter/material.dart';
import '../data/weather_model.dart';
import '../utils/weather_utils.dart';
import '../services/weather_service.dart';

class WeatherCard extends StatefulWidget {
  final Weather currentWeather;
  final WeatherForecast forecast;
  final VoidCallback onCityEditPress;
  final Future<void> Function() onUpdateWeather;

  const WeatherCard({
    super.key,
    required this.currentWeather,
    required this.forecast,
    required this.onCityEditPress,
    required this.onUpdateWeather,
  });

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final backgroundColor =
        WeatherUtils.getWeatherBackgroundColor(widget.currentWeather.icon);
    final bool isNight = widget.currentWeather.icon.contains('n');
    final textColor = isNight ? Colors.white : Colors.black87;
    final secondTextColor = isNight
        ? const Color.fromARGB(227, 207, 207, 207)
        : const Color.fromARGB(230, 95, 95, 95);
    final accentColor = isNight
        ? const Color.fromARGB(255, 255, 182, 193) // 浅粉红（夜晚）
        : const Color.fromARGB(255, 255, 187, 0); // 橙红色（白天）;
    final secondaryColor = isNight
        ? const Color.fromARGB(255, 173, 216, 230) // 浅蓝色（夜晚）
        : const Color.fromARGB(255, 70, 130, 180); // 钢蓝色（白天）;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 5,
      margin: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundColor.withOpacity(0.8),
              backgroundColor.withOpacity(0.4),
            ],
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：城市名称（第一列）+ 天气图标（第二列）+ 天气文字+最高/最低温度（第三列）+ 当前温度（第四列最右侧）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 24),
                    // 第一列：城市名称
                    InkWell(
                      onTap: widget.onCityEditPress,
                      child: Text(
                        widget.currentWeather.cityName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: secondaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // 第二列：天气图标
                    Icon(
                      WeatherUtils.getWeatherIcon(widget.currentWeather.icon),
                      size: 32,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    // 第三列：天气文字+最高/最低温度
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          WeatherUtils.getWeatherDescription(
                              widget.currentWeather.description),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${WeatherUtils.formatTemperature(widget.currentWeather.tempMax)}/${WeatherUtils.formatTemperature(widget.currentWeather.tempMin)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                // 第四列：当前温度（最右侧）- 可点击更新
                GestureDetector(
                  onTap: () async {
                    if (!_isUpdating) {
                      setState(() {
                        _isUpdating = true;
                      });

                      try {
                        await widget.onUpdateWeather();
                        // 显示Toast提示
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('天气信息已更新'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('更新天气失败: $e'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setState(() {
                          _isUpdating = false;
                        });
                      }
                    }
                  },
                  child: Stack(
                    children: [
                      Text(
                        WeatherUtils.formatTemperature(
                            widget.currentWeather.temperature),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      if (_isUpdating)
                        const Positioned(
                          right: -10,
                          top: -10,
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            const SizedBox(height: 4),

            // 第三行：未来五天天气预报
            SizedBox(
              height: 60,
              child: Row(
                // 将5天的天气预报均匀分布在整行
                children: _getFilteredForecastDays(widget.forecast.forecastDays)
                    .map((day) {
                  return Expanded(
                    child: _buildForecastDayCard(context, day, secondTextColor,
                        accentColor, secondaryColor, theme),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 过滤掉今天的数据，并限制为5天
  List<ForecastDay> _getFilteredForecastDays(List<ForecastDay> allDays) {
    // 过滤出非今天的数据，然后取前5个
    final tomorrowAndBeyond = allDays.where((day) => !day.isToday).toList();
    return tomorrowAndBeyond.take(5).toList();
  }

  // 获取中文星期
  String _getChineseWeekday(DateTime date) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '今天';
    } else if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return '明天';
    } else {
      const chineseWeekdays = ['日', '一', '二', '三', '四', '五', '六'];
      return '周${chineseWeekdays[date.weekday - 1]}';
    }
  }

  Widget _buildForecastDayCard(
      BuildContext context,
      ForecastDay day,
      Color textColor,
      Color accentColor,
      Color secondaryColor,
      ThemeData theme) {
    // 为预报卡片添加更丰富的颜色变化
    final cardBackgroundColor = textColor == Colors.white
        ? Colors.black.withOpacity(0.3)
        : Colors.white.withOpacity(0.6);
    final isDayForecast = day.icon.contains('d');
    final forecastIconColor = isDayForecast ? accentColor : secondaryColor;

    return Container(
      width: 55,
      margin: const EdgeInsets.only(left: 4, right: 4),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDayForecast
              ? secondaryColor.withOpacity(0.5)
              : accentColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 星期格式（中文）
          Text(
            _getChineseWeekday(day.date),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          // 天气图标
          Icon(
            WeatherUtils.getWeatherIcon(day.icon),
            size: 18,
            color: forecastIconColor,
          ),
          // 最高/最低温度 - 分开设置颜色，使最高温更醒目
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${WeatherUtils.formatTemperature(day.tempMax)}/',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: secondaryColor,
                  ),
                ),
                TextSpan(
                  text: WeatherUtils.formatTemperature(day.tempMin),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 城市选择弹窗
class CitySelectDialog extends StatefulWidget {
  final String currentCity;

  const CitySelectDialog({super.key, required this.currentCity});

  @override
  State<CitySelectDialog> createState() => _CitySelectDialogState();
}

class _CitySelectDialogState extends State<CitySelectDialog> {
  late TextEditingController _cityController;
  bool _isCityValid = true;
  String? _errorMessage;
  final WeatherService _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(text: widget.currentCity);
    // 初始化时验证当前城市
    _validateCity(widget.currentCity);
    // 添加监听器以验证城市名称
    _cityController.addListener(() {
      _validateCity(_cityController.text.trim());
    });
  }

  // 验证城市有效性
  void _validateCity(String cityName) {
    setState(() {
      if (cityName.isEmpty) {
        _isCityValid = false;
        _errorMessage = null;
      } else if (!_weatherService.getSupportedCities().contains(cityName)) {
        _isCityValid = false;
        _errorMessage = '请检查城市名称是否正确';
      } else {
        _isCityValid = true;
        _errorMessage = null;
      }
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改城市'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: '城市名称',
              hintText: '请输入城市名称',
              errorText: _errorMessage != null ? '城市不支持' : null,
              errorBorder: _errorMessage != null
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red))
                  : null,
            ),
            onSubmitted: (value) {
              if (_isCityValid) {
                print(
                    'CitySelectDialog: Submitting city: ${_cityController.text.trim()}');
                Navigator.of(context).pop(_cityController.text.trim());
              }
            },
          ),
          if (_errorMessage != null && _cityController.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            print('CitySelectDialog: Cancel pressed');
            Navigator.of(context).pop(null);
          },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isCityValid
              ? () {
                  print(
                      'CitySelectDialog: OK pressed with city: ${_cityController.text.trim()}');
                  Navigator.of(context).pop(_cityController.text.trim());
                }
              : null, // 当城市名称为空时禁用按钮
          child: const Text('确定'),
        ),
      ],
    );
  }
}
