import 'package:esugid/services/barili_weather_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the verified Barili, Cebu coordinates', () {
    expect(BariliWeatherService.latitude, closeTo(10.1114, 0.0001));
    expect(BariliWeatherService.longitude, closeTo(123.5113, 0.0001));
    expect(
      BariliWeatherService.forecastUri.queryParameters['timezone'],
      'Asia/Manila',
    );
    expect(
      BariliWeatherService.forecastUri.queryParameters['wind_speed_unit'],
      'kmh',
    );
    expect(
      BariliWeatherService.forecastUri.queryParameters['forecast_days'],
      '7',
    );
  });

  test('maps current WMO weather codes to readable conditions', () {
    BariliWeather weather(int code, {bool isDay = true}) => BariliWeather(
      temperatureCelsius: 28.4,
      apparentTemperatureCelsius: 30.1,
      weatherCode: code,
      isDay: isDay,
      humidityPercent: 77,
      windSpeedKmh: 8.2,
      precipitationMm: 0,
      cloudCoverPercent: 35,
      visibilityKm: 12,
      fetchedAt: DateTime(2026, 8, 26),
    );

    expect(weather(0).condition, 'Sunny');
    expect(weather(0, isDay: false).condition, 'Clear');
    expect(weather(2).condition, 'Partly Cloudy');
    expect(weather(3).condition, 'Overcast');
    expect(weather(61).condition, 'Light Rain');
    expect(weather(65).condition, 'Heavy Rain');
    expect(weather(95).condition, 'Thunderstorm');
    expect(weather(99).condition, 'Thunderstorm with Heavy Hail');
  });

  test('rejects incomplete API weather instead of showing fake values', () {
    expect(
      () => BariliWeather.fromApi(const {'temperature_2m': 28.0}),
      throwsFormatException,
    );
  });

  test('parses complete Open-Meteo readings without substituted values', () {
    final refreshedAt = DateTime.parse('2099-09-12T13:46:00Z');
    final weather = BariliWeather.fromApi({
      'latitude': 10.087873,
      'longitude': 123.52323,
      'timezone': 'Asia/Manila',
      'utc_offset_seconds': 28800,
      'current_units': {
        'temperature_2m': '°C',
        'apparent_temperature': '°C',
        'relative_humidity_2m': '%',
        'wind_speed_10m': 'km/h',
        'precipitation': 'mm',
        'visibility': 'm',
      },
      'current': {
        'time': '2099-09-12T21:45',
        'temperature_2m': 26.2,
        'apparent_temperature': 29.4,
        'relative_humidity_2m': 88,
        'wind_speed_10m': 4.7,
        'precipitation': 0.3,
        'weather_code': 51,
        'cloud_cover': 73,
        'visibility': 9400,
        'is_day': 0,
      },
      'hourly': {
        'time': ['2099-09-12T21:00', '2099-09-12T22:00', '2099-09-12T23:00'],
        'temperature_2m': [26.4, 25.9, 25.4],
        'precipitation_probability': [22, 37, 42],
        'weather_code': [2, 51, 61],
        'is_day': [0, 0, 0],
      },
      'daily': {
        'time': ['2099-09-12'],
        'weather_code': [61],
        'temperature_2m_max': [30.6],
        'temperature_2m_min': [24.9],
        'precipitation_probability_max': [68],
        'precipitation_sum': [4.2],
      },
    }, refreshedAt: refreshedAt);

    expect(weather.temperatureCelsius, 26.2);
    expect(weather.apparentTemperatureCelsius, 29.4);
    expect(weather.humidityPercent, 88);
    expect(weather.windSpeedKmh, 4.7);
    expect(weather.precipitationMm, 0.3);
    expect(weather.visibilityKm, 9.4);
    expect(weather.hourlyForecast, hasLength(2));
    expect(
      BariliWeatherService.toPhilippineTime(
        weather.hourlyForecast.first.time,
      ).hour,
      22,
    );
    expect(weather.hourlyForecast.first.isDay, isFalse);
    expect(weather.dailyForecast.single.tempMax, 30.6);
    expect(weather.temperatureCelsius, isNot(weather.dailyMaxTemp));
    expect(weather.refreshedAt, refreshedAt);
    expect(weather.formattedUpdatedTime, '9:45 PM');
  });

  test('rejects responses resolved outside Barili or outside UTC+8', () {
    expect(
      () => BariliWeatherService.validateResponseMetadata({
        'latitude': 10.3157,
        'longitude': 123.8854,
        'timezone': 'Asia/Manila',
      }),
      throwsFormatException,
    );
    expect(
      () => BariliWeatherService.validateResponseMetadata({
        'timezone': 'UTC',
        'utc_offset_seconds': 0,
      }),
      throwsFormatException,
    );
  });

  test('treats cached responses as fresh for no more than 15 minutes', () {
    final refreshedAt = DateTime.parse('2026-09-13T00:00:00Z');
    final weather = BariliWeather(
      temperatureCelsius: 28,
      apparentTemperatureCelsius: 30,
      weatherCode: 2,
      isDay: true,
      humidityPercent: 70,
      windSpeedKmh: 8,
      precipitationMm: 0,
      cloudCoverPercent: 40,
      visibilityKm: 12,
      fetchedAt: refreshedAt,
      refreshedAt: refreshedAt,
    );

    expect(
      BariliWeatherService.isCacheFresh(
        weather,
        now: refreshedAt.add(const Duration(minutes: 14)),
      ),
      isTrue,
    );
    expect(
      BariliWeatherService.isCacheFresh(
        weather,
        now: refreshedAt.add(const Duration(minutes: 16)),
      ),
      isFalse,
    );
  });

  test('cached weather round-trips without losing its reading', () {
    final original = BariliWeather(
      temperatureCelsius: 27.8,
      apparentTemperatureCelsius: 29.2,
      weatherCode: 63,
      isDay: true,
      humidityPercent: 81,
      windSpeedKmh: 9.5,
      precipitationMm: 1.2,
      cloudCoverPercent: 72,
      visibilityKm: 8.4,
      fetchedAt: DateTime.parse('2026-08-26T10:00:00+08:00'),
      refreshedAt: DateTime.parse('2026-08-26T02:02:00Z'),
    );
    final restored = BariliWeather.fromJson(original.toJson());

    expect(restored.temperatureCelsius, original.temperatureCelsius);
    expect(restored.weatherCode, original.weatherCode);
    expect(restored.isDay, original.isDay);
    expect(restored.fetchedAt, original.fetchedAt);
    expect(restored.refreshedAt, original.refreshedAt);
  });
}
