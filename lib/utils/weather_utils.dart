// 天气工具类 - 提供天气图标映射、描述转换、背景颜色和温度格式化等UI展示相关的工具方法
import 'package:flutter/material.dart';

class WeatherUtils {
  // 根据天气图标代码获取对应的Material图标
  static IconData getWeatherIcon(String iconCode) {
    switch (iconCode) {
      case '01d': // 晴天（白天）
        return Icons.sunny;
      case '01n': // 晴天（夜晚）
        return Icons.nightlight_round;
      case '02d': // 多云（白天）
      case '02n': // 多云（夜晚）
        return Icons.cloud;
      case '03d': // 阴云
      case '03n':
        return Icons.cloud_outlined;
      case '04d': // 阴天
      case '04n':
        return Icons.cloud_queue;
      case '09d': // 小雨
      case '09n':
        return Icons.shower;
      case '10d': // 雨（白天）
      case '10n': // 雨（夜晚）
        return Icons.umbrella;
      case '11d': // 雷阵雨（白天）
      case '11n': // 雷阵雨（夜晚）
        return Icons.bolt;
      case '13d': // 雪（白天）
      case '13n': // 雪（夜晚）
        return Icons.snowing;
      case '50d': // 雾（白天）
      case '50n': // 雾（夜晚）
        return Icons.foggy;
      default:
        return Icons.cloud;
    }
  }

  // 根据天气描述获取对应的中文天气
  static String getWeatherDescription(String description) {
    final Map<String, String> descriptionMap = {
      'clear sky': '晴',
      'few clouds': '少云',
      'scattered clouds': '多云',
      'broken clouds': '阴',
      'overcast clouds': '阴天',
      'light rain': '小雨',
      'moderate rain': '中雨',
      'heavy intensity rain': '大雨',
      'very heavy rain': '暴雨',
      'extreme rain': '大暴雨',
      'freezing rain': '冻雨',
      'light intensity shower rain': '阵雨',
      'shower rain': '阵雨',
      'heavy intensity shower rain': '强阵雨',
      'ragged shower rain': '不规则阵雨',
      'light snow': '小雪',
      'snow': '雪',
      'heavy snow': '大雪',
      'sleet': '雨夹雪',
      'shower sleet': '阵雨夹雪',
      'light rain and snow': '小雨夹雪',
      'rain and snow': '雨夹雪',
      'light shower snow': '阵雪',
      'shower snow': '阵雪',
      'heavy shower snow': '强阵雪',
      'mist': '薄雾',
      'smoke': '烟雾',
      'haze': '霾',
      'sand/dust whirls': '沙尘',
      'fog': '雾',
      'sand': '沙尘',
      'dust': '浮尘',
      'volcanic ash': '火山灰',
      'squalls': '飑线',
      'tornado': '龙卷风',
    };

    return descriptionMap[description.toLowerCase()] ?? description;
  }

  // 根据天气情况获取背景颜色
  static Color getWeatherBackgroundColor(String iconCode) {
    if (iconCode.contains('d')) { // 白天
      switch (iconCode) {
        case '01d':
          return const Color.fromARGB(255, 135, 206, 235); // 晴天-天蓝色
        case '02d':
        case '03d':
          return const Color.fromARGB(255, 176, 224, 230); // 多云-浅蓝
        case '04d':
          return const Color.fromARGB(255, 192, 192, 192); // 阴天-灰色
        case '09d':
        case '10d':
          return const Color.fromARGB(255, 173, 216, 230); // 雨天-浅蓝色
        case '11d':
          return const Color.fromARGB(255, 169, 169, 169); // 雷阵雨-深灰色
        case '13d':
          return const Color.fromARGB(255, 240, 248, 255); // 雪天-浅蓝白
        case '50d':
          return const Color.fromARGB(255, 211, 211, 211); // 雾天-浅灰色
        default:
          return const Color.fromARGB(255, 135, 206, 235);
      }
    } else { // 夜晚
      switch (iconCode) {
        case '01n':
          return const Color.fromARGB(255, 25, 25, 112); // 晴天-深蓝
        case '02n':
        case '03n':
          return const Color.fromARGB(255, 47, 79, 79); // 多云-暗蓝
        case '04n':
          return const Color.fromARGB(255, 70, 130, 180); // 阴天-钢蓝
        case '09n':
        case '10n':
          return const Color.fromARGB(255, 30, 144, 255); // 雨天-中蓝
        case '11n':
          return const Color.fromARGB(255, 25, 25, 50); // 雷阵雨-近黑
        case '13n':
          return const Color.fromARGB(255, 100, 149, 237); // 雪天-中浅蓝
        case '50n':
          return const Color.fromARGB(255, 60, 60, 60); // 雾天-深灰色
        default:
          return const Color.fromARGB(255, 25, 25, 112);
      }
    }
  }

  // 格式化温度显示
  static String formatTemperature(double temp) {
    return '${temp.round()}°';
  }
}