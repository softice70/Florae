// 天气缓存管理器 - 用于缓存天气数据，减少API调用
import '../data/weather_model.dart';
import 'dart:async';

// 缓存项类，包含数据和过期时间
class CacheItem<T> {
  final T data;
  final DateTime expirationTime;

  CacheItem(this.data, this.expirationTime);

  bool get isExpired => DateTime.now().isAfter(expirationTime);
}

class WeatherCacheManager {
  // 缓存存储
  final Map<String, CacheItem<Weather>> _currentWeatherCache = {};
  final Map<String, CacheItem<WeatherForecast>> _forecastCache = {};

  // 缓存过期时间设置
  static const Duration currentWeatherCacheDuration = Duration(minutes: 5);
  static const Duration forecastCacheDuration = Duration(hours: 2);

  // 获取缓存的当前天气
  Weather? getCurrentWeather(String cityName) {
    final cacheKey = _getCacheKey(cityName, 'current');
    final cacheItem = _currentWeatherCache[cacheKey];

    if (cacheItem == null || cacheItem.isExpired) {
      // 缓存不存在或已过期
      if (cacheItem?.isExpired ?? false) {
        _currentWeatherCache.remove(cacheKey);
      }
      return null;
    }

    return cacheItem.data;
  }

  // 缓存当前天气
  void setCurrentWeather(String cityName, Weather weather) {
    final cacheKey = _getCacheKey(cityName, 'current');
    final expirationTime = DateTime.now().add(currentWeatherCacheDuration);
    _currentWeatherCache[cacheKey] = CacheItem(weather, expirationTime);
  }

  // 获取缓存的天气预报
  WeatherForecast? getWeatherForecast(String cityName) {
    final cacheKey = _getCacheKey(cityName, 'forecast');
    final cacheItem = _forecastCache[cacheKey];

    if (cacheItem == null || cacheItem.isExpired) {
      // 缓存不存在或已过期
      if (cacheItem?.isExpired ?? false) {
        _forecastCache.remove(cacheKey);
      }
      return null;
    }

    return cacheItem.data;
  }

  // 缓存天气预报
  void setWeatherForecast(String cityName, WeatherForecast forecast) {
    final cacheKey = _getCacheKey(cityName, 'forecast');
    final expirationTime = DateTime.now().add(forecastCacheDuration);
    _forecastCache[cacheKey] = CacheItem(forecast, expirationTime);
  }

  // 清除特定城市的所有缓存
  void clearCacheForCity(String cityName) {
    final currentKey = _getCacheKey(cityName, 'current');
    final forecastKey = _getCacheKey(cityName, 'forecast');
    _currentWeatherCache.remove(currentKey);
    _forecastCache.remove(forecastKey);
  }

  // 清除所有缓存
  void clearAllCache() {
    _currentWeatherCache.clear();
    _forecastCache.clear();
  }

  // 生成缓存键
  String _getCacheKey(String cityName, String type) {
    return '$cityName:$type';
  }
}

// 单例实例
final WeatherCacheManager weatherCacheManager = WeatherCacheManager();