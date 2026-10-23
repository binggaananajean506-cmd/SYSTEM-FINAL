import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const Duration _philippineUtcOffset = Duration(hours: 8);

DateTime? _parsePhilippineProviderTime(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final hasExplicitOffset = RegExp(
    r'(?:z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(raw);
  if (hasExplicitOffset) return parsed.toUtc();

  // Open-Meteo returns local ISO-8601 clock values when timezone=Asia/Manila.
  // Convert those wall-clock components into an absolute UTC instant without
  // depending on the phone's configured timezone.
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  ).subtract(_philippineUtcOffset);
}

DateTime _asPhilippineClock(DateTime instant) =>
    instant.toUtc().add(_philippineUtcOffset);

bool _isFiniteInRange(num? value, double minimum, double maximum) {
  if (value == null) return false;
  final number = value.toDouble();
  return number.isFinite && number >= minimum && number <= maximum;
}

void _validateUnit(
  Map<String, dynamic> units,
  String field,
  Set<String> acceptedUnits,
) {
  final unit = units[field]?.toString();
  if (unit != null && !acceptedUnits.contains(unit)) {
    throw FormatException('Unexpected unit for $field: $unit');
  }
}

/// Animation category representing the meteorological effect.
enum WeatherAnimationType {
  sunny,
  cloudy,
  lightRain,
  heavyRain,
  thunderstorm,
  fog,
  none,
}

/// Hourly forecast prediction for Barili, Cebu.
class BariliHourlyForecast {
  final DateTime time;
  final double temperatureCelsius;
  final int precipitationProbability;
  final int weatherCode;
  final bool isDay;

  const BariliHourlyForecast({
    required this.time,
    required this.temperatureCelsius,
    required this.precipitationProbability,
    required this.weatherCode,
    required this.isDay,
  });

  factory BariliHourlyForecast.fromJson(Map<String, dynamic> json) {
    final time = DateTime.tryParse(json['time'] as String? ?? '');
    final temperature = (json['temperatureCelsius'] as num?)?.toDouble();
    final probability = (json['precipitationProbability'] as num?)?.toInt();
    final code = (json['weatherCode'] as num?)?.toInt();
    final isDay = json['isDay'];
    if (time == null ||
        temperature == null ||
        !temperature.isFinite ||
        probability == null ||
        probability < 0 ||
        probability > 100 ||
        code == null ||
        code < 0 ||
        code > 99 ||
        isDay is! bool) {
      throw const FormatException('Invalid cached hourly weather data.');
    }
    return BariliHourlyForecast(
      time: time,
      temperatureCelsius: temperature,
      precipitationProbability: probability,
      weatherCode: code,
      isDay: isDay,
    );
  }

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'temperatureCelsius': temperatureCelsius,
    'precipitationProbability': precipitationProbability,
    'weatherCode': weatherCode,
    'isDay': isDay,
  };

  String get condition =>
      BariliWeatherConditionHelper.condition(weatherCode, isDay);
  IconData get icon => BariliWeatherConditionHelper.icon(weatherCode, isDay);
}

/// Daily forecast for Barili, Cebu (up to 7 days).
class BariliDailyForecast {
  final DateTime date;
  final int weatherCode;
  final double tempMax;
  final double tempMin;
  final int precipitationProbability;
  final double precipitationSumMm;

  const BariliDailyForecast({
    required this.date,
    required this.weatherCode,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationProbability,
    required this.precipitationSumMm,
  });

  factory BariliDailyForecast.fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse(json['date'] as String? ?? '');
    final code = (json['weatherCode'] as num?)?.toInt();
    final max = (json['tempMax'] as num?)?.toDouble();
    final min = (json['tempMin'] as num?)?.toDouble();
    final probability = (json['precipitationProbability'] as num?)?.toInt();
    final sum = (json['precipitationSumMm'] as num?)?.toDouble();
    if (date == null ||
        code == null ||
        max == null ||
        min == null ||
        probability == null ||
        sum == null ||
        !max.isFinite ||
        !min.isFinite ||
        !sum.isFinite ||
        max < min ||
        probability < 0 ||
        probability > 100 ||
        code < 0 ||
        code > 99 ||
        sum < 0) {
      throw const FormatException('Invalid cached daily weather data.');
    }
    return BariliDailyForecast(
      date: date,
      weatherCode: code,
      tempMax: max,
      tempMin: min,
      precipitationProbability: probability,
      precipitationSumMm: sum,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'weatherCode': weatherCode,
    'tempMax': tempMax,
    'tempMin': tempMin,
    'precipitationProbability': precipitationProbability,
    'precipitationSumMm': precipitationSumMm,
  };

  String get condition =>
      BariliWeatherConditionHelper.condition(weatherCode, true);
  IconData get icon => BariliWeatherConditionHelper.icon(weatherCode, true);
}

/// Centralized WMO weather code mapping and styling helper.
class BariliWeatherConditionHelper {
  const BariliWeatherConditionHelper._();

  static String condition(int code, bool isDay) {
    switch (code) {
      case 0:
        return isDay ? 'Sunny' : 'Clear';
      case 1:
        return isDay ? 'Mostly Sunny' : 'Mostly Clear';
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Overcast';
      case 45:
        return 'Foggy';
      case 48:
        return 'Rime Fog';
      case 51:
        return 'Light Drizzle';
      case 53:
        return 'Drizzle';
      case 55:
        return 'Heavy Drizzle';
      case 56:
        return 'Light Freezing Drizzle';
      case 57:
        return 'Heavy Freezing Drizzle';
      case 61:
        return 'Light Rain';
      case 63:
        return 'Rain';
      case 65:
        return 'Heavy Rain';
      case 66:
        return 'Light Freezing Rain';
      case 67:
        return 'Heavy Freezing Rain';
      case 71:
        return 'Light Snow';
      case 73:
        return 'Snow';
      case 75:
        return 'Heavy Snow';
      case 77:
        return 'Snow Grains';
      case 85:
        return 'Light Snow Showers';
      case 86:
        return 'Heavy Snow Showers';
      case 80:
        return 'Light Rain Showers';
      case 81:
        return 'Rain Showers';
      case 82:
        return 'Heavy Rain Showers';
      case 95:
        return 'Thunderstorm';
      case 96:
        return 'Thunderstorm with Light Hail';
      case 99:
        return 'Thunderstorm with Heavy Hail';
      default:
        return 'Unknown Conditions';
    }
  }

  static IconData icon(int code, bool isDay) {
    if (code == 0 || code == 1) {
      return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    }
    if (code == 2) {
      return isDay ? Icons.wb_cloudy_rounded : Icons.cloud_rounded;
    }
    if (code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 95) return Icons.thunderstorm_rounded;
    if (code >= 51 && code <= 57) {
      return Icons.grain_rounded;
    }
    if (code >= 61 && code <= 67) {
      return code == 65 ? Icons.umbrella_rounded : Icons.water_drop_rounded;
    }
    if (code >= 80 && code <= 82) {
      return code == 82 ? Icons.umbrella_rounded : Icons.water_drop_rounded;
    }
    if (code >= 71 && code <= 86) {
      return Icons.ac_unit_rounded;
    }
    return Icons.wb_cloudy_rounded;
  }

  static WeatherAnimationType animationType(int code) {
    if (code == 0 || code == 1) return WeatherAnimationType.sunny;
    if (code == 2 || code == 3) return WeatherAnimationType.cloudy;
    if (code == 45 || code == 48) return WeatherAnimationType.fog;
    if (code == 51 || code == 53 || code == 55 || code == 61 || code == 80) {
      return WeatherAnimationType.lightRain;
    }
    if (code == 63 ||
        code == 65 ||
        code == 81 ||
        code == 82 ||
        code == 56 ||
        code == 57 ||
        code == 66 ||
        code == 67) {
      return WeatherAnimationType.heavyRain;
    }
    if (code >= 95) return WeatherAnimationType.thunderstorm;
    return WeatherAnimationType.cloudy;
  }

  static String advisoryDescription(int code) {
    if (code >= 95) {
      return 'Thunderstorms expected in the area. Stay indoors if lightning occurs.';
    }
    if (code == 65 || code == 82) {
      return 'Heavy rain showers present. Take an umbrella and watch for slippery roads.';
    }
    if (code == 61 || code == 63 || code == 80 || code == 51 || code == 53) {
      return 'Passing light rain showers. Outdoor activities can continue with caution.';
    }
    if (code == 45 || code == 48) {
      return 'Reduced visibility due to mist and fog in higher elevation areas.';
    }
    if (code == 0 || code == 1) {
      return 'Pleasant clear conditions across Barili, Cebu. Stay hydrated under the sun.';
    }
    return 'Moderate cloud cover across Barili. Ideal for daytime travel and outdoor tasks.';
  }
}

/// A comprehensive real-time and cached weather reading for Barili, Cebu.
class BariliWeather {
  final double temperatureCelsius;
  final double apparentTemperatureCelsius;
  final int weatherCode;
  final bool isDay;
  final int humidityPercent;
  final double windSpeedKmh;
  final double precipitationMm;
  final int cloudCoverPercent;
  final double visibilityKm;
  final double? dailyMaxTemp;
  final double? dailyMinTemp;
  final List<BariliHourlyForecast> hourlyForecast;
  final List<BariliDailyForecast> dailyForecast;

  /// Provider time at which the current conditions are valid.
  final DateTime fetchedAt;

  /// Time at which this response was retrieved by the app.
  final DateTime refreshedAt;
  final bool isOffline;

  const BariliWeather({
    required this.temperatureCelsius,
    required this.apparentTemperatureCelsius,
    required this.weatherCode,
    required this.isDay,
    required this.humidityPercent,
    required this.windSpeedKmh,
    required this.precipitationMm,
    required this.cloudCoverPercent,
    required this.visibilityKm,
    this.dailyMaxTemp,
    this.dailyMinTemp,
    this.hourlyForecast = const [],
    this.dailyForecast = const [],
    required this.fetchedAt,
    DateTime? refreshedAt,
    this.isOffline = false,
  }) : refreshedAt = refreshedAt ?? fetchedAt;

  BariliWeather copyWith({bool? isOffline, DateTime? refreshedAt}) {
    return BariliWeather(
      temperatureCelsius: temperatureCelsius,
      apparentTemperatureCelsius: apparentTemperatureCelsius,
      weatherCode: weatherCode,
      isDay: isDay,
      humidityPercent: humidityPercent,
      windSpeedKmh: windSpeedKmh,
      precipitationMm: precipitationMm,
      cloudCoverPercent: cloudCoverPercent,
      visibilityKm: visibilityKm,
      dailyMaxTemp: dailyMaxTemp,
      dailyMinTemp: dailyMinTemp,
      hourlyForecast: hourlyForecast,
      dailyForecast: dailyForecast,
      fetchedAt: fetchedAt,
      refreshedAt: refreshedAt ?? this.refreshedAt,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  factory BariliWeather.fromApi(
    Map<String, dynamic> payload, {
    DateTime? refreshedAt,
  }) {
    BariliWeatherService.validateResponseMetadata(payload);
    final current = (payload['current'] is Map<String, dynamic>)
        ? payload['current'] as Map<String, dynamic>
        : payload;
    final hourly = payload['hourly'] as Map<String, dynamic>? ?? {};
    final daily = payload['daily'] as Map<String, dynamic>? ?? {};

    final temperature = (current['temperature_2m'] as num?)?.toDouble();
    final code = (current['weather_code'] as num?)?.toInt();
    final isDayValue = (current['is_day'] as num?)?.toInt();
    final currentTime = _parsePhilippineProviderTime(current['time']);

    if (temperature == null ||
        !temperature.isFinite ||
        code == null ||
        code < 0 ||
        code > 99 ||
        (isDayValue != 0 && isDayValue != 1) ||
        currentTime == null) {
      throw const FormatException('Invalid current weather data.');
    }

    final apparentTemp = (current['apparent_temperature'] as num?)?.toDouble();
    final humidity = (current['relative_humidity_2m'] as num?)?.toInt();
    final windSpeed = (current['wind_speed_10m'] as num?)?.toDouble();
    final precip = (current['precipitation'] as num?)?.toDouble();
    final cloudCover = (current['cloud_cover'] as num?)?.toInt();
    final visibilityMeters = (current['visibility'] as num?)?.toDouble();
    if (apparentTemp == null ||
        humidity == null ||
        windSpeed == null ||
        precip == null ||
        cloudCover == null ||
        visibilityMeters == null ||
        !apparentTemp.isFinite ||
        !_isFiniteInRange(humidity, 0, 100) ||
        !_isFiniteInRange(cloudCover, 0, 100) ||
        !windSpeed.isFinite ||
        windSpeed < 0 ||
        !precip.isFinite ||
        precip < 0 ||
        !visibilityMeters.isFinite ||
        visibilityMeters < 0) {
      throw const FormatException('Incomplete current weather data.');
    }
    final visibilityKm = visibilityMeters / 1000.0;

    // Parse the upcoming hourly forecast after the current provider time.
    final hourlyList = <BariliHourlyForecast>[];
    final hourlyTimes = (hourly['time'] as List?)?.cast<String>() ?? [];
    final hourlyTemps = (hourly['temperature_2m'] as List?) ?? [];
    final hourlyPrecipProbs =
        (hourly['precipitation_probability'] as List?) ?? [];
    final hourlyCodes = (hourly['weather_code'] as List?) ?? [];
    final hourlyIsDay = (hourly['is_day'] as List?) ?? [];

    final completeHourlyLength = [
      hourlyTimes.length,
      hourlyTemps.length,
      hourlyPrecipProbs.length,
      hourlyCodes.length,
      hourlyIsDay.length,
    ].reduce((a, b) => a < b ? a : b);
    int startIndex = completeHourlyLength;
    for (int i = 0; i < completeHourlyLength; i++) {
      final time = _parsePhilippineProviderTime(hourlyTimes[i]);
      if (time != null && time.isAfter(currentTime)) {
        startIndex = i;
        break;
      }
    }

    // The page renders its "Now" card from the current-condition fields. This
    // list therefore contains only real future forecast hours.
    final endIndex = (startIndex + 23).clamp(0, completeHourlyLength);
    for (int i = startIndex; i < endIndex; i++) {
      final t = _parsePhilippineProviderTime(hourlyTimes[i]);
      final temp = (hourlyTemps[i] as num?)?.toDouble();
      final prob = (hourlyPrecipProbs[i] as num?)?.toInt();
      final c = (hourlyCodes[i] as num?)?.toInt();
      final isDayTime = (hourlyIsDay[i] as num?)?.toInt();
      if (t == null ||
          temp == null ||
          prob == null ||
          c == null ||
          isDayTime == null ||
          !temp.isFinite ||
          !_isFiniteInRange(prob, 0, 100) ||
          c < 0 ||
          c > 99 ||
          (isDayTime != 0 && isDayTime != 1)) {
        continue;
      }

      hourlyList.add(
        BariliHourlyForecast(
          time: t,
          temperatureCelsius: temp,
          precipitationProbability: prob,
          weatherCode: c,
          isDay: isDayTime != 0,
        ),
      );
    }

    // Parse Daily (7 days)
    final dailyList = <BariliDailyForecast>[];
    final dailyTimes = (daily['time'] as List?)?.cast<String>() ?? [];
    final dailyCodes = (daily['weather_code'] as List?) ?? [];
    final dailyMaxTemps = (daily['temperature_2m_max'] as List?) ?? [];
    final dailyMinTemps = (daily['temperature_2m_min'] as List?) ?? [];
    final dailyPrecipProbs =
        (daily['precipitation_probability_max'] as List?) ?? [];
    final dailyPrecipSums = (daily['precipitation_sum'] as List?) ?? [];

    final completeDailyLength = [
      dailyTimes.length,
      dailyCodes.length,
      dailyMaxTemps.length,
      dailyMinTemps.length,
      dailyPrecipProbs.length,
      dailyPrecipSums.length,
    ].reduce((a, b) => a < b ? a : b);
    for (int i = 0; i < completeDailyLength && i < 7; i++) {
      final d = _parsePhilippineProviderTime(dailyTimes[i]);
      final c = (dailyCodes[i] as num?)?.toInt();
      final maxT = (dailyMaxTemps[i] as num?)?.toDouble();
      final minT = (dailyMinTemps[i] as num?)?.toDouble();
      final prob = (dailyPrecipProbs[i] as num?)?.toInt();
      final sum = (dailyPrecipSums[i] as num?)?.toDouble();
      if (d == null ||
          c == null ||
          maxT == null ||
          minT == null ||
          prob == null ||
          sum == null ||
          !maxT.isFinite ||
          !minT.isFinite ||
          !sum.isFinite ||
          c < 0 ||
          c > 99 ||
          !_isFiniteInRange(prob, 0, 100) ||
          sum < 0 ||
          maxT < minT) {
        continue;
      }

      dailyList.add(
        BariliDailyForecast(
          date: d,
          weatherCode: c,
          tempMax: maxT,
          tempMin: minT,
          precipitationProbability: prob,
          precipitationSumMm: sum,
        ),
      );
    }

    final todayMax = dailyList.isNotEmpty ? dailyList.first.tempMax : null;
    final todayMin = dailyList.isNotEmpty ? dailyList.first.tempMin : null;

    return BariliWeather(
      temperatureCelsius: temperature,
      apparentTemperatureCelsius: apparentTemp,
      weatherCode: code,
      isDay: isDayValue != 0,
      humidityPercent: humidity,
      windSpeedKmh: windSpeed,
      precipitationMm: precip,
      cloudCoverPercent: cloudCover,
      visibilityKm: visibilityKm,
      dailyMaxTemp: todayMax,
      dailyMinTemp: todayMin,
      hourlyForecast: hourlyList,
      dailyForecast: dailyList,
      fetchedAt: currentTime,
      refreshedAt: refreshedAt?.toUtc() ?? DateTime.now().toUtc(),
      isOffline: false,
    );
  }

  factory BariliWeather.fromJson(Map<String, dynamic> json) {
    final hourlyRaw = (json['hourlyForecast'] as List?) ?? [];
    final dailyRaw = (json['dailyForecast'] as List?) ?? [];

    final temperature = (json['temperatureCelsius'] as num?)?.toDouble();
    final apparent = (json['apparentTemperatureCelsius'] as num?)?.toDouble();
    final code = (json['weatherCode'] as num?)?.toInt();
    final isDay = json['isDay'];
    final humidity = (json['humidityPercent'] as num?)?.toInt();
    final wind = (json['windSpeedKmh'] as num?)?.toDouble();
    final precipitation = (json['precipitationMm'] as num?)?.toDouble();
    final cloudCover = (json['cloudCoverPercent'] as num?)?.toInt();
    final visibility = (json['visibilityKm'] as num?)?.toDouble();
    final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
    final refreshedAt = DateTime.tryParse(
      json['refreshedAt'] as String? ?? json['fetchedAt'] as String? ?? '',
    );
    if (temperature == null ||
        apparent == null ||
        code == null ||
        isDay is! bool ||
        humidity == null ||
        wind == null ||
        precipitation == null ||
        cloudCover == null ||
        visibility == null ||
        fetchedAt == null ||
        refreshedAt == null ||
        !temperature.isFinite ||
        !apparent.isFinite ||
        code < 0 ||
        code > 99 ||
        humidity < 0 ||
        humidity > 100 ||
        !wind.isFinite ||
        wind < 0 ||
        !precipitation.isFinite ||
        precipitation < 0 ||
        cloudCover < 0 ||
        cloudCover > 100 ||
        !visibility.isFinite ||
        visibility < 0) {
      throw const FormatException('Incomplete cached weather data.');
    }
    return BariliWeather(
      temperatureCelsius: temperature,
      apparentTemperatureCelsius: apparent,
      weatherCode: code,
      isDay: isDay,
      humidityPercent: humidity,
      windSpeedKmh: wind,
      precipitationMm: precipitation,
      cloudCoverPercent: cloudCover,
      visibilityKm: visibility,
      dailyMaxTemp: (json['dailyMaxTemp'] as num?)?.toDouble(),
      dailyMinTemp: (json['dailyMinTemp'] as num?)?.toDouble(),
      hourlyForecast: hourlyRaw
          .map(
            (item) =>
                BariliHourlyForecast.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      dailyForecast: dailyRaw
          .map(
            (item) =>
                BariliDailyForecast.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      fetchedAt: fetchedAt,
      refreshedAt: refreshedAt,
      isOffline: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'temperatureCelsius': temperatureCelsius,
    'apparentTemperatureCelsius': apparentTemperatureCelsius,
    'weatherCode': weatherCode,
    'isDay': isDay,
    'humidityPercent': humidityPercent,
    'windSpeedKmh': windSpeedKmh,
    'precipitationMm': precipitationMm,
    'cloudCoverPercent': cloudCoverPercent,
    'visibilityKm': visibilityKm,
    'dailyMaxTemp': dailyMaxTemp,
    'dailyMinTemp': dailyMinTemp,
    'hourlyForecast': hourlyForecast.map((h) => h.toJson()).toList(),
    'dailyForecast': dailyForecast.map((d) => d.toJson()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'refreshedAt': refreshedAt.toIso8601String(),
    'isOffline': isOffline,
  };

  String get condition =>
      BariliWeatherConditionHelper.condition(weatherCode, isDay);
  IconData get icon => BariliWeatherConditionHelper.icon(weatherCode, isDay);
  WeatherAnimationType get animationType =>
      BariliWeatherConditionHelper.animationType(weatherCode);
  String get advisory =>
      BariliWeatherConditionHelper.advisoryDescription(weatherCode);

  /// Returns a clean formatted update timestamp string, e.g. "8:20 PM"
  String get formattedUpdatedTime {
    final localTime = _asPhilippineClock(fetchedAt);
    final hour = localTime.hour == 0
        ? 12
        : (localTime.hour > 12 ? localTime.hour - 12 : localTime.hour);
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = localTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Labels the provider condition time and identifies cached fallback data.
  String get updateBadgeLabel {
    if (isOffline) {
      return 'Cached • as of $formattedUpdatedTime';
    }
    return 'Conditions as of $formattedUpdatedTime';
  }
}

/// Service providing real-time, cached meteorological data strictly for Barili, Cebu.
class BariliWeatherService {
  static const _cacheKey = 'barili_weather_full_cache_v3';
  static const cacheDuration = Duration(minutes: 15);
  static const locationName = 'Barili, Cebu, Philippines';
  static const timezone = 'Asia/Manila';
  static const utcOffsetSeconds = 8 * 60 * 60;

  // Fixed Barili municipal coordinates. No GPS or ambiguous place-name lookup
  // is used for current, hourly, or daily data.
  static const double latitude = 10.1114;
  static const double longitude = 123.5113;
  static const double _bariliMinLatitude = 10.039378;
  static const double _bariliMaxLatitude = 10.186907;
  static const double _bariliMinLongitude = 123.466798;
  static const double _bariliMaxLongitude = 123.600014;

  static Uri
  get forecastUri => Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': latitude.toString(),
    'longitude': longitude.toString(),
    'current':
        'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,wind_speed_10m,visibility',
    'hourly': 'temperature_2m,precipitation_probability,weather_code,is_day',
    'daily':
        'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum',
    'temperature_unit': 'celsius',
    'wind_speed_unit': 'kmh',
    'precipitation_unit': 'mm',
    'timeformat': 'iso8601',
    'timezone': timezone,
    'forecast_days': '7',
  });

  static DateTime toPhilippineTime(DateTime instant) =>
      _asPhilippineClock(instant);

  static bool isCacheFresh(BariliWeather weather, {DateTime? now}) {
    final age = (now ?? DateTime.now().toUtc()).toUtc().difference(
      weather.refreshedAt.toUtc(),
    );
    if (age < const Duration(minutes: -1)) return false;
    return age <= cacheDuration;
  }

  static void validateResponseMetadata(Map<String, dynamic> payload) {
    final responseTimezone = payload['timezone']?.toString();
    if (responseTimezone != null && responseTimezone != timezone) {
      throw FormatException('Unexpected weather timezone: $responseTimezone');
    }

    final offset = (payload['utc_offset_seconds'] as num?)?.toInt();
    if (offset != null && offset != utcOffsetSeconds) {
      throw FormatException('Unexpected weather UTC offset: $offset');
    }

    final resolvedLatitude = (payload['latitude'] as num?)?.toDouble();
    final resolvedLongitude = (payload['longitude'] as num?)?.toDouble();
    if (resolvedLatitude != null &&
        resolvedLongitude != null &&
        (resolvedLatitude < _bariliMinLatitude ||
            resolvedLatitude > _bariliMaxLatitude ||
            resolvedLongitude < _bariliMinLongitude ||
            resolvedLongitude > _bariliMaxLongitude)) {
      throw const FormatException(
        'Weather provider resolved a location outside Barili.',
      );
    }

    final currentUnits = payload['current_units'];
    if (currentUnits is Map<String, dynamic>) {
      _validateUnit(currentUnits, 'temperature_2m', {'°C'});
      _validateUnit(currentUnits, 'apparent_temperature', {'°C'});
      _validateUnit(currentUnits, 'relative_humidity_2m', {'%'});
      _validateUnit(currentUnits, 'wind_speed_10m', {'km/h'});
      _validateUnit(currentUnits, 'precipitation', {'mm'});
      _validateUnit(currentUnits, 'visibility', {'m'});
    }
    final hourlyUnits = payload['hourly_units'];
    if (hourlyUnits is Map<String, dynamic>) {
      _validateUnit(hourlyUnits, 'temperature_2m', {'°C'});
      _validateUnit(hourlyUnits, 'precipitation_probability', {'%'});
    }
    final dailyUnits = payload['daily_units'];
    if (dailyUnits is Map<String, dynamic>) {
      _validateUnit(dailyUnits, 'temperature_2m_max', {'°C'});
      _validateUnit(dailyUnits, 'temperature_2m_min', {'°C'});
      _validateUnit(dailyUnits, 'precipitation_probability_max', {'%'});
      _validateUnit(dailyUnits, 'precipitation_sum', {'mm'});
    }
  }

  /// Loads cached weather immediately from local storage for zero-delay startup display.
  static Future<BariliWeather?> loadCached() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_cacheKey);
      if (encoded != null && encoded.isNotEmpty) {
        final map = jsonDecode(encoded) as Map<String, dynamic>;
        return BariliWeather.fromJson(map).copyWith(isOffline: false);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches real-time weather from Open-Meteo for Barili, Cebu and caches it.
  /// If the network fails, gracefully falls back to the latest cached data.
  static Future<BariliWeather> fetchLatest() async {
    try {
      final response = await http
          .get(forecastUri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final weather = BariliWeather.fromApi(
          payload,
          refreshedAt: DateTime.now().toUtc(),
        );

        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(_cacheKey, jsonEncode(weather.toJson()));
        _debugLogSuccess(payload, weather);
        return weather;
      }
      _debugLogFailure('HTTP ${response.statusCode}');
    } catch (error) {
      _debugLogFailure(error);
      // Network or parsing failed - fallback to cached data below
    }

    final cached = await loadCached();
    if (cached != null) {
      return cached.copyWith(isOffline: true);
    }

    throw StateError('Weather data is currently unavailable.');
  }

  static void _debugLogSuccess(
    Map<String, dynamic> payload,
    BariliWeather weather,
  ) {
    assert(() {
      final resolvedLatitude = payload['latitude'] ?? latitude;
      final resolvedLongitude = payload['longitude'] ?? longitude;
      debugPrint(
        '[BariliWeather] location=$locationName '
        'requested=($latitude,$longitude) '
        'resolved=($resolvedLatitude,$resolvedLongitude) '
        'timezone=$timezone observation=${weather.fetchedAt.toIso8601String()} '
        'temperature=${weather.temperatureCelsius}°C '
        'condition=${weather.condition} source=Open-Meteo '
        'refreshed=${weather.refreshedAt.toIso8601String()}',
      );
      return true;
    }());
  }

  static void _debugLogFailure(Object error) {
    assert(() {
      debugPrint(
        '[BariliWeather] request failed for $locationName '
        '($latitude,$longitude), timezone=$timezone: $error',
      );
      return true;
    }());
  }
}
