import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';

/// Local date/time selection; applying is the only action that commits a value.
class IncidentDateTimePicker extends StatefulWidget {
  const IncidentDateTimePicker({
    super.key,
    this.initialDateTime,
    required this.onApply,
  });

  final DateTime? initialDateTime;
  final ValueChanged<DateTime> onApply;

  @override
  State<IncidentDateTimePicker> createState() => _IncidentDateTimePickerState();
}

class _IncidentDateTimePickerState extends State<IncidentDateTimePicker> {
  late final DateTime now = DateTime.now();
  late DateTime selectedDate = widget.initialDateTime ?? now;
  late TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
  late DateTime currentMonthView = DateTime(
    selectedDate.year,
    selectedDate.month,
  );

  Widget _buildDateQuickChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.brand : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? context.colors.primaryGreen
                : context.colors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? context.colors.onAccent
                : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeQuickChip(
    String label,
    TimeOfDay time,
    TimeOfDay current,
    ValueChanged<TimeOfDay> onSelected,
  ) {
    final isSelected =
        current.hour == time.hour && (current.minute - time.minute).abs() < 5;
    return InkWell(
      onTap: () => onSelected(time),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.brand : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? context.colors.primaryGreen
                : context.colors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? context.colors.onAccent
                : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayHeight = max(
      40.0,
      MediaQuery.textScalerOf(context).scale(13) * 1.25 + 8,
    );
    final daysInCurrentMonth = DateTime(
      currentMonthView.year,
      currentMonthView.month + 1,
      0,
    ).day;
    final firstDayOffset =
        DateTime(currentMonthView.year, currentMonthView.month, 1).weekday % 7;

    final dayCells = <Widget>[];
    for (int i = 0; i < firstDayOffset; i++) {
      dayCells.add(SizedBox(height: dayHeight));
    }

    for (int day = 1; day <= daysInCurrentMonth; day++) {
      final cellDate = DateTime(
        currentMonthView.year,
        currentMonthView.month,
        day,
      );
      final isToday =
          cellDate.year == now.year &&
          cellDate.month == now.month &&
          cellDate.day == now.day;
      final isSelected =
          cellDate.year == selectedDate.year &&
          cellDate.month == selectedDate.month &&
          cellDate.day == selectedDate.day;
      final isFuture = cellDate.isAfter(
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );

      dayCells.add(
        InkWell(
          key: ValueKey(
            'incident-day-${DateFormat('yyyy-MM-dd').format(cellDate)}',
          ),
          onTap: isFuture
              ? null
              : () {
                  setState(() {
                    selectedDate = cellDate;
                  });
                },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: dayHeight,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? context.colors.brand : Colors.transparent,
              border: isToday && !isSelected
                  ? Border.all(color: context.colors.primaryGreen, width: 1.5)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isSelected
                      ? context.colors.onAccent
                      : isFuture
                      ? context.colors.disabled
                      : isToday
                      ? context.colors.primaryGreen
                      : context.colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final dayRows = <Widget>[];
    for (int i = 0; i < dayCells.length; i += 7) {
      final chunk = dayCells.sublist(i, min(i + 7, dayCells.length));
      while (chunk.length < 7) {
        chunk.add(SizedBox(height: dayHeight));
      }
      dayRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: chunk.map((cell) => Expanded(child: cell)).toList(),
          ),
        ),
      );
    }

    final canGoNextMonth =
        !(currentMonthView.year > now.year ||
            (currentMonthView.year == now.year &&
                currentMonthView.month >= now.month));
    final canGoPrevMonth =
        !(currentMonthView.year <= 2021 && currentMonthView.month <= 1);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab Bar
            Center(
              child: Container(
                width: 40,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? context.colors.infoSurface.withValues(alpha: 0.2392)
                      : context.colors.infoSurface,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.surfaceAlt,
                    border: Border.all(
                      color: context.colors.border,
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.event_available_rounded,
                      color: context.colors.primaryGreen,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Incident Date & Time',
                        style: GoogleFonts.outfit(
                          color: context.colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'When did this incident or concern occur?',
                        style: GoogleFonts.poppins(
                          color: context.colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quick Date Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDateQuickChip(
                  'Today',
                  selectedDate.year == now.year &&
                      selectedDate.month == now.month &&
                      selectedDate.day == now.day,
                  () {
                    setState(() {
                      selectedDate = DateTime(now.year, now.month, now.day);
                      currentMonthView = DateTime(now.year, now.month);
                    });
                  },
                ),
                _buildDateQuickChip(
                  'Yesterday',
                  (() {
                    final y = now.subtract(const Duration(days: 1));
                    return selectedDate.year == y.year &&
                        selectedDate.month == y.month &&
                        selectedDate.day == y.day;
                  })(),
                  () {
                    final y = now.subtract(const Duration(days: 1));
                    setState(() {
                      selectedDate = DateTime(y.year, y.month, y.day);
                      currentMonthView = DateTime(y.year, y.month);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Calendar Container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                children: [
                  // Month Navigation Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: canGoPrevMonth
                            ? () {
                                setState(() {
                                  currentMonthView = DateTime(
                                    currentMonthView.year,
                                    currentMonthView.month - 1,
                                  );
                                });
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded, size: 22),
                        visualDensity: VisualDensity.compact,
                        color: context.colors.brand,
                      ),
                      Expanded(
                        child: Text(
                          DateFormat('MMMM yyyy').format(currentMonthView),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: canGoNextMonth
                            ? () {
                                setState(() {
                                  currentMonthView = DateTime(
                                    currentMonthView.year,
                                    currentMonthView.month + 1,
                                  );
                                });
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded, size: 22),
                        visualDensity: VisualDensity.compact,
                        color: context.colors.brand,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Weekday Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        .map(
                          (d) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  d,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 6),

                  // Days Grid
                  ...dayRows,
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Time Section
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: context.colors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Incident Time',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                // Time Pill
                InkWell(
                  key: const ValueKey('incident-time-edit'),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                      builder: (c, child) {
                        return Theme(
                          data: Theme.of(
                            c,
                          ).copyWith(colorScheme: Theme.of(c).colorScheme),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && mounted) {
                      setState(() => selectedTime = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: context.colors.border,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            selectedTime.format(context),
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: context.colors.primaryGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.edit_rounded,
                          size: 13,
                          color: context.colors.primaryGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Time Quick Presets
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTimeQuickChip(
                    'Now',
                    TimeOfDay.now(),
                    selectedTime,
                    (t) => setState(() => selectedTime = t),
                  ),
                  const SizedBox(width: 6),
                  _buildTimeQuickChip(
                    'Morning (8 AM)',
                    const TimeOfDay(hour: 8, minute: 0),
                    selectedTime,
                    (t) => setState(() => selectedTime = t),
                  ),
                  const SizedBox(width: 6),
                  _buildTimeQuickChip(
                    'Noon (12 PM)',
                    const TimeOfDay(hour: 12, minute: 0),
                    selectedTime,
                    (t) => setState(() => selectedTime = t),
                  ),
                  const SizedBox(width: 6),
                  _buildTimeQuickChip(
                    'Afternoon (3 PM)',
                    const TimeOfDay(hour: 15, minute: 0),
                    selectedTime,
                    (t) => setState(() => selectedTime = t),
                  ),
                  const SizedBox(width: 6),
                  _buildTimeQuickChip(
                    'Evening (6 PM)',
                    const TimeOfDay(hour: 18, minute: 0),
                    selectedTime,
                    (t) => setState(() => selectedTime = t),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live Preview Summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 17,
                    color: context.colors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${DateFormat('EEEE, MMM d, y').format(selectedDate)} at ${selectedTime.format(context)}',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Confirm Action Button
            FilledButton.icon(
              onPressed: () {
                final combined = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                widget.onApply(combined);
              },
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.brand,
                foregroundColor: context.colors.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 1.5,
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(
                'Apply Date & Time',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
