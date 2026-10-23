import 'package:esugid/app/theme/semantic_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_motion.dart';
import '../app/theme/app_colors.dart';
import '../core/widgets/esugid_pull_to_refresh.dart';
import '../services/barili_weather_service.dart';
import '../widgets/weather_animation_effects.dart';
import '../widgets/weather_realistic_graphics.dart';

/// Dedicated detailed weather forecast page for Barili, Cebu.
///
/// Informational weather dashboard with hourly projections, 7-day outlook,
/// and live meteorological metrics.
class BariliWeatherPage extends StatefulWidget {
  final BariliWeather? initialWeather;
  final ValueChanged<BariliWeather>? onWeatherUpdated;

  const BariliWeatherPage({
    super.key,
    this.initialWeather,
    this.onWeatherUpdated,
  });

  @override
  State<BariliWeatherPage> createState() => _BariliWeatherPageState();
}

class _BariliWeatherPageState extends State<BariliWeatherPage> {
  BariliWeather? _weather;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _weather = widget.initialWeather;
    unawaited(_initializeWeather());
  }

  Future<void> _initializeWeather() async {
    var availableWeather = _weather;
    if (availableWeather == null) {
      availableWeather = await BariliWeatherService.loadCached();
      if (mounted && availableWeather != null) {
        setState(() => _weather = availableWeather);
      }
    }

    if (availableWeather == null ||
        availableWeather.isOffline ||
        !BariliWeatherService.isCacheFresh(availableWeather)) {
      await _handleRefresh();
    }
  }

  Future<void> _handleRefresh() async {
    if (!mounted || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final latest = await BariliWeatherService.fetchLatest();
      if (mounted) {
        widget.onWeatherUpdated?.call(latest);
        setState(() {
          _weather = latest;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_weather == null) {
            _errorMessage = 'Unable to load weather. Check your connection.';
          } else {
            _weather = _weather!.copyWith(isOffline: true);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weather = _weather;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(context, isDark, weather),
            Expanded(
              child: ESugidPullToRefresh(
                onRefresh: () async {
                  await _handleRefresh();
                  return ESugidRefreshOutcome.updated;
                },
                child: weather == null
                    ? _buildLoadingOrError(isDark)
                    : _buildContent(context, isDark, weather),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    bool isDark,
    BariliWeather? weather,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Circular Back button
          ESugidPressable(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                      : context.colors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.05,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 17,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BARILI WEATHER',
                  style: GoogleFonts.outfit(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: isDark
                          ? context.colors.textSecondary
                          : context.colors.primaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      BariliWeatherService.locationName,
                      style: GoogleFonts.outfit(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Refresh Button
          ESugidPressable(
            onTap: _handleRefresh,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.colors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                      : context.colors.border,
                ),
              ),
              child: _isLoading
                  ? Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.brand,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: context.colors.textPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOrError(bool isDark) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: context.colors.info,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _handleRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  foregroundColor: context.colors.onAccent,

                  backgroundColor: context.colors.brand,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: CircularProgressIndicator(color: context.colors.primaryGreen),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    BariliWeather weather,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // 1. Hero Showcase Card with Animation
        _buildHeroCard(isDark, weather),
        if (weather.isOffline) ...[
          const SizedBox(height: 10),
          _buildOutdatedNotice(isDark),
        ],
        const SizedBox(height: 18),

        // 2. Hourly Forecast (24h)
        _buildSectionHeader('HOURLY FORECAST', Icons.schedule_rounded, isDark),
        const SizedBox(height: 10),
        _buildHourlyList(isDark, weather),
        const SizedBox(height: 20),

        // 3. Today's Atmospheric Metrics Grid
        _buildSectionHeader(
          "TODAY'S CONDITIONS",
          Icons.dashboard_outlined,
          isDark,
        ),
        const SizedBox(height: 10),
        _buildMetricsGrid(isDark, weather),
        const SizedBox(height: 20),

        // 4. Multi-Day Forecast (7-day outlook)
        if (weather.dailyForecast.isNotEmpty) ...[
          _buildSectionHeader(
            '7-DAY OUTLOOK',
            Icons.calendar_today_rounded,
            isDark,
          ),
          const SizedBox(height: 10),
          _buildDailyForecastCard(isDark, weather.dailyForecast, weather),
          const SizedBox(height: 20),
        ],

        // 5. Official Disaster & Emergency Informational Disclaimer
        _buildEmergencyNotice(isDark),
      ],
    );
  }

  Widget _buildHeroCard(bool isDark, BariliWeather weather) {
    final isDay = weather.isDay;

    // Atmospheric sky gradient according to weather condition and time of day
    final List<Color> gradientColors = switch (weather.animationType) {
      WeatherAnimationType.sunny =>
        isDay
            ? [
                context.colors.brandStrong,
                context.colors.brand,
                context.colors.brand,
                context.colors.brand,
              ]
            : [
                context.colors.brandStrong,
                context.colors.brandStrong,
                context.colors.brandStrong,
              ],
      WeatherAnimationType.cloudy =>
        isDay
            ? [
                context.colors.brandStrong,
                context.colors.brand,
                context.colors.brand,
              ]
            : [
                context.colors.brandStrong,
                context.colors.brandStrong,
                context.colors.brandStrong,
              ],
      WeatherAnimationType.lightRain || WeatherAnimationType.heavyRain =>
        isDay
            ? [
                context.colors.brandStrong,
                context.colors.brand,
                context.colors.brand,
              ]
            : [
                context.colors.brandStrong,
                context.colors.infoSolid,
                context.colors.infoSolid,
              ],
      WeatherAnimationType.thunderstorm => [
        context.colors.brandStrong,
        context.colors.infoSolid,
        context.colors.infoSolid,
      ],
      _ => [
        context.colors.brandStrong,
        context.colors.brand,
        context.colors.brand,
      ],
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.42),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Atmospheric particle & cloud diffusion layer
            Positioned.fill(
              child: WeatherAnimationWidget(
                type: weather.animationType,
                isDay: weather.isDay,
                isCompact: false,
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top badge row: Status / Update time + Day/Night
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surface.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.colors.border.withValues(alpha: 0.30,
                            ),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.shadow.withValues(alpha: 0.12,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: weather.isOffline
                                    ? context.colors.warningSolid
                                    : context.colors.brand,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (weather.isOffline
                                                ? context.colors.highlight
                                                : context.colors.brandStrong)
                                            .withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              weather.updateBadgeLabel,
                              style: GoogleFonts.outfit(
                                color: context.colors.onAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.shadow.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.colors.border.withValues(alpha: 0.15,
                            ),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDay
                                  ? Icons.wb_sunny_rounded
                                  : Icons.nightlight_round,
                              size: 11,
                              color: isDay
                                  ? context.colors.warning
                                  : context.colors.info,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isDay ? 'DAY' : 'NIGHT',
                              style: GoogleFonts.outfit(
                                color: context.colors.onAccent.withValues(alpha: 0.9,
                                ),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Main Temperature & Condition Row with 3D Realistic Weather Scene
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${weather.temperatureCelsius.round()}°',
                              style: GoogleFonts.outfit(
                                color: context.colors.onAccent,
                                fontSize: 72,
                                fontWeight: FontWeight.w900,
                                height: 0.92,
                                letterSpacing: -2.5,
                                shadows: [
                                  Shadow(
                                    color: context.colors.textPrimary,
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              weather.condition,
                              style: GoogleFonts.outfit(
                                color: context.colors.onAccent,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                shadows: [
                                  Shadow(
                                    color: context.colors.textPrimary,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Large 3D Volumetric Realistic Weather Graphic
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.shadow.withValues(alpha: 0.20,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: RealisticWeatherGraphic(
                          weatherCode: weather.weatherCode,
                          isDay: weather.isDay,
                          size: 82,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Glassmorphic Feels Like and Daily High / Low
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.shadow.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: 0.18),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.thermostat_rounded,
                              size: 15,
                              color: context.colors.warning,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Feels like ${weather.apparentTemperatureCelsius.round()}°C',
                              style: GoogleFonts.outfit(
                                color: context.colors.onAccent.withValues(alpha: 0.95,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (weather.dailyMaxTemp != null &&
                            weather.dailyMinTemp != null)
                          Text(
                            'High ${weather.dailyMaxTemp!.round()}° • Low ${weather.dailyMinTemp!.round()}°',
                            style: GoogleFonts.outfit(
                              color: context.colors.onAccent.withValues(alpha: 0.88,
                              ),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Advisory Description
                  const SizedBox(height: 10),
                  Text(
                    weather.advisory,
                    style: GoogleFonts.outfit(
                      color: context.colors.onAccent.withValues(alpha: 0.82),
                      fontSize: 12,
                      height: 1.38,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  (context.colors.surfaceAlt)
                      .withValues(alpha: 0.7),
            ),
            child: Icon(
              icon,
              size: 13,
              color: isDark ? context.colors.textSecondary
                  : context.colors.primaryGreen,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: context.colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutdatedNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: BoxDecoration(
        color: context.colors.warningSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 17,
            color: context.colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Weather data may be outdated',
              style: GoogleFonts.outfit(
                color: context.colors.warning,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _handleRefresh,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.warning,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyList(bool isDark, BariliWeather weather) {
    final list = weather.hourlyForecast;
    return SizedBox(
      height: 136,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final isCurrent = index == 0;
          final hour = isCurrent ? null : list[index - 1];
          final timeStr = isCurrent ? 'Now' : _formatHour(hour!.time);
          final weatherCode = isCurrent
              ? weather.weatherCode
              : hour!.weatherCode;
          final isDay = isCurrent ? weather.isDay : hour!.isDay;
          final temperature = isCurrent
              ? weather.temperatureCelsius
              : hour!.temperatureCelsius;
          final precipitationProbability = isCurrent
              ? null
              : hour!.precipitationProbability;

          return Container(
            width: 74,
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            decoration: BoxDecoration(
              gradient: isCurrent
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.brand,
                        context.colors.brand,
                        context.colors.brandStrong,
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [context.colors.surface, context.colors.surface],
                    ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCurrent
                    ? context.colors.border.withValues(alpha: 0.85)
                    : (isDark ? context.colors.border.withValues(alpha: 0.1216)
                          : context.colors.border),
                width: isCurrent ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isCurrent
                      ? context.colors.brandStrong.withValues(alpha: 0.40)
                      : context.colors.shadow.withValues(alpha: isDark ? 0.25 : 0.05,
                        ),
                  blurRadius: isCurrent ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: isCurrent
                        ? context.colors.onAccent
                        : (context.colors.textPrimary),
                  ),
                ),
                RealisticWeatherGraphic(
                  weatherCode: weatherCode,
                  isDay: isDay,
                  size: 28,
                ),
                Text(
                  '${temperature.round()}°',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isCurrent
                        ? context.colors.onAccent
                        : (context.colors.textPrimary),
                  ),
                ),
                if (precipitationProbability != null &&
                    precipitationProbability > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? context.colors.surface.withValues(alpha: 0.22)
                          : context.colors.infoSolid.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.water_drop_rounded,
                          size: 8,
                          color: isCurrent
                              ? context.colors.onAccent
                              : context.colors.info,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$precipitationProbability%',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isCurrent
                                ? context.colors.onAccent
                                : context.colors.info,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 14),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricsGrid(bool isDark, BariliWeather weather) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              width: cardWidth,
              isDark: isDark,
              icon: Icons.water_drop_rounded,
              label: 'HUMIDITY',
              value: '${weather.humidityPercent}%',
              subtext: weather.humidityPercent > 75
                  ? 'High moisture'
                  : (weather.humidityPercent < 40 ? 'Dry air' : 'Comfortable'),
              color: context.colors.infoSolid,
              gaugeRatio: (weather.humidityPercent / 100.0).clamp(0.05, 1.0),
            ),
            _buildMetricCard(
              width: cardWidth,
              isDark: isDark,
              icon: Icons.air_rounded,
              label: 'WIND SPEED',
              value: '${weather.windSpeedKmh.toStringAsFixed(1)} km/h',
              subtext: weather.windSpeedKmh > 20
                  ? 'Moderate breeze'
                  : 'Gentle breeze',
              color: context.colors.brand,
              gaugeRatio: (weather.windSpeedKmh / 40.0).clamp(0.05, 1.0),
            ),
            _buildMetricCard(
              width: cardWidth,
              isDark: isDark,
              icon: Icons.grain_rounded,
              label: 'PRECIPITATION',
              value: '${weather.precipitationMm.toStringAsFixed(1)} mm',
              subtext: weather.precipitationMm > 0
                  ? 'Active rainfall'
                  : 'Zero precipitation',
              color: context.colors.infoSolid,
              gaugeRatio: weather.precipitationMm > 0
                  ? (weather.precipitationMm / 15.0).clamp(0.1, 1.0)
                  : 0.0,
            ),
            _buildMetricCard(
              width: cardWidth,
              isDark: isDark,
              icon: Icons.visibility_rounded,
              label: 'VISIBILITY',
              value: '${weather.visibilityKm.toStringAsFixed(1)} km',
              subtext: weather.visibilityKm >= 10
                  ? 'Optimal clarity'
                  : 'Reduced mist',
              color: context.colors.warningSolid,
              gaugeRatio: (weather.visibilityKm / 35.0).clamp(0.05, 1.0),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required double width,
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color color,
    required double gaugeRatio,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surface, context.colors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? context.colors.border.withValues(alpha: 0.1020)
              : context.colors.border,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.28 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    colors: [
                      color.withValues(alpha: 0.25),
                      color.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: color.withValues(alpha: 0.40),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.16),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(child: Icon(icon, size: 16, color: color)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: context.colors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: context.colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: GoogleFonts.outfit(
              color: context.colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          WeatherMetricGauge(
            ratio: gaugeRatio,
            primaryColor: color,
            secondaryColor: isDark ? context.colors.infoSurface.withValues(alpha: 0.1216)
                : context.colors.infoSurface,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyForecastCard(
    bool isDark,
    List<BariliDailyForecast> daily,
    BariliWeather weather,
  ) {
    double globalMin = 100;
    double globalMax = -100;
    for (final day in daily) {
      if (day.tempMin < globalMin) globalMin = day.tempMin;
      if (day.tempMax > globalMax) globalMax = day.tempMax;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surface, context.colors.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? context.colors.border.withValues(alpha: 0.1020)
              : context.colors.border,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.28 : 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(daily.length, (index) {
          final item = daily[index];
          final isToday = index == 0;
          final dayName = isToday
              ? 'Today'
              : (index == 1 ? 'Tomorrow' : _formatWeekday(item.date));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    // Day name column
                    SizedBox(
                      width: 76,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              dayName,
                              style: GoogleFonts.outfit(
                                color: isToday
                                    ? context.colors.primaryGreen
                                    : (context.colors.textPrimary),
                                fontSize: 13,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 3D Realistic Weather icon
                    RealisticWeatherGraphic(
                      weatherCode: item.weatherCode,
                      isDay: true,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    // Condition text
                    SizedBox(
                      width: 72,
                      child: Text(
                        item.condition,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: context.colors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Rain chance badge if > 0
                    SizedBox(
                      width: 44,
                      child: item.precipitationProbability > 0
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.water_drop_rounded,
                                  size: 9,
                                  color: context.colors.info,
                                ),
                                const SizedBox(width: 1),
                                Text(
                                  '${item.precipitationProbability}%',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.info,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 6),
                    // Horizontal Temperature Range Bar
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              '${item.tempMin.round()}°',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.outfit(
                                color: context.colors.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: WeatherTempRangeBar(
                              minTemp: item.tempMin,
                              maxTemp: item.tempMax,
                              globalMin: globalMin,
                              globalMax: globalMax,
                              currentTemp: isToday
                                  ? weather.temperatureCelsius
                                  : null,
                              isToday: isToday,
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 26,
                            child: Text(
                              '${item.tempMax.round()}°',
                              textAlign: TextAlign.left,
                              style: GoogleFonts.outfit(
                                color: context.colors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (index < daily.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.6,
                  color: isDark ? context.colors.border.withValues(alpha: 0.1020)
                      : context.colors.border,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildEmergencyNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.border,
          width: 1.0),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.brand.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              size: 16,
              color: context.colors.primaryGreen,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Official Municipal Meteorological Advisory',
                  style: GoogleFonts.outfit(
                    color: context.colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Weather readings are provided for Barili, Cebu for daily citizen convenience. Official municipal disaster advisories and warnings are issued directly by LGU Barili.',
                  style: GoogleFonts.outfit(
                    color: context.colors.textPrimary,
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatHour(DateTime dt) {
    final hour = BariliWeatherService.toPhilippineTime(dt).hour;
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  String _formatWeekday(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final localDate = BariliWeatherService.toPhilippineTime(dt);
    return days[localDate.weekday - 1];
  }
}
