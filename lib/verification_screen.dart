import 'dart:io';

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'core/errors/user_facing_error.dart';
import 'core/validation/esugid_validators.dart';
import 'features/verification/data/resident_verification_service.dart';
import 'features/verification/domain/residency_verification.dart';
import 'widgets/esugid_page_header.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _otherDocumentController =
      TextEditingController();
  String? _selectedDocType;
  File? _frontImage;
  File? _backImage;
  String? _frontError;
  String? _backError;
  bool _isLoading = false;
  DateTime? _manualBirthDate;

  User? get _user => AuthService.currentUser;
  bool get _isResident => _user?.role == UserRole.resident;
  bool get _isOtherProof =>
      _selectedDocType == 'Other Proof' ||
      _selectedDocType == 'Other Proof of Address';
  bool get _hasDocumentDescription =>
      !_isOtherProof || _otherDocumentController.text.trim().length >= 3;

  bool get _isTwoSidedId =>
      _selectedDocType == 'National ID' ||
      _selectedDocType == "Driver's License" ||
      _selectedDocType == 'Postal ID';

  DateTime? get _userBirthDate => parseResidentBirthDate(_user?.birthDate);
  DateTime? get _effectiveBirthDate => _userBirthDate ?? _manualBirthDate;

  String get _birthDateDisplay {
    final birthDate = _effectiveBirthDate;
    if (birthDate != null) return DateFormat('MMMM d, yyyy').format(birthDate);
    final raw = _user?.birthDate?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return 'Not provided';
  }

  String get _ageDisplay {
    final birthDate = _effectiveBirthDate;
    return birthDate == null
        ? 'Not available'
        : '${residentAge(birthDate)} years old';
  }

  bool get _isAdditionalDocumentFlow =>
      _isResident &&
      verificationRequiresAdditionalDocument(
        _user?.verificationStatus ?? VerificationStatus.notVerified,
      );
  bool get _needsAttention =>
      _isAdditionalDocumentFlow ||
      _user?.verificationStatus == VerificationStatus.rejected;
  bool get _isWaitingForReview =>
      _isResident &&
      verificationIsWaitingForReview(
        _user?.verificationStatus ?? VerificationStatus.notVerified,
      );

  bool get _registeredIdentityComplete {
    final user = _user;
    return user != null &&
        user.name.trim().isNotEmpty &&
        (user.barangay?.trim().isNotEmpty ?? false) &&
        (user.barangayId?.trim().isNotEmpty ?? false);
  }

  bool get _isFormReady {
    final birthDate = _effectiveBirthDate;
    if (!_registeredIdentityComplete ||
        birthDate == null ||
        birthDate.isAfter(DateTime.now()) ||
        _selectedDocType == null ||
        !_hasDocumentDescription ||
        _frontImage == null) {
      return false;
    }
    if (_isTwoSidedId && _backImage == null) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    final user = _user;
    if (_manualBirthDate == null && user != null) {
      final cached = AuthService.getCachedBirthDateFor(
        uid: user.uid,
        email: user.email,
        name: user.name,
      );
      if (cached != null && cached.isNotEmpty) {
        final parsed = parseResidentBirthDate(cached);
        if (parsed != null) {
          _manualBirthDate = parsed;
        }
      }
    }
    _resolveStoredBirthDate();
    AuthService.refreshCurrentUserFromServer().then((_) {
      _resolveStoredBirthDate();
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  Future<void> _resolveStoredBirthDate() async {
    if (_effectiveBirthDate != null) return;
    final user = _user;
    final recovered = await AuthService.recoverCachedBirthDate(
      uid: user?.uid,
      email: user?.email,
      name: user?.name,
    );
    if (recovered != null && recovered.isNotEmpty && mounted) {
      final parsed = parseResidentBirthDate(recovered);
      if (parsed != null) {
        setState(() {
          _manualBirthDate = parsed;
        });
        if (AuthService.currentUser != null &&
            (AuthService.currentUser!.birthDate == null ||
                AuthService.currentUser!.birthDate!.isEmpty)) {
          AuthService.currentUser = AuthService.currentUser!.copyWith(
            birthDate: storedBirthDateValue(parsed),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _otherDocumentController.dispose();
    super.dispose();
  }

  void _selectDocument(String documentType) {
    if (_isLoading || documentType == _selectedDocType) return;
    setState(() {
      _selectedDocType = documentType;
      if (documentType != 'Other Proof' &&
          documentType != 'Other Proof of Address') {
        _otherDocumentController.clear();
      }
      if (!_isTwoSidedId) {
        _backImage = null;
        _backError = null;
      }
    });
  }

  Future<void> _selectManualBirthDate() async {
    if (_isLoading) return;
    final now = DateTime.now();
    final initialDate = _manualBirthDate ??
        DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your birth date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context,
          ).copyWith(
            colorScheme: Theme.of(context).colorScheme),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      final wireDate = storedBirthDateValue(picked);
      AuthService.cacheBirthDateInMemory(
        uid: _user?.uid,
        email: _user?.email,
        name: _user?.name,
        wireDate: wireDate,
      );
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('last_signup_birth_date', wireDate);
        if (_user?.email != null && _user!.email.isNotEmpty) {
          prefs.setString(
            'user_birth_date_${_user!.email.trim().toLowerCase()}',
            wireDate,
          );
        }
        if (_user?.name != null && _user!.name.isNotEmpty) {
          prefs.setString(
            'user_birth_date_${_user!.name.trim().toLowerCase()}',
            wireDate,
          );
        }
        if (_user?.uid != null && _user!.uid.isNotEmpty) {
          prefs.setString('user_birth_date_${_user!.uid}', wireDate);
        }
      }).catchError((_) {});
      if (AuthService.currentUser != null) {
        AuthService.currentUser = AuthService.currentUser!.copyWith(
          birthDate: wireDate,
        );
      }
      setState(() {
        _manualBirthDate = picked;
      });
    }
  }

  void _clearDocument({required bool isFront}) {
    setState(() {
      if (isFront) {
        _frontImage = null;
        _frontError = null;
      } else {
        _backImage = null;
        _backError = null;
      }
    });
  }

  Future<void> _pickImage({
    required bool isFront,
    required ImageSource source,
  }) async {
    if (_isLoading) return;
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 2200,
        imageQuality: 90,
      );
      if (image == null || !mounted) return;
      final imageLength = await image.length();
      final supportedType =
          ESugidValidators.isSupportedImageMimeType(image.mimeType) ||
          ESugidValidators.isSupportedImageFileName(image.path);
      if (!supportedType || imageLength > ESugidInputLimits.imageBytes) {
        _showMessage(
          supportedType
              ? 'Document must be 8 MB or smaller.'
              : 'Use a JPG, PNG, or WebP image.',
          kind: FeedbackKind.warning,
        );
        return;
      }

      setState(() {
        if (isFront) {
          _frontImage = File(image.path);
          _frontError = null;
        } else {
          _backImage = File(image.path);
          _backError = null;
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Verification document selection failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        if (isFront) {
          _frontError = 'Unable to add front image. Please try another.';
        } else {
          _backError = 'Unable to add back image. Please try another.';
        }
      });
    }
  }

  Future<void> _showDocumentSourceSheet({required bool isFront}) async {
    if (_isLoading) return;
    final String targetTitle;
    final String subtitle;
    if (_isTwoSidedId) {
      targetTitle = isFront ? 'Front View of ID' : 'Back View of ID';
      subtitle = isFront
          ? 'Capture or select the front side of your ID.'
          : 'Capture or select the back side of your ID.';
    } else {
      targetTitle = 'Document Photo';
      subtitle = 'Capture or select a clear photo of your document.';
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add verification document',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: sheetContext.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              targetTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: sheetContext.colors.primaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: sheetContext.colors.textSecondary, fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 14),
            _sourceOption(
              context: sheetContext,
              icon: Icons.photo_camera_outlined,
              title: 'Take Photo',
              subtitle: 'Use your camera to take a photo',
              source: ImageSource.camera,
            ),
            const SizedBox(height: 8),
            _sourceOption(
              context: sheetContext,
              icon: Icons.photo_library_outlined,
              title: 'Choose File',
              subtitle: 'Select a photo from your device',
              source: ImageSource.gallery,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (source != null && mounted) {
      await _pickImage(isFront: isFront, source: source);
    }
  }

  Widget _sourceOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required ImageSource source,
  }) {
    return Material(
      color: context.colors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.pop(context, source),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.colors.primaryGreen, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: context.colors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(color: context.colors.textSecondary, fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _uploadImage(String uid, File image, String fileName) async {
    final reference = FirebaseStorage.instance
        .ref()
        .child('verifications')
        .child(uid)
        .child(fileName);
    await reference.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
    return reference.fullPath;
  }

  Future<void> _submitVerification() async {
    final user = _user;
    if (user == null) {
      _showMessage('Please sign in again before submitting verification.',
        kind: FeedbackKind.warning,
      );
      return;
    }
    if (!_isResident) {
      _showMessage('Resident verification is only available to residents.',
        kind: FeedbackKind.warning,
      );
      return;
    }
    if (!_registeredIdentityComplete) {
      _showMessage('Your registered name or barangay is missing.',
        kind: FeedbackKind.warning,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedDocType == null) {
      _showMessage('Choose what you will upload.', kind: FeedbackKind.warning);
      return;
    }
    if (!_hasDocumentDescription) {
      _showMessage('Enter the name of the document you are uploading.',
        kind: FeedbackKind.warning,
      );
      return;
    }
    if (_frontImage == null) {
      _showMessage(
        _isTwoSidedId
            ? 'Please upload the front view of your ID.'
            : 'Please upload a photo of your document.',
        kind: FeedbackKind.warning,
      );
      return;
    }
    if (_isTwoSidedId && _backImage == null) {
      _showMessage('Please upload the back view of your ID.',
        kind: FeedbackKind.warning,
      );
      return;
    }
    final birthDate = _effectiveBirthDate;
    if (birthDate == null) {
      _showMessage('Please provide your birth date.',
        kind: FeedbackKind.warning,
      );
      return;
    }
    final contactNumber = ESugidValidators.normalizePhilippineMobile(
      user.contactNumber ?? '09000000000',
    ) ?? '09000000000';

    setState(() => _isLoading = true);
    try {
      final documentPath = await _uploadImage(
        user.uid,
        _frontImage!,
        'supporting_document.jpg',
      );
      await _uploadImage(
        user.uid,
        _frontImage!,
        'front_document.jpg',
      ).catchError((_) => documentPath);

      String? backDocumentPath;
      if (_isTwoSidedId && _backImage != null) {
        final path = await _uploadImage(
          user.uid,
          _backImage!,
          'back_document.jpg',
        ).catchError((_) => '');
        if (path.isNotEmpty) {
          backDocumentPath = path;
        }
      }

      await ResidentVerificationService.submit(
        ResidentVerificationSubmission(
          birthDate: storedBirthDateValue(birthDate),
          contactNumber: contactNumber,
          documentType: _selectedDocType!,
          otherDocumentName: _isOtherProof
              ? _otherDocumentController.text.trim()
              : '',
          documentPath: documentPath,
          frontDocumentPath: 'verifications/${user.uid}/front_document.jpg',
          backDocumentPath: backDocumentPath,
          submissionStage: _isAdditionalDocumentFlow
              ? 'additional_document'
              : 'initial_document',
        ),
      );
      await AuthService.refreshCurrentUserFromServer();
      if (!mounted) return;
      setState(() {
        _frontImage = null;
        _backImage = null;
        _manualBirthDate = null;
      });
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text(
            'Verification sent to Barangay ${user.barangay} for review.',
          ),
          kind: FeedbackKind.success,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Verification submission failed: $error\n$stackTrace');
      if (mounted) _showMessage(_verificationError(error), kind: FeedbackKind.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _verificationError(Object error) {
    if (error is FirebaseFunctionsException &&
        error.message?.trim().isNotEmpty == true) {
      return error.message!.trim();
    }
    return userFacingError(error);
  }

  void _showMessage(String message, {FeedbackKind kind = FeedbackKind.info}) {
    ScaffoldMessenger.of(context,
    ).showAppSnackBar(AppSnackBar(content: Text(message), kind: kind));
  }

  Widget _buildHeaderCivicBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: context.colors.brandStrong.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.75),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.2588),
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.warningSolid,
              boxShadow: [
                BoxShadow(
                  color: context.colors.highlight,
                  blurRadius: 3,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'MUNICIPALITY OF BARILI',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: context.colors.onBrandMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final isVerified = user?.verificationStatus == VerificationStatus.verified;
    final title = _isWaitingForReview || isVerified
        ? 'Verification status'
        : _needsAttention
        ? 'Verification needs attention'
        : 'Verify your residency';
    return Scaffold(
      backgroundColor: context.colors.background,
      resizeToAvoidBottomInset: true,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          ESugidSliverPageHeader(
            sectionLabelWidget: _buildHeaderCivicBadge(),
            title: title,
            showBackButton: true,
            onBack: () => Navigator.maybePop(context),
            pinned: true,
          ),
          if (!_isResident)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _residentOnlyView(),
            )
          else if (_isWaitingForReview || isVerified)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                36 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverToBoxAdapter(
                child: _statusView(user!, isVerified: isVerified),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                32 +
                    MediaQuery.paddingOf(context).bottom +
                    MediaQuery.viewInsetsOf(context).bottom,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_needsAttention) ...[
                            _attentionNotice(),
                            const SizedBox(height: 14),
                          ],
                          _personalInformationSection(user!),
                          const SizedBox(height: 14),
                          _documentTypeSection(),
                          const SizedBox(height: 14),
                          _uploadDocumentSection(),
                          const SizedBox(height: 14),
                          _privacyNotice(),
                          const SizedBox(height: 18),
                          _submitButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _residentOnlyView() => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Text(
        'Resident verification is only available to resident accounts.',
        textAlign: TextAlign.center,
      ),
    ),
  );

  Widget _personalInformationSection(User user) => _sectionCard(
    icon: Icons.person_outline_rounded,
    title: 'PERSONAL INFORMATION',
    subtitle:
        'Review your registered details and complete the required fields.',
    child: Column(
      children: [
        _readOnlyField(
          label: 'Full Name',
          value: user.name,
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 12),
        _readOnlyField(
          label: 'Barangay',
          value: user.barangay ?? 'Not provided',
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 12),
        _readOnlyField(
          label: 'Birth Date',
          value: _birthDateDisplay,
          icon: Icons.cake_outlined,
          onTap: _effectiveBirthDate == null ? _selectManualBirthDate : null,
        ),
        const SizedBox(height: 12),
        _readOnlyField(
          label: 'Age',
          value: _ageDisplay,
          icon: Icons.schedule_outlined,
        ),
      ],
    ),
  );

  Widget _documentTypeSection() => _sectionCard(
    icon: Icons.description_outlined,
    title: 'VERIFICATION DOCUMENT',
    subtitle: 'Choose the document you will submit for manual barangay review.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Document Type'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedDocType),
          initialValue: _selectedDocType,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: _fieldDecoration(
            hint: 'Select document type',
            icon: Icons.article_outlined,
          ),
          items: acceptedResidencyDocuments
              .map(
                (document) => DropdownMenuItem<String>(
                  value: document.label,
                  child: Text(
                    document.label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              )
              .toList(),
          validator: (value) => value == null ? 'Select a document type' : null,
          onChanged: _isLoading
              ? null
              : (value) {
                  if (value != null) _selectDocument(value);
                },
        ),
        if (_isOtherProof) ...[
          const SizedBox(height: 12),
          _fieldLabel('Document Name'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _otherDocumentController,
            enabled: !_isLoading,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            style: GoogleFonts.poppins(fontSize: 12.5),
            decoration: _fieldDecoration(
              hint: 'Enter the document name',
              icon: Icons.edit_document,
            ).copyWith(counterText: ''),
            validator: (value) {
              if (!_isOtherProof) return null;
              if ((value?.trim().length ?? 0) < 3) {
                return 'Enter the document name';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    ),
  );

  Widget _uploadDocumentSection() {
    final isTwoSided = _isTwoSidedId;
    return _sectionCard(
      icon: Icons.upload_file_outlined,
      title: 'UPLOAD DOCUMENT',
      subtitle: isTwoSided
          ? 'Provide both front and back views of your ID. Your barangay official will review it manually.'
          : 'Provide a clear photo of your document. Your barangay official will review it manually.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.colors.brand.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: context.colors.primaryGreen,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isTwoSided
                        ? 'Both Front and Back photos of your ID are strictly required.'
                        : 'A clear photo of your document is required for manual barangay review.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _idSlotHeader(
            label: isTwoSided ? 'Front View of ID' : 'Document Photo',
            icon: isTwoSided
                ? Icons.credit_card_rounded
                : Icons.description_rounded,
            isUploaded: _frontImage != null,
          ),
          const SizedBox(height: 8),
          _uploadSlot(isFront: true),
          if (_frontError != null) _errorNotice(_frontError!),
          if (isTwoSided) ...[
            const SizedBox(height: 18),
            _idSlotHeader(
              label: 'Back View of ID',
              icon: Icons.flip_to_back_rounded,
              isUploaded: _backImage != null,
            ),
            const SizedBox(height: 8),
            _uploadSlot(isFront: false),
            if (_backError != null) _errorNotice(_backError!),
          ],
        ],
      ),
    );
  }

  Widget _idSlotHeader({
    required String label,
    required IconData icon,
    required bool isUploaded,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colors.primaryGreen),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: isUploaded
                ? context.colors.surfaceAlt
                : context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isUploaded
                  ? context.colors.border : context.colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUploaded
                    ? Icons.check_circle_rounded
                    : Icons.pending_outlined,
                size: 11,
                color: isUploaded ? context.colors.primaryGreen
                    : context.colors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                isUploaded ? 'Ready' : 'Required',
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isUploaded ? context.colors.primaryGreen
                      : context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _uploadSlot({required bool isFront}) {
    final image = isFront ? _frontImage : _backImage;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: image == null
              ? _emptyUploadArea(isFront: isFront)
              : _documentPreview(isFront: isFront, file: image),
        ),
      ),
    );
  }

  Widget _emptyUploadArea({required bool isFront}) {
    return Container(
      key: ValueKey('empty-upload-${isFront ? "front" : "back"}'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.surface, context.colors.surfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.0314),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _DashedRoundedBorderPainter(
          color: context.colors.brand,
          radius: 16,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: ValueKey(
              isFront
                  ? 'verification-upload-area'
                  : 'verification-upload-area-back',
            ),
            onTap: _isLoading
                ? null
                : () => _showDocumentSourceSheet(isFront: isFront),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.surfaceAlt,
                          context.colors.surfaceAlt,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.colors.border,
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.18,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: context.colors.highlight,
                          blurRadius: 0,
                          offset: Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Icon(
                      isFront
                          ? Icons.add_photo_alternate_rounded
                          : Icons.flip_camera_ios_rounded,
                      color: context.colors.primaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFront
                        ? (_isTwoSidedId
                            ? 'Upload Front View'
                            : 'Upload Document')
                        : 'Upload Back View',
                    style: GoogleFonts.poppins(
                      color: context.colors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to take photo or choose file',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: context.colors.textSecondary, fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Text(
                      'JPG, PNG or WebP • Up to 8 MB',
                      style: GoogleFonts.poppins(
                        color: context.colors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _documentPreview({required bool isFront, required File file}) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.09),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: context.colors.highlight,
            blurRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: context.colors.surfaceAlt,
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: context.colors.error,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.brandStrong.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.6),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.shadow.withValues(alpha: 0.2588),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: context.colors.onAccent,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isFront
                            ? (_isTwoSidedId
                                ? 'Front Attached'
                                : 'Document Attached')
                            : 'Back Attached',
                        style: GoogleFonts.poppins(
                          color: context.colors.onAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final changeButton = _build3DChangeButton(isFront: isFront);
              final removeButton = _build3DRemoveButton(isFront: isFront);

              if (constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    changeButton,
                    const SizedBox(height: 8),
                    removeButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: changeButton),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: removeButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _build3DChangeButton({required bool isFront}) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.brand, context.colors.brand],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.primaryGreen, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3.5),
          ),
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: 0.2000),
            blurRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _isLoading
              ? null
              : () => _showDocumentSourceSheet(isFront: isFront),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 18,
                  color: context.colors.onAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  'Change Document',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onAccent,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _build3DRemoveButton({required bool isFront}) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.surface, context.colors.errorSurface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.error, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: context.colors.errorSolid.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2.5),
          ),
          BoxShadow(
            color: context.colors.highlight,
            blurRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _isLoading ? null : () => _clearDocument(isFront: isFront),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: context.colors.error,
                ),
                const SizedBox(width: 5),
                Text(
                  'Remove',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorNotice(String error) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: context.colors.error,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.poppins(
                color: context.colors.error,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyNotice() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.lock_outline_rounded, color: context.colors.primaryGreen, size: 18,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Your document is private and can only be reviewed by authorized officials from your barangay.',
          style: GoogleFonts.poppins(
            color: context.colors.textSecondary,
            fontSize: 10.5,
            height: 1.45,
          ),
        ),
      ),
    ],
  );

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: _isLoading || !_isFormReady
              ? null
              : LinearGradient(
                  colors: [context.colors.brand, context.colors.brand],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          boxShadow: _isLoading || !_isFormReady
              ? null
              : [
                  BoxShadow(
                    color: context.colors.brandStrong.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: context.colors.highlight.withValues(alpha: 0.2000),
                    blurRadius: 0,
                    offset: Offset(0, -1),
                  ),
                ],
        ),
        child: FilledButton.icon(
          onPressed: _isLoading || !_isFormReady ? null : _submitVerification,
          style: FilledButton.styleFrom(
            backgroundColor: _isLoading || !_isFormReady
                ? context.colors.surfaceAlt
                : Colors.transparent,
            disabledBackgroundColor: context.colors.disabledBackground,
            disabledForegroundColor: context.colors.disabled,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _isLoading
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    color: context.colors.surface,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.verified_user_outlined, size: 19),
          label: Text(
            _isLoading
                ? 'Submitting...'
                : _isAdditionalDocumentFlow
                ? 'Resubmit for Verification'
                : 'Submit for Verification',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _attentionNotice() {
    final reason = _user?.verificationReviewReason?.trim();
    final note = _user?.verificationReviewNote?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: context.colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                if (reason?.isNotEmpty == true) reason!,
                if (note?.isNotEmpty == true) note!,
                if (reason?.isNotEmpty != true && note?.isNotEmpty != true)
                  'Upload clearer replacement documents and submit them again.',
              ].join('\n'),
              style: GoogleFonts.poppins(
                color: context.colors.warning,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.colors.border),
      boxShadow: [
        BoxShadow(
          color: context.colors.brandStrong.withValues(alpha: 0.0392),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: context.colors.primaryGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: context.colors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: context.colors.textSecondary,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _fieldLabel(String label) => Text(
    label,
    style: GoogleFonts.poppins(
      color: context.colors.textPrimary,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
    ),
  );

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    bool readOnly = false,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.poppins(
      color: context.colors.textSecondary,
      fontSize: 12,
    ),
    prefixIcon: Icon(icon, color: context.colors.primaryGreen, size: 18),
    filled: true,
    fillColor: readOnly ? context.colors.inputBackground
        : context.colors.inputBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.colors.primaryGreen, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.colors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.colors.error, width: 1.5),
    ),
  );

  Widget _readOnlyField({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel(label),
      const SizedBox(height: 6),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: IgnorePointer(
          ignoring: onTap != null,
          child: TextFormField(
            key: ValueKey('$label-$value'),
            initialValue: value,
            readOnly: true,
            enableInteractiveSelection: false,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            decoration: _fieldDecoration(hint: value, icon: icon, readOnly: true,
                )
                .copyWith(
                  suffixIcon: Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: context.colors.textSecondary,
                  ),
                ),
          ),
        ),
      ),
    ],
  );

  Widget _statusView(User user, {required bool isVerified}) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: isVerified
                  ? context.colors.surfaceAlt
                  : context.colors.infoSurface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              isVerified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
              color: isVerified ? context.colors.primaryGreen
                  : context.colors.info,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 17),
        Text(
          isVerified ? 'Verified Resident' : 'Verification submitted',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: context.colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          isVerified
              ? 'Verified by Barangay ${user.barangay}. Community features are available.'
              : 'Your documents were sent to Barangay ${user.barangay}. An authorized official will review both sides of your ID.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: context.colors.textSecondary, fontSize: 12, height: 1.5,
          ),
        ),
        if (!isVerified) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              children: [
                _infoRow('Status', 'Pending barangay review'),
                _divider(),
                _infoRow(
                  'Submitted',
                  user.verificationSubmittedAt == null
                      ? 'Recently'
                      : DateFormat(
                          'MMM d, y • h:mm a',
                        ).format(user.verificationSubmittedAt!.toLocal()),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(
            label,
            style: GoogleFonts.poppins(color: context.colors.textSecondary, fontSize: 10.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _divider() => Divider(height: 1, color: context.colors.border);
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, (distance + 7).clamp(0, metric.length)),
          paint,
        );
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
