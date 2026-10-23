import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../core/errors/user_facing_error.dart';
import '../core/location/location_service.dart';
import '../submission_service.dart';

/// ConcernRevisionPage displays the guided Concern Details form (Step 2 of 4)
/// allowing residents to update requested details and resubmit their concern.
class ConcernRevisionPage extends StatefulWidget {
  const ConcernRevisionPage({
    super.key,
    required this.concern,
    required this.request,
    required this.repository,
  });

  final Submission concern;
  final String request;
  final SubmissionRepository repository;

  @override
  State<ConcernRevisionPage> createState() => _ConcernRevisionPageState();
}

class _ConcernRevisionPageState extends State<ConcernRevisionPage> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.concern.title);
  late final _description = TextEditingController(
    text: widget.concern.description,
  );
  late final _location = TextEditingController(text: widget.concern.location);
  late String _incidentDateDisplay;
  late String _category;
  DateTime? _incidentDateTime;

  XFile? _photo;
  bool _removeExistingAttachment = false;
  bool _busy = false;
  bool _isLocating = false;
  String? _error;

  static const List<String> _defaultCategories = [
    'Disaster Response',
    'Roads',
    'Infrastructure',
    'Sanitation',
    'Drainage',
    'Electricity',
    'Public Safety',
    'Health',
    'School & Education',
    'Social Services',
    'Environment',
    'Agriculture',
    'Transportation',
    'Community Services',
    'Animal Services',
    'Banking & Finance',
    'Internet & Telecom',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.concern.category.isNotEmpty
        ? widget.concern.category
        : 'General';

    final rawDate = widget.concern.incidentDate?.trim() ?? '';
    if (rawDate.isNotEmpty) {
      _incidentDateDisplay = rawDate;
      _incidentDateTime = DateTime.tryParse(rawDate);
      if (_incidentDateTime != null) {
        _incidentDateDisplay = DateFormat(
          'MMM d, y · h:mm a',
        ).format(_incidentDateTime!);
      }
    } else {
      _incidentDateDisplay = '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'Roads' || 'Roads and Accessibility' => Icons.add_road_rounded,
      'Infrastructure' ||
      'Infrastructure and Public Facilities' => Icons.apartment_rounded,
      'Sanitation' ||
      'Sanitation and Waste Management' => Icons.delete_sweep_rounded,
      'Drainage' || 'Drainage and Flooding' => Icons.water_drop_rounded,
      'Electricity' ||
      'Streetlights and Electrical / Public Utilities' => Icons.bolt_rounded,
      'Public Safety' ||
      'Peace and Order / Public Safety' => Icons.shield_rounded,
      'Disaster Response' => Icons.crisis_alert_rounded,
      'Health' || 'Health & Medical' => Icons.medical_services_rounded,
      'School & Education' => Icons.school_rounded,
      'Social Services' => Icons.volunteer_activism_rounded,
      'Environment' => Icons.park_rounded,
      'Agriculture' || 'Agriculture & Livelihood' => Icons.agriculture_rounded,
      'Transportation' => Icons.directions_bus_rounded,
      'Community Services' => Icons.groups_rounded,
      'Animal Services' => Icons.pets_rounded,
      'Banking & Finance' => Icons.account_balance_rounded,
      'Internet & Telecom' => Icons.wifi_rounded,
      _ => Icons.grid_view_rounded,
    };
  }

  InputDecoration _inputDecoration(
    String? hint,
    IconData icon, {
    Widget? suffixIcon,
    bool alignPrefixTop = false,
  }) {
    return InputDecoration(
      hintText: hint,
      counterText: '',
      hintStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: context.colors.info,
        fontWeight: FontWeight.w400,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
      prefixIcon: alignPrefixTop
          ? Container(
              alignment: Alignment.topLeft,
              width: 46,
              padding: const EdgeInsets.only(left: 14, top: 14),
              child: Icon(icon, size: 21, color: context.colors.primaryGreen),
            )
          : Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(icon, size: 21, color: context.colors.primaryGreen),
            ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: context.colors.inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.border, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.primaryGreen, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.error, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildFieldLabel(
    String label, {
    bool isRequired = true,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    color: context.colors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          ?trailing,
        ],
      ),
    );
  }

  Future<void> _pickIncidentDateTime() async {
    if (_busy) return;
    final now = DateTime.now();
    final initial = _incidentDateTime ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context,
        ).copyWith(
          colorScheme: Theme.of(context).colorScheme),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: Theme.of(context,
        ).copyWith(
          colorScheme: Theme.of(context).colorScheme),
        child: child!,
      ),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      _incidentDateTime = combined;
      _incidentDateDisplay = DateFormat('MMM d, y · h:mm a').format(combined);
    });
  }

  Future<void> _getCurrentLocation() async {
    if (_isLocating || _busy) return;
    setState(() => _isLocating = true);
    try {
      const service = LocationService();
      final address = await service.currentAddress();
      if (!mounted) return;
      setState(() => _location.text = address);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
              e is LocationException
                  ? e.message
                  : 'Could not obtain location. Please enter manually.',
            ),
            kind: FeedbackKind.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (mounted && photo != null) {
        setState(() {
          _photo = photo;
          _removeExistingAttachment = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the photo. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resubmit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var url = _removeExistingAttachment
          ? ''
          : (widget.concern.attachmentUrl ?? '');
      var path = _removeExistingAttachment
          ? ''
          : (widget.concern.attachmentStoragePath ?? '');
      final photo = _photo;
      if (photo != null) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.concern.userId ?? 'resident';
        path =
            'concerns/$currentUid/${widget.concern.id}/revision-${DateTime.now().microsecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref(path);
        await ref.putData(
          await photo.readAsBytes(),
          SettableMetadata(contentType: photo.mimeType ?? 'image/jpeg'),
        );
        url = await ref.getDownloadURL();
      }
      final saved = await widget.repository.resubmitConcern(
        widget.concern.copyWith(
          title: _title.text.trim(),
          description: _description.text.trim(),
          location: _location.text.trim(),
          category: _category,
          incidentDate: _incidentDateDisplay.trim(),
          attachmentUrl: url,
          attachmentStoragePath: path,
        ),
      );
      if (!mounted) return;
      setState(() => _busy = false);

      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text(
            'Concern resubmitted successfully!',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600),
          ),
          kind: FeedbackKind.success,
        ),
      );
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (error is FirebaseFunctionsException) {
          if (error.code == 'not-found' || error.message == 'NOT_FOUND') {
            _error = 'Concern service was not found or the report no longer exists. Please try again.';
          } else {
            _error = userFacingError(
              error,
              fallback: 'Unable to resubmit. Please try again.',
            );
          }
        } else {
          _error = 'Unable to resubmit. Check your connection and try again.';
        }
      });
    }
  }

  Widget _buildColoredHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.colors.brandStrong, context.colors.brandStrong],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Navigation Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center Title & Subtitle matching Picture 2
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'File a Concern',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: context.colors.onAccent,
                          fontSize: 17.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Step 2 of 4 · Concern Details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: context.colors.onAccent.withValues(alpha: 0.85,
                          ),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  // Left: Circular Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _busy ? null : () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colors.surface.withValues(alpha: 0.16,
                            ),
                            border: Border.all(
                              color: context.colors.border.withValues(alpha: 0.25,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.arrow_back_rounded,
                              size: 19,
                              color: context.colors.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Right: "Save Draft" Pill Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showAppSnackBar(
                            AppSnackBar(
                              content: Text('Edits saved locally.'),
                              kind: FeedbackKind.success,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5.5,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.surface.withValues(alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: context.colors.border.withValues(alpha: 0.35,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bookmark_border_rounded,
                                size: 14,
                                color: context.colors.onAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Save Draft',
                                style: GoogleFonts.outfit(
                                  color: context.colors.onAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Stepper Indicator: Step 1 checked, Step 2 active, Steps 3-4 hollow
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Step 1: Checked
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.brand,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: context.colors.onAccent,
                    ),
                  ),
                ),
                // Connector 1-2
                Container(
                  width: 28,
                  height: 2.2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1.5),
                    color: context.colors.brand,
                  ),
                ),
                // Step 2: Active with center dot and glow
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.brand,
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.5,
                        ),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.surface,
                      ),
                    ),
                  ),
                ),
                // Connector 2-3
                Container(
                  width: 28,
                  height: 2.2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1.5),
                    color: context.colors.surface.withValues(alpha: 0.22),
                  ),
                ),
                // Step 3: Hollow
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.38),
                      width: 1.5,
                    ),
                  ),
                ),
                // Connector 3-4
                Container(
                  width: 28,
                  height: 2.2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1.5),
                    color: context.colors.surface.withValues(alpha: 0.22),
                  ),
                ),
                // Step 4: Hollow
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.38),
                      width: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _buildPhotoEvidenceCard() {
    final existingUrl = widget.concern.attachmentUrl ?? '';
    final hasExistingPhoto =
        !_removeExistingAttachment && existingUrl.isNotEmpty;
    final hasNewPhoto = _photo != null;

    if (hasNewPhoto || hasExistingPhoto) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: context.colors.infoSurface,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasNewPhoto
                  ? Center(
                      child: Icon(
                        Icons.photo_outlined,
                        color: context.colors.primaryGreen,
                        size: 28,
                      ),
                    )
                  : Image.network(
                      existingUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: context.colors.info,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasNewPhoto ? _photo!.name : 'Photo attached',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasNewPhoto
                        ? 'Ready to upload on resubmit'
                        : 'Existing attached photo will be kept',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: context.colors.brand,
              tooltip: 'Replace photo',
              onPressed: _busy ? null : _pickPhoto,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: context.colors.errorSolid,
              tooltip: 'Remove photo',
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _photo = null;
                        _removeExistingAttachment = true;
                      });
                    },
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        painter: _DashedRoundedBorderPainter(
          color: context.colors.surfaceAlt,
          radius: 16,
          strokeWidth: 1.3,
          dashLength: 6.0,
          dashGap: 4.5,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _busy ? null : _pickPhoto,
            borderRadius: BorderRadius.circular(16),
            splashColor: context.colors.brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.surfaceAlt,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          size: 26,
                          color: context.colors.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to upload',
                      style: GoogleFonts.outfit(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'JPG, PNG, or PDF',
                      style: GoogleFonts.poppins(
                        color: context.colors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '(Max 5MB each)',
                      style: GoogleFonts.poppins(
                        color: context.colors.info,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      if (_category.isNotEmpty) _category,
      ..._defaultCategories,
    }.toList();

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: context.colors.brandStrong,
        body: Column(
          children: [
            _buildColoredHeader(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Expanded(
                      child: Form(
                        key: _form,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Requested info notice banner from office
                              if (widget.request.trim().isNotEmpty) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.colors.warningSurface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: context.colors.border,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: context.colors.warningSolid,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.info_outline_rounded,
                                          color: context.colors.onBrandMuted,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'More information is needed',
                                              style: GoogleFonts.outfit(
                                                color: context.colors.error,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Additional information requested: ${widget.request}',
                                              style: GoogleFonts.poppins(
                                                color: context.colors.error,
                                                fontSize: 11.5,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Concern Type
                              _buildFieldLabel('Concern Type'),
                              DropdownButtonFormField<String>(
                                initialValue: categories.contains(_category)
                                    ? _category
                                    : categories.first,
                                isExpanded: true,
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: context.colors.textSecondary,
                                  size: 22,
                                ),
                                decoration: _inputDecoration(
                                  'Select concern type',
                                  _categoryIcon(_category),
                                ),
                                items: categories
                                    .map(
                                      (cat) => DropdownMenuItem(
                                        value: cat,
                                        child: Text(
                                          cat,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13.5,
                                            color: context.colors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _busy
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() => _category = value);
                                        }
                                      },
                              ),
                              const SizedBox(height: 12),

                              // Title (TextFormField #0 for tests)
                              _buildFieldLabel('Title'),
                              TextFormField(
                                controller: _title,
                                enabled: !_busy,
                                maxLength: 100,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  color: context.colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: _inputDecoration(
                                  'Enter a short title for your concern...',
                                  Icons.title_rounded,
                                ),
                                validator: (value) =>
                                    (value ?? '').trim().length < 3
                                    ? 'Enter at least 3 characters.'
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Description (TextFormField #1 for tests)
                              _buildFieldLabel('Description'),
                              TextFormField(
                                controller: _description,
                                enabled: !_busy,
                                maxLines: 4,
                                maxLength: 500,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  color: context.colors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                buildCounter: (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => Text(
                                  '$currentLength/${maxLength ?? 500}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    color: context.colors.info,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                decoration: _inputDecoration(
                                  'Provide a clear and detailed description\nof your concern...',
                                  Icons.article_outlined,
                                  alignPrefixTop: true,
                                ),
                                validator: (value) =>
                                    (value ?? '').trim().length < 10
                                    ? 'Enter at least 10 characters.'
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Incident Date & Time
                              _buildFieldLabel(
                                'Incident Date & Time',
                                trailing: _incidentDateDisplay.isNotEmpty
                                    ? InkWell(
                                        onTap: _busy
                                            ? null
                                            : () => setState(
                                                () => _incidentDateDisplay = '',
                                              ),
                                        child: Text(
                                          'Clear',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.error,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              InkWell(
                                onTap: _pickIncidentDateTime,
                                borderRadius: BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration: _inputDecoration(
                                    'Select date and time of incident',
                                    Icons.calendar_month_rounded,
                                    suffixIcon: Padding(
                                      padding: EdgeInsets.only(right: 14),
                                      child: Icon(
                                        Icons.access_time_rounded,
                                        size: 19,
                                        color: context.colors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _incidentDateDisplay.isEmpty
                                        ? 'Select date and time of incident'
                                        : _incidentDateDisplay,
                                    style: GoogleFonts.outfit(
                                      color: _incidentDateDisplay.isEmpty
                                          ? context.colors.info
                                          : context.colors.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: _incidentDateDisplay.isEmpty
                                          ? FontWeight.w400
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Specific Location (TextFormField #2 for tests)
                              _buildFieldLabel(
                                'Specific Location',
                                trailing: InkWell(
                                  onTap: _isLocating
                                      ? null
                                      : _getCurrentLocation,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isLocating)
                                          SizedBox(
                                            width: 13,
                                            height: 13,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: context.colors.brand,
                                            ),
                                          )
                                        else
                                          Icon(
                                            Icons.near_me_rounded,
                                            size: 15,
                                            color: context.colors.primaryGreen,
                                          ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _isLocating
                                              ? 'Locating...'
                                              : 'Use My Location',
                                          style: GoogleFonts.outfit(
                                            color: context.colors.primaryGreen,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              TextFormField(
                                controller: _location,
                                enabled: !_busy,
                                maxLength: 200,
                                textCapitalization: TextCapitalization.words,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  color: context.colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: _inputDecoration(
                                  'Enter address, street, or landmark...',
                                  Icons.location_on_rounded,
                                ),
                                validator: (value) =>
                                    (value ?? '').trim().length < 3
                                    ? 'Enter at least 3 characters.'
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Photo/s Evidence
                              _buildFieldLabel(
                                'Photo/s Evidence',
                                isRequired: false,
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Optional',
                                    style: GoogleFonts.outfit(
                                      color: context.colors.primaryGreen,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              _buildPhotoEvidenceCard(),

                              // Error notice
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.colors.errorSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: context.colors.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        color: context.colors.error,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: GoogleFonts.poppins(
                                            color: context.colors.error,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom Action Bar: "Resubmit Concern" matching Picture 2
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        10,
                        20,
                        14 + MediaQuery.of(context).padding.bottom,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        border: Border(
                          top: BorderSide(color: context.colors.border, width: 1,
                          ),
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 580),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy ? null : _resubmit,
                              style: FilledButton.styleFrom(
                                backgroundColor: context.colors.brand,
                                foregroundColor: context.colors.onAccent,
                                disabledBackgroundColor:
                                    context.colors.disabledBackground,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                                shadowColor: context.colors.brand.withValues(alpha: 0.35,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_busy) ...[
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(
                                    _busy ? 'Saving…' : 'Resubmit Concern',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  if (!_busy) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.3,
    this.dashLength = 6.0,
    this.dashGap = 4.5,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + dashLength).clamp(0, metric.length),
          ),
          paint,
        );
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.dashGap != dashGap;
}
