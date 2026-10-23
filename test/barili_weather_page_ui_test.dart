import 'package:esugid/pages/barili_weather_page.dart';
import 'package:esugid/services/barili_weather_service.dart';
import 'package:esugid/widgets/weather_realistic_graphics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sampleWeather = BariliWeather(
    temperatureCelsius: 30.2,
    apparentTemperatureCelsius: 34.8,
    weatherCode: 2, // Partly Cloudy
    isDay: true,
    humidityPercent: 68,
    windSpeedKmh: 9.4,
    precipitationMm: 0.2,
    cloudCoverPercent: 40,
    visibilityKm: 25.0,
    fetchedAt: DateTime.parse('2026-09-13T08:00:00+08:00'),
    refreshedAt: DateTime.now().toUtc(),
    hourlyForecast: [
      BariliHourlyForecast(
        time: DateTime.parse('2026-09-13T09:00:00+08:00'),
        temperatureCelsius: 31.5,
        precipitationProbability: 15,
        weatherCode: 1,
        isDay: true,
      ),
      BariliHourlyForecast(
        time: DateTime.parse('2026-09-13T10:00:00+08:00'),
        temperatureCelsius: 33.0,
        precipitationProbability: 35,
        weatherCode: 61,
        isDay: true,
      ),
    ],
    dailyForecast: [
      BariliDailyForecast(
        date: DateTime.parse('2026-09-13'),
        weatherCode: 2,
        tempMax: 33.0,
        tempMin: 25.5,
        precipitationProbability: 20,
        precipitationSumMm: 0.5,
      ),
      BariliDailyForecast(
        date: DateTime.parse('2026-09-14'),
        weatherCode: 95,
        tempMax: 31.0,
        tempMin: 24.5,
        precipitationProbability: 85,
        precipitationSumMm: 14.0,
      ),
    ],
  );

  testWidgets(
    'RealisticWeatherGraphic paints correctly for different weather codes',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                RealisticWeatherGraphic(weatherCode: 0, isDay: true, size: 48),
                RealisticWeatherGraphic(weatherCode: 0, isDay: false, size: 48),
                RealisticWeatherGraphic(weatherCode: 2, isDay: true, size: 48),
                RealisticWeatherGraphic(weatherCode: 3, isDay: true, size: 48),
                RealisticWeatherGraphic(weatherCode: 45, isDay: true, size: 48),
                RealisticWeatherGraphic(weatherCode: 61, isDay: true, size: 48),
                RealisticWeatherGraphic(weatherCode: 95, isDay: true, size: 48),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(RealisticWeatherGraphic), findsNWidgets(7));
    },
  );

  testWidgets(
    'WeatherTempRangeBar and WeatherMetricGauge render without overflow',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                WeatherTempRangeBar(
                  minTemp: 24,
                  maxTemp: 34,
                  globalMin: 22,
                  globalMax: 35,
                  currentTemp: 30,
                  isToday: true,
                ),
                WeatherMetricGauge(ratio: 0.68, primaryColor: Colors.teal),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(WeatherTempRangeBar), findsOneWidget);
      expect(find.byType(WeatherMetricGauge), findsOneWidget);
    },
  );

  testWidgets(
    'BariliWeatherPage renders hero section, hourly forecast, conditions grid, and 7-day outlook',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(home: BariliWeatherPage(initialWeather: sampleWeather)),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // App bar
      expect(find.text('BARILI WEATHER'), findsOneWidget);
      expect(find.text('Barili, Cebu, Philippines'), findsOneWidget);

      // Hero Card temperature
      expect(find.text('30°'), findsWidgets);
      expect(find.text('Partly Cloudy'), findsWidgets);
      expect(find.textContaining('Feels like 35°'), findsOneWidget);

      // Section headers
      expect(find.text('HOURLY FORECAST'), findsOneWidget);
      expect(find.text("TODAY'S CONDITIONS"), findsOneWidget);
      expect(find.text('7-DAY OUTLOOK'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('9 AM'), findsOneWidget);

      // Conditions items
      expect(find.text('HUMIDITY'), findsOneWidget);
      expect(find.text('WIND SPEED'), findsOneWidget);
      expect(find.text('PRECIPITATION'), findsOneWidget);
      expect(find.text('VISIBILITY'), findsOneWidget);

      // 7-day items
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
    },
  );
}
