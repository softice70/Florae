// 天气数据模型类 - 包含天气信息、天气预报和单日天气详情的数据结构
import 'package:intl/intl.dart';

class Weather {
  final String cityName;
  final String description;
  final double temperature;
  final double tempMin;
  final double tempMax;
  final String icon;
  final DateTime date;

  Weather({
    required this.cityName,
    required this.description,
    required this.temperature,
    required this.tempMin,
    required this.tempMax,
    required this.icon,
    required this.date,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      cityName: json['name'] ?? '',
      description: json['weather'][0]['description'] ?? '',
      temperature: (json['main']['temp'] as num).toDouble() - 273.15, // 转换为摄氏度
      tempMin: (json['main']['temp_min'] as num).toDouble() - 273.15,
      tempMax: (json['main']['temp_max'] as num).toDouble() - 273.15,
      icon: json['weather'][0]['icon'] ?? '',
      date: DateTime.now(),
    );
  }
}

class ForecastDay {
  final DateTime date;
  final String description;
  final double tempMin;
  final double tempMax;
  final String icon;

  ForecastDay({
    required this.date,
    required this.description,
    required this.tempMin,
    required this.tempMax,
    required this.icon,
  });

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    return ForecastDay(
      date: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
      description: json['weather'][0]['description'] ?? '',
      tempMin: (json['main']['temp_min'] as num).toDouble() - 273.15,
      tempMax: (json['main']['temp_max'] as num).toDouble() - 273.15,
      icon: json['weather'][0]['icon'] ?? '',
    );
  }

  String get dayOfWeek {
    if (isToday) return '今天';
    if (isTomorrow) return '明天';
    return DateFormat('EEEE').format(date).substring(0, 3);
  }

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;
  }
}

class WeatherForecast {
  final String cityName;
  final List<ForecastDay> forecastDays;

  WeatherForecast({
    required this.cityName,
    required this.forecastDays,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final List<ForecastDay> forecastDays = [];
    
    // 过滤并分组为每天的数据
    final Map<String, List<Map<String, dynamic>>> dailyData = {};
    
    for (var item in json['list']) {
      final date = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      final dateKey = '${date.year}-${date.month}-${date.day}';
      
      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = [];
      }
      dailyData[dateKey]!.add(item);
    }

    // 处理每天的数据，取温度范围和主要天气描述
    dailyData.forEach((dateKey, hourlyData) {
      if (hourlyData.isEmpty) return;
      
      // 找出当天的最低和最高温度
      double minTemp = double.infinity;
      double maxTemp = double.negativeInfinity;
      String mainDescription = hourlyData[0]['weather'][0]['description'];
      String mainIcon = hourlyData[0]['weather'][0]['icon'];
      
      for (var hour in hourlyData) {
        final temp = (hour['main']['temp'] as num).toDouble() - 273.15;
        if (temp < minTemp) minTemp = temp;
        if (temp > maxTemp) maxTemp = temp;
        
        // 优先显示白天的天气
        final hourOfDay = DateTime.fromMillisecondsSinceEpoch(hour['dt'] * 1000).hour;
        if (hourOfDay >= 8 && hourOfDay <= 18) {
          mainDescription = hour['weather'][0]['description'];
          mainIcon = hour['weather'][0]['icon'];
        }
      }
      
      forecastDays.add(ForecastDay(
        date: DateTime.parse(dateKey),
        description: mainDescription,
        tempMin: minTemp,
        tempMax: maxTemp,
        icon: mainIcon,
      ));
    });

    // 按日期排序
    forecastDays.sort((a, b) => a.date.compareTo(b.date));

    return WeatherForecast(
      cityName: json['city']['name'] ?? '',
      forecastDays: forecastDays,
    );
  }
}