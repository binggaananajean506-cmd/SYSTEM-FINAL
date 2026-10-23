import 'dart:io';
import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../auth_service.dart';
import '../jobs_service.dart';
import '../core/location/location_service.dart';
import '../core/errors/user_facing_error.dart';
import '../core/validation/esugid_validators.dart';
import '../widgets/esugid_page_header.dart';
import '../app_motion.dart';

class RequestHelpPage extends StatefulWidget {
  final JobItem? existingJob;

  const RequestHelpPage({super.key, this.existingJob});

  @override
  State<RequestHelpPage> createState() => _RequestHelpPageState();
}

class _RequestHelpPageState extends State<RequestHelpPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _scheduledAt;

  String _helpCategory = 'Errands';
  String _urgency = 'Normal';
  static const _contactPreference = 'Both';
  int _helpersNeeded = 1;
  bool _isCustomHelpers = false;
  final _customHelpersController = TextEditingController();
  final _customCategoryController = TextEditingController();
  XFile? _imageFile;
  String? _existingImageUrl;
  bool _isPosting = false;
  bool _isLocating = false;
  final LocationService _locationService = const LocationService();

  final List<String> _helpCategories = [
    'Errands',
    'Repairs',
    'Farming',
    'Hauling',
    'Care',
    'Animals',
    'Tech',
    'Other',
  ];

  final List<String> _urgencyLevels = ['Low', 'Normal', 'High', 'Urgent'];

  @override
  void initState() {
    super.initState();
    final job = widget.existingJob;
    if (job != null) {
      _titleController.text = job.title;
      _locationController.text = job.location;
      _descriptionController.text = job.description;
      _dateController.text = job.dateNeeded;
      _scheduledAt = job.scheduledAt;
      _urgency = _urgencyLevels.contains(job.urgency) ? job.urgency : 'Normal';
      _existingImageUrl = job.imageUrl;

      if (_helpCategories.contains(job.helpCategory)) {
        _helpCategory = job.helpCategory;
      } else {
        _helpCategory = 'Other';
        _customCategoryController.text = job.helpCategory;
      }

      if (job.helpersNeeded > 5) {
        _isCustomHelpers = true;
        _customHelpersController.text = job.helpersNeeded.toString();
      } else {
        _helpersNeeded = job.helpersNeeded;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _customHelpersController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (image != null) {
      final imageLength = await image.length();
      final supportedType =
          ESugidValidators.isSupportedImageMimeType(image.mimeType) ||
          ESugidValidators.isSupportedImageFileName(image.path);
      if (!supportedType || imageLength > ESugidInputLimits.imageBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
              supportedType
                  ? 'Photo must be 8 MB or smaller.'
                  : 'Use a JPG, PNG, or WebP photo.',
            ),
            kind: FeedbackKind.warning,
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _imageFile = image);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context,
          ).copyWith(
            colorScheme: Theme.of(context).colorScheme),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (!mounted) return;
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        if (!mounted) return;
        final dateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );
        if (!dateTime.isAfter(DateTime.now())) {
          ScaffoldMessenger.of(context).showAppSnackBar(
            AppSnackBar(
              content: Text('Please choose a future date and time.'),
              kind: FeedbackKind.warning,
            ),
          );
          return;
        }
        setState(() {
          _scheduledAt = dateTime;
          _dateController.text = DateFormat(
            'MMM dd, yyyy - hh:mm a',
          ).format(dateTime);
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final location = await _locationService.currentAddress();
      if (!mounted) return;
      setState(() => _locationController.text = location);
    } on LocationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(error.message), kind: FeedbackKind.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _build3DHeader(context),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: _build3DForm(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DHeader(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.brandStrong,
            context.colors.brandStrong,
            context.colors.brand,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // 1. Top Specular Crystal Rim Light (simulating curved glass refraction)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.colors.surface.withValues(alpha: 0.0),
                    context.colors.surface.withValues(alpha: 0.45),
                    context.colors.surface.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // 2. Ambient Volumetric 3D Light Orbs matching Home Dashboard
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.warningSolid.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.brand.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 3. Embossed Municipal Watermark
          Positioned(
            top: -15,
            right: 15,
            child: Opacity(
              opacity: 0.06,
              child: Image.asset(
                'assets/images/resident_dashboard/pinakafinal.png',
                width: 170,
                color: context.colors.surface,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 14),
                child: Row(
                  children: [
                    // 3D Glass Back Button
                    ESugidPressable(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              context.colors.surface.withValues(alpha: 0.22),
                              context.colors.surface.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.colors.border.withValues(alpha: 0.42,
                            ),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.shadow.withValues(alpha: 0.22,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                            BoxShadow(
                              color: context.colors.brandStrong.withValues(alpha: 0.18,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: context.colors.onAccent,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Badge Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.surface.withValues(alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: context.colors.border.withValues(alpha: 0.5,
                                ),
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.colors.brand,
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.brandStrong,
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  widget.existingJob != null
                                      ? 'EDIT BAYANIHAN'
                                      : 'BARILI BAYANIHAN',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                    color: context.colors.onBrandMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.existingJob != null
                                ? 'Edit Request'
                                : 'Request Help',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 22.5,
                              fontWeight: FontWeight.w900,
                              color: context.colors.onAccent,
                              letterSpacing: -0.3,
                              shadows: [
                                Shadow(
                                  color: context.colors.textPrimary,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3D Glass Handshake Emblem
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.surface.withValues(alpha: 0.22),
                            context.colors.surface.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.42),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.20,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(alpha: 0.18,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.handshake_rounded,
                          color: context.colors.onBrandMuted,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const ESugidBodyCrown(height: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build3DForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? context.colors.surface : context.colors.surface;
    final cardBorder = context.colors.border;
    final bannerBg1 = context.colors.surfaceAlt;
    final bannerBg2 = context.colors.surfaceAlt;
    final bannerBorder = isDark ? context.colors.primaryGreen
        : context.colors.primaryGreen.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          // Deep tactile ambient shadow
          BoxShadow(
            color: isDark ? context.colors.brandStrong.withValues(alpha: 0.4) : context.colors.brandStrong.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Natural pearl / slate gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [context.colors.surface, context.colors.surface],
                ),
              ),
            ),
          ),
          // Top light reflection / Bevel Highlight
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? context.colors.brandStrong
                                : context.colors.highlight).withValues(alpha: isDark ? 0.3 : 0.95),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3D Hero Community Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [bannerBg1, bannerBg2],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: bannerBorder,
                        width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: isDark ? 0.12 : 0.08,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // 3D Embossed Icon Medallion
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.colors.brand,
                                context.colors.brand,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.35,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: context.colors.highlight.withValues(alpha: 0.4,
                                ),
                                offset: const Offset(0, -1),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.volunteer_activism_rounded,
                              color: context.colors.onAccent,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Need a Hand?',
                                    style: GoogleFonts.outfit(
                                      color: context.colors.textPrimary,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.colors.brand.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'COMMUNITY',
                                      style: GoogleFonts.outfit(
                                        color: context.colors.textPrimary,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tell your neighbors what you need help with.',
                                style: GoogleFonts.outfit(
                                  color: context.colors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Category
                  _buildLabel('Category', icon: Icons.category_outlined),
                  _build3DDropdown(),

                  if (_helpCategory == 'Other') ...[
                    const SizedBox(height: 14),
                    _buildLabel(
                      'What kind of help?',
                      icon: Icons.edit_outlined,
                    ),
                    _build3DField(
                      controller: _customCategoryController,
                      hint: 'e.g. Cooking, Gardening, Tutoring...',
                      icon: Icons.edit_note_rounded,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      validator: (value) {
                        if (_helpCategory == 'Other' &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please type what kind of help you need';
                        }
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 22),

                  // What do you need help with?
                  _buildLabel(
                    'What do you need help with?',
                    icon: Icons.title_rounded,
                  ),
                  _build3DField(
                    controller: _titleController,
                    hint: 'e.g. Need help carrying heavy boxes',
                    icon: Icons.edit_note_rounded,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        ESugidInputLimits.shortTitle,
                      ),
                    ],
                    validator: (value) => ESugidValidators.requiredText(
                      value,
                      label: 'title',
                      minLength: 3,
                      maxLength: ESugidInputLimits.shortTitle,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // How many people do you need?
                  _buildLabel(
                    'How many people do you need?',
                    icon: Icons.groups_outlined,
                  ),
                  _build3DHelpersDropdown(),

                  if (_isCustomHelpers) ...[
                    const SizedBox(height: 14),
                    _buildLabel('How many people?', icon: Icons.pin_outlined),
                    _build3DField(
                      controller: _customHelpersController,
                      hint: 'Enter number of people (1 to 10)',
                      icon: Icons.numbers_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      validator: (value) {
                        if (!_isCustomHelpers) return null;
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter how many people you need';
                        }
                        final parsed = int.tryParse(value.trim());
                        if (parsed == null || parsed < 1) {
                          return 'Must be at least 1 person';
                        }
                        if (parsed > 10) {
                          return 'Maximum 10 people allowed';
                        }
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 22),

                  // How soon do you need this?
                  _buildLabel(
                    'How soon do you need this?',
                    icon: Icons.speed_rounded,
                  ),
                  _build3DUrgencySelector(),

                  const SizedBox(height: 22),

                  // When do you need it?
                  _buildLabel(
                    'When do you need it?',
                    icon: Icons.event_available_outlined,
                  ),
                  ESugidPressable(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _scheduledAt != null
                              ? context.colors.primaryGreen.withValues(alpha: 0.6,
                                )
                              : (isDark ? context.colors.primaryGreen
                                    : context.colors.border),
                          width: _scheduledAt != null ? 1.5 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.03,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: context.colors.brand.withValues(alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.calendar_month_rounded,
                              color: context.colors.primaryGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _scheduledAt != null
                                      ? DateFormat(
                                          'EEEE, MMM dd, yyyy',
                                        ).format(_scheduledAt!)
                                      : 'Choose date and time',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: _scheduledAt != null
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _scheduledAt != null
                                        ? (isDark ? context.colors.onAccent
                                              : context.colors.textPrimary)
                                        : (isDark ? context.colors.textSecondary
                                              : context.colors.textSecondary),
                                  ),
                                ),
                                if (_scheduledAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('hh:mm a').format(_scheduledAt!),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: context.colors.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 13,
                                  color: context.colors.primaryGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _scheduledAt != null ? 'CHANGE' : 'SET TIME',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isDark ? context.colors.primaryGreen
                                        : context.colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Where is this?
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel(
                        'Where is this?',
                        icon: Icons.pin_drop_outlined,
                      ),
                      // 3D Glass Location Pill
                      ESugidPressable(
                        onTap: _isLocating ? null : _getCurrentLocation,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.colors.surfaceAlt,
                                context.colors.surfaceAlt,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: context.colors.border,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.15,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isLocating)
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.colors.brand,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.my_location_rounded,
                                  size: 13,
                                  color: context.colors.primaryGreen,
                                ),
                              const SizedBox(width: 5),
                              Text(
                                'USE MY LOCATION',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: isDark ? context.colors.primaryGreen
                                      : context.colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  _build3DField(
                    controller: _locationController,
                    hint: 'e.g. Sitio Mahogany, Brgy. Poblacion',
                    icon: Icons.location_on_rounded,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        ESugidInputLimits.address,
                      ),
                    ],
                    validator: (value) => ESugidValidators.requiredText(
                      value,
                      label: 'Location',
                      minLength: 3,
                      maxLength: ESugidInputLimits.address,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // More Details (Optional)
                  _buildLabel(
                    'More Details (Optional)',
                    icon: Icons.notes_rounded,
                  ),
                  _build3DField(
                    controller: _descriptionController,
                    hint: 'Write any helpful details or instructions here...',
                    icon: Icons.subject_rounded,
                    maxLines: 4,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        ESugidInputLimits.description,
                      ),
                    ],
                    validator: (value) => ESugidValidators.optionalText(
                      value,
                      label: 'Details',
                      maxLength: ESugidInputLimits.description,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Add a Photo (Optional)
                  _buildLabel(
                    'Add a Photo (Optional)',
                    icon: Icons.add_photo_alternate_outlined,
                  ),
                  _build3DPhotoUploader(),

                  const SizedBox(height: 36),

                  // Full-Width 3D Submit Button
                  _build3DSubmitButton(),

                  const SizedBox(height: 16),

                  // Trust Badges Footer
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _buildTrustPill('🛡️ Verified Neighbors'),
                        _buildTrustPill('🤝 100% Free Service'),
                        _buildTrustPill('⚡ Fast Neighbor Alerts'),
                      ],
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

  Widget _buildTrustPill(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _build3DUrgencySelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: _urgencyLevels.map((u) {
        final isSelected = _urgency == u;
        final uColor = _getUrgencyColor(u);
        final uIcon = _getUrgencyIcon(u);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ESugidPressable(
              onTap: () => setState(() => _urgency = u),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: 38,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.solid(uColor),
                            context.colors.solid(_getUrgencyDarkColor(u)),
                          ],
                        )
                      : null,
                  color: isSelected ? null : (context.colors.surface),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? context.colors.border.withValues(alpha: 0.45)
                        : (context.colors.border),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? uColor.withValues(alpha: 0.32)
                          : context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.035,
                            ),
                      blurRadius: isSelected ? 8 : 4,
                      offset: Offset(0, isSelected ? 3 : 1.5),
                    ),
                  ],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            uIcon,
                            size: 14,
                            color: isSelected ? context.colors.onAccent
                                : uColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            u,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? context.colors.onAccent
                                  : (context.colors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getUrgencyIcon(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'urgent':
        return Icons.bolt_rounded;
      case 'high':
        return Icons.priority_high_rounded;
      case 'low':
        return Icons.spa_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  Color _getUrgencyDarkColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'urgent':
        return context.colors.error;
      case 'high':
        return context.colors.warning;
      case 'low':
        return context.colors.info;
      default:
        return context.colors.textPrimary;
    }
  }

  Widget _build3DPhotoUploader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ESugidPressable(
      onTap: _pickImage,
      child: Container(
        height: 165,
        width: double.infinity,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: (_imageFile != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty))
                ? context.colors.primaryGreen.withValues(alpha: 0.6)
                : (isDark ? context.colors.primaryGreen
                      : context.colors.border),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _imageFile != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(_imageFile!.path),
                      width: double.infinity,
                      height: 165,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _imageFile = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.colors.shadow.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(color: context.colors.border, width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: context.colors.onAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          _existingImageUrl!,
                          width: double.infinity,
                          height: 165,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                            child: Icon(Icons.broken_image_rounded, size: 36),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _existingImageUrl = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: context.colors.shadow.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                              border: Border.all(color: context.colors.border, width: 1.5,
                          ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: context.colors.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 3D Floating Camera Medallion
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.brand.withValues(alpha: 0.15),
                          context.colors.brand.withValues(alpha: 0.08),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.12,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add_a_photo_rounded,
                        color: context.colors.primaryGreen,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to take or choose a photo',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'A photo helps neighbors understand faster',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _build3DHelpersDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? context.colors.primaryGreen : context.colors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          dropdownColor: context.colors.surface,
          value: _isCustomHelpers ? -1 : _helpersNeeded,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.colors.primaryGreen,
          ),
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: isDark ? context.colors.onAccent
                : context.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          items: [
            ...List.generate(
              10,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: context.colors.primaryGreen.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 10),
                    Text(index == 0 ? '1 person' : '${index + 1} people'),
                  ],
                ),
              ),
            ),
            DropdownMenuItem(
              value: -1,
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: context.colors.primaryGreen.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 10),
                  const Text('Custom number...'),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            if (value == -1) {
              setState(() {
                _isCustomHelpers = true;
              });
            } else {
              setState(() {
                _isCustomHelpers = false;
                _helpersNeeded = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _build3DSubmitButton() {
    return ESugidPressable(
      onTap: _isPosting ? null : _submitRequest,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.brand,
              context.colors.brand,
              context.colors.brandStrong,
            ],
            stops: [0.0, 0.6, 1.0],
          ),
          boxShadow: [
            // Deep volumetric glow
            BoxShadow(
              color: context.colors.brandStrong.withValues(alpha: 0.42),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            // Specular top light rim
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: 0.35),
              offset: const Offset(0, -1.5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: _isPosting
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: context.colors.surface,
                    strokeWidth: 2.8,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.existingJob != null
                          ? Icons.save_rounded
                          : Icons.send_rounded,
                      size: 20,
                      color: context.colors.onAccent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.existingJob != null
                          ? 'SAVE CHANGES'
                          : 'ASK FOR HELP',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 15.5,
                        color: context.colors.onAccent,
                        shadows: [
                          Shadow(
                            color: context.colors.textPrimary,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _build3DDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? context.colors.primaryGreen : context.colors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: context.colors.surface,
          value: _helpCategory,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.colors.primaryGreen,
          ),
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: isDark ? context.colors.onAccent
                : context.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          items: _helpCategories.map((c) {
            final icon = _getCategoryIcon(c);
            return DropdownMenuItem(
              value: c,
              child: Row(
                children: [
                  Icon(icon, size: 18, color: context.colors.primaryGreen),
                  const SizedBox(width: 10),
                  Text(c),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _helpCategory = val!),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Errands':
        return Icons.directions_run_rounded;
      case 'Repairs':
        return Icons.handyman_rounded;
      case 'Farming':
        return Icons.eco_rounded;
      case 'Hauling':
        return Icons.local_shipping_rounded;
      case 'Care':
        return Icons.volunteer_activism_rounded;
      case 'Animals':
        return Icons.pets_rounded;
      case 'Tech':
        return Icons.devices_rounded;
      case 'Other':
        return Icons.more_horiz_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  Widget _build3DField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        style: GoogleFonts.outfit(
          fontSize: 14,
          color: isDark ? context.colors.textPrimary
              : context.colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(
            fontSize: 14,
            color: (context.colors.textSecondary),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(icon, color: context.colors.primaryGreen, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          filled: true,
          fillColor: context.colors.inputBackground,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines > 1 ? 16 : 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: isDark ? context.colors.primaryGreen
                  : context.colors.border,
              width: 1.2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: isDark ? context.colors.primaryGreen
                  : context.colors.border,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: context.colors.primaryGreen, width: 1.8,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: context.colors.error, width: 1.2),
          ),
          errorStyle: GoogleFonts.outfit(fontSize: 12),
        ),
      ),
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'urgent':
        return context.colors.error;
      case 'high':
        return context.colors.warning;
      case 'low':
        return context.colors.info;
      default:
        return context.colors.primaryGreen;
    }
  }

  Widget _buildLabel(String text, {IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: isDark ? context.colors.textSecondary
              : context.colors.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_isPosting) return;
    if (!_formKey.currentState!.validate()) return;
    final user = AuthService.currentUser;
    if (user == null) return;
    final contact = ESugidValidators.normalizePhilippineMobile(
      user.contactNumber ?? '',
    );
    final isEditing = widget.existingJob != null;
    String? validationError;
    if (contact == null) {
      validationError =
          'Please add a valid mobile number in your profile before posting.';
    } else if (_scheduledAt == null) {
      validationError = 'Please choose when you need help.';
    } else if (!isEditing && !_scheduledAt!.isAfter(DateTime.now())) {
      validationError =
          'Please choose a future date and time for your request.';
    }
    if (validationError != null) {
      ScaffoldMessenger.of(
        context).showAppSnackBar(
        AppSnackBar(content: Text(validationError), kind: FeedbackKind.error),
      );
      return;
    }

    setState(() => _isPosting = true);
    Reference? uploadedReference;
    try {
      String? imageUrl;
      if (_imageFile != null) {
        await firebase_auth.FirebaseAuth.instance.currentUser?.getIdToken(true);
        final ref = FirebaseStorage.instance.ref().child(
          'job_images/${user.uid}/${const Uuid().v4()}.jpg',
        );
        uploadedReference = ref;
        await ref.putFile(
          File(_imageFile!.path),
          SettableMetadata(contentType: _imageFile!.mimeType ?? 'image/jpeg'),
        );
        imageUrl = await ref.getDownloadURL();
      }

      final finalImageUrl = imageUrl ?? (isEditing ? _existingImageUrl : null);

      final resolvedCategory = _helpCategory == 'Other'
          ? (_customCategoryController.text.trim().isNotEmpty
                ? _customCategoryController.text.trim()
                : 'Other')
          : _helpCategory;

      final job = JobItem(
        id: isEditing ? widget.existingJob!.id : const Uuid().v4(),
        posterId: isEditing ? widget.existingJob!.posterId : user.uid,
        company: user.name,
        title: _titleController.text.trim(),
        salary: isEditing ? widget.existingJob!.salary : '',
        type: isEditing ? widget.existingJob!.type : 'Help Request',
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        category: isEditing ? widget.existingJob!.category : 'request',
        urgency: _urgency,
        contact: contact!,
        helpCategory: resolvedCategory,
        dateNeeded: _dateController.text.trim(),
        scheduledAt: _scheduledAt,
        createdAt: isEditing ? widget.existingJob!.createdAt : DateTime.now(),
        imageUrl: finalImageUrl,
        status: isEditing ? widget.existingJob!.status : 'Active',
        contactPreference: _contactPreference,
        helpersNeeded: _isCustomHelpers
            ? int.parse(_customHelpersController.text.trim())
            : _helpersNeeded,
        acceptedHelperCount:
            isEditing ? widget.existingJob!.acceptedHelperCount : 0,
      );

      if (isEditing) {
        await JobsService.updateJob(job);
      } else {
        await JobsService.addJob(job);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
              isEditing ? 'Help request updated!' : 'Help request posted!',
            ),
            kind: FeedbackKind.success,
          ),
        );
      }
    } catch (e) {
      try {
        await uploadedReference?.delete();
      } catch (_) {
        // The original submission failure is more useful to the resident.
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'The help request could not be posted. Try again.',
              ),
            ),
            kind: FeedbackKind.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }
}
