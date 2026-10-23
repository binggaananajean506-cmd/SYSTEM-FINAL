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
import '../core/validation/esugid_input_formatters.dart';
import '../core/validation/esugid_validators.dart';
import '../widgets/esugid_page_header.dart';

class OfferHelpPage extends StatefulWidget {
  const OfferHelpPage({super.key});

  @override
  State<OfferHelpPage> createState() => _OfferHelpPageState();
}

class _OfferHelpPageState extends State<OfferHelpPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _scheduledAt;

  String _helpCategory = 'Errands';
  String _contactPreference = 'Both';
  XFile? _imageFile;
  bool _isPosting = false;
  bool _isLocating = false;
  final LocationService _locationService = const LocationService();

  final List<String> _helpCategories = [
    'Errands',
    'Manual Labor',
    'Technical/IT',
    'Elder Care',
    'Pet Care',
    'Community Service',
  ];

  final List<String> _contactPreferences = ['Calls', 'Messages', 'Both'];

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ESugidPageHeader(
            sectionLabel: 'Bayanihan',
            title: 'Offer Help',
            subtitle: 'Share your skills or spare time with your community.',
            icon: Icons.volunteer_activism_outlined,
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
              child: _build3DForm(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          // Dual Shadow Depth
          BoxShadow(
            color: isDark
                ? context.colors.shadow.withValues(alpha: 0.3)
                : context.colors.brandStrong.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark
              ? context.colors.border
              : context.colors.border.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Natural Emerald Glass-morphism Effect
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.colors.surface, context.colors.surface],
                ),
              ),
            ),
          ),
          // Top light reflection
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: context.colors.highlight.withValues(alpha: 0.9),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
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
                              color: context.colors.brandStrong.withValues(alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.volunteer_activism_rounded,
                          color: context.colors.onAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'OFFER DETAILS',
                        style: GoogleFonts.outfit(
                          color: isDark ? context.colors.onAccent
                              : context.colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildLabel('Category of Service'),
                  _build3DDropdown(),
                  const SizedBox(height: 24),
                  _buildLabel('Title of Offer'),
                  _build3DField(
                    controller: _titleController,
                    hint: 'e.g. Free Computer Repair / Tutoring',
                    icon: Icons.auto_awesome_rounded,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        ESugidInputLimits.shortTitle,
                      ),
                    ],
                    validator: (value) => ESugidValidators.requiredText(
                      value,
                      label: 'Offer title',
                      minLength: 3,
                      maxLength: ESugidInputLimits.shortTitle,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Availability Schedule'),
                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(20),
                    child: IgnorePointer(
                      child: _build3DField(
                        controller: _dateController,
                        hint: 'e.g. Weekends, 8am - 5pm',
                        icon: Icons.access_time_filled_rounded,
                        validator: (v) =>
                            v!.isEmpty ? 'When are you available?' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Location / Barangay'),
                  _build3DField(
                    controller: _locationController,
                    hint: 'e.g. Poblacion and nearby areas',
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
                    suffixIcon: IconButton(
                      icon: _isLocating
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.brand,
                              ),
                            )
                          : Icon(
                              Icons.my_location_rounded,
                              color: context.colors.primaryGreen,
                            ),
                      onPressed: _isLocating ? null : _getCurrentLocation,
                      tooltip: 'Use current location',
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Description & Skills'),
                  _build3DField(
                    controller: _descriptionController,
                    hint: 'Tell your neighbors how you can help...',
                    icon: Icons.description_rounded,
                    maxLines: 4,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        ESugidInputLimits.description,
                      ),
                    ],
                    validator: (value) => ESugidValidators.optionalText(
                      value,
                      label: 'Description',
                      maxLength: ESugidInputLimits.description,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Mobile Number'),
                  _build3DField(
                    controller: _contactController,
                    hint: '0917 123 4567',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [PhilippineMobileInputFormatter()],
                    validator: ESugidValidators.philippineMobile,
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Contact Preference'),
                  Row(
                    children: _contactPreferences.map((p) {
                      final isSelected = _contactPreference == p;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _contactPreference = p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.colors.brand
                                    : context.colors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? context.colors.primaryGreen
                                      : context.colors.border,
                                  width: 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: context.colors.brandStrong
                                              .withValues(
                                            alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: Text(
                                  p,
                                  style: GoogleFonts.outfit(
                                    color: isSelected
                                        ? context.colors.onAccent
                                        : context.colors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Gallery (Optional)'),
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.colors.border,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.02,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _imageFile != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.file(
                                    File(_imageFile!.path),
                                    width: double.infinity,
                                    height: 140,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _imageFile = null;
                                    }),
                                    child: CircleAvatar(
                                      backgroundColor: context.colors.shadow
                                          .withValues(
                                        alpha: 0.5),
                                      radius: 14,
                                      child: Icon(
                                        Icons.close,
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
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: context.colors.primaryGreen,
                                  size: 30,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add a preview of your work',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: context.colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: isDark ? context.colors.onAccent : context.colors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _build3DField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
            color: isDark ? context.colors.textSecondary
                : context.colors.textSecondary,
          ),
          prefixIcon: Icon(icon, color: context.colors.primaryGreen, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: context.colors.inputBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: context.colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: context.colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: context.colors.primaryGreen, width: 1.5,
            ),
          ),
          errorStyle: GoogleFonts.outfit(fontSize: 12),
        ),
      ),
    );
  }

  Widget _build3DDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _helpCategory,
          isExpanded: true,
          dropdownColor: context.colors.surface,
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
          items: _helpCategories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (val) => setState(() => _helpCategory = val!),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.brand, context.colors.brand],
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: 0.2),
            blurRadius: 0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isPosting ? null : _submitOffer,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: context.colors.onAccent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isPosting
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'POST HELP OFFER',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _submitOffer() async {
    if (_isPosting) return;
    if (!_formKey.currentState!.validate()) return;
    final user = AuthService.currentUser;
    if (user == null) return;

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

      final job = JobItem(
        id: const Uuid().v4(),
        posterId: user.uid,
        company: user.name,
        title: _titleController.text.trim(),
        salary: '',
        type: 'Help Offer',
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        category: 'offer',
        urgency: 'Normal',
        contact: ESugidValidators.normalizePhilippineMobile(
          _contactController.text,
        )!,
        helpCategory: _helpCategory,
        dateNeeded: _dateController.text.trim(),
        scheduledAt: _scheduledAt,
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
        status: 'Active',
        contactPreference: _contactPreference,
      );

      await JobsService.addJob(job);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Help offer posted successfully!'),
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
                fallback: 'The help offer could not be posted. Try again.',
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
