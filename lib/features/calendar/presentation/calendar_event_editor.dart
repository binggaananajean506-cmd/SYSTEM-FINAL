import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../auth_service.dart';
import '../../../barili_barangays.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../widgets/esugid_page_header.dart';
import '../data/calendar_service.dart';
import '../domain/calendar_event.dart';
import 'calendar_event_presentation.dart';

class CalendarEventEditorPage extends StatefulWidget {
  const CalendarEventEditorPage({
    super.key,
    required this.user,
    required this.service,
    required this.personal,
    this.event,
  });

  final User user;
  final CalendarService service;
  final bool personal;
  final CalendarEvent? event;

  @override
  State<CalendarEventEditorPage> createState() =>
      _CalendarEventEditorPageState();
}

class _CalendarEventEditorPageState extends State<CalendarEventEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late DateTime _startAt;
  late DateTime _endAt;
  late CalendarEventCategory _category;
  late CalendarEventVisibility _visibility;
  late String _targetBarangay;
  late bool _allDay;
  late bool _isImportant;
  bool _saving = false;

  bool get _editing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController = TextEditingController(
      text: event?.description ?? '',
    );
    _locationController = TextEditingController(text: event?.location ?? '');
    _startAt = event?.startAt ?? nextHour;
    _endAt = event?.endAt ?? nextHour.add(const Duration(hours: 1));
    _category =
        event?.category ??
        (widget.personal
            ? CalendarEventCategory.personal
            : CalendarEventCategory.barangayEvent);
    _visibility =
        event?.visibility ??
        (widget.personal
            ? CalendarEventVisibility.private
            : widget.user.role == UserRole.barangay
            ? CalendarEventVisibility.barangay
            : CalendarEventVisibility.public);
    _targetBarangay =
        canonicalBariliBarangay(
          event?.targetBarangay.isNotEmpty == true
              ? event!.targetBarangay
              : widget.user.barangay,
        ) ??
        bariliBarangays.first;
    _allDay = event?.allDay ?? false;
    _isImportant = event?.isImportant ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBarangayOfficial = widget.user.role == UserRole.barangay;
    final categories = widget.personal
        ? const [CalendarEventCategory.personal]
        : const [
            CalendarEventCategory.barangayEvent,
            CalendarEventCategory.announcement,
            CalendarEventCategory.emergency,
          ];
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          ESugidPageHeader(
            sectionLabel: widget.personal
                ? 'My Calendar'
                : 'Community Calendar',
            title: _editing ? 'Edit event' : 'New event',
            subtitle: widget.personal
                ? 'Keep a private reminder for yourself.'
                : 'Share a clear schedule with the community.',
            icon: Icons.event_note_rounded,
            showBackButton: true,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _section(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Event title',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (value) => value?.trim().isEmpty ?? true
                            ? 'Enter an event title.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<CalendarEventCategory>(
                        initialValue: categories.contains(_category)
                            ? _category
                            : categories.first,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _category = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLength: 1200,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationController,
                        maxLength: 200,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Location (optional)',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: 'Schedule',
                    children: [
                      _dateTimeTile(
                        label: 'Starts',
                        value: _startAt,
                        onTap: () => _pickDateTime(start: true),
                      ),
                      const Divider(height: 1),
                      _dateTimeTile(
                        label: 'Ends',
                        value: _endAt,
                        onTap: () => _pickDateTime(start: false),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('All-day event'),
                        value: _allDay,
                        onChanged: (value) => setState(() => _allDay = value),
                      ),
                    ],
                  ),
                  if (!widget.personal) ...[
                    const SizedBox(height: 16),
                    _section(
                      title: 'Audience',
                      children: [
                        if (!isBarangayOfficial)
                          SegmentedButton<CalendarEventVisibility>(
                            segments: const [
                              ButtonSegment(
                                value: CalendarEventVisibility.public,
                                label: Text('All Barili'),
                                icon: Icon(Icons.public_rounded),
                              ),
                              ButtonSegment(
                                value: CalendarEventVisibility.barangay,
                                label: Text('Barangay'),
                                icon: Icon(Icons.location_on_rounded),
                              ),
                            ],
                            selected: {_visibility},
                            onSelectionChanged: (values) =>
                                setState(() => _visibility = values.first),
                          ),
                        if (_visibility ==
                            CalendarEventVisibility.barangay) ...[
                          if (!isBarangayOfficial) const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _targetBarangay,
                            decoration: const InputDecoration(
                              labelText: 'Barangay',
                              prefixIcon: Icon(Icons.place_outlined),
                            ),
                            items: bariliBarangays
                                .map(
                                  (barangay) => DropdownMenuItem(
                                    value: barangay,
                                    child: Text(barangay),
                                  ),
                                )
                                .toList(),
                            onChanged: isBarangayOfficial
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _targetBarangay = value);
                                    }
                                  },
                          ),
                        ],
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mark as important'),
                          subtitle: const Text(
                            'Adds a subtle priority marker.',
                          ),
                          value: _isImportant,
                          onChanged: (value) =>
                              setState(() => _isImportant = value),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? SizedBox.square(
                            dimension: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.surface,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_editing ? 'Save changes' : 'Create event'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({String? title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
        boxShadow: ESugidClay.raisedShadows(depth: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _dateTimeTile({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.schedule_rounded, color: context.colors.primaryGreen),
      title: Text(label),
      subtitle: Text(
        _allDay
            ? DateFormat('EEEE, MMMM d, y').format(value)
            : DateFormat('EEE, MMM d, y • h:mm a').format(value),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Future<void> _pickDateTime({required bool start}) async {
    final current = start ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: _editing
          ? DateTime.now().subtract(const Duration(days: 365))
          : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    var time = TimeOfDay.fromDateTime(current);
    if (!_allDay) {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: time,
      );
      if (selectedTime == null) return;
      time = selectedTime;
    }
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      _allDay ? 0 : time.hour,
      _allDay ? 0 : time.minute,
    );
    setState(() {
      if (start) {
        final previousDuration = _endAt.difference(_startAt);
        _startAt = value;
        _endAt = value.add(
          previousDuration.isNegative || previousDuration == Duration.zero
              ? const Duration(hours: 1)
              : previousDuration,
        );
      } else {
        _endAt = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final visibility = widget.personal
          ? CalendarEventVisibility.private
          : _visibility;
      final audienceKeys = switch (visibility) {
        CalendarEventVisibility.public => const ['municipality:barili'],
        CalendarEventVisibility.barangay => ['barangay:$_targetBarangay'],
        CalendarEventVisibility.private => ['user:${widget.user.uid}'],
      };
      final existing = widget.event;
      final event = CalendarEvent(
        id: existing?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startAt: _startAt,
        endAt: _endAt,
        allDay: _allDay,
        category: widget.personal ? CalendarEventCategory.personal : _category,
        location: _locationController.text.trim(),
        createdBy: existing?.createdBy ?? widget.user.uid,
        sourceType: existing?.sourceType ?? CalendarEventSourceType.manual,
        sourceId: existing?.sourceId ?? '',
        visibility: visibility,
        targetBarangay: visibility == CalendarEventVisibility.barangay
            ? _targetBarangay
            : '',
        targetUserIds: visibility == CalendarEventVisibility.private
            ? [widget.user.uid]
            : const [],
        audienceKeys: audienceKeys,
        status: existing?.status ?? CalendarEventStatus.scheduled,
        isImportant: widget.personal ? false : _isImportant,
        organizerName: existing?.organizerName ?? widget.user.name,
        createdAt: existing?.createdAt,
        updatedAt: existing?.updatedAt,
      );
      if (_editing) {
        await widget.service.updateEvent(event);
      } else {
        await widget.service.createEvent(event);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on CalendarValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(error.message), kind: FeedbackKind.error),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
              userFacingError(
                error,
                fallback:
                    'The event could not be saved. Check your connection and try again.',
              ),
            ),
            kind: FeedbackKind.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
