import 'dart:typed_data';

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../auth_service.dart';
import '../barili_barangays.dart';
import '../services/barangay_logo_service.dart';
import '../widgets/barangay_logo.dart';
import '../features/complaints/complaint_service.dart';
import '../submission_service.dart';
import '../widgets/esugid_page_header.dart';

/// Files a barangay complaint: a private problem with a person or household.
/// Handled directly by the barangay through peaceful mediation. Always private.
class ComplaintFormPage extends StatefulWidget {
  const ComplaintFormPage({
    super.key,
    this.submit = submitComplaint,
    this.onViewComplaints,
    this.existingComplaint,
    this.requestReason,
  });

  final ComplaintSubmitter submit;
  final VoidCallback? onViewComplaints;
  final Submission? existingComplaint;
  final String? requestReason;

  @override
  State<ComplaintFormPage> createState() => _ComplaintFormPageState();
}

const _relationshipOptions = <Map<String, String>>[
  {'value': 'Neighbor', 'label': 'Neighbor (Kapitbahay)'},
  {'value': 'Relative', 'label': 'Family or Relative (Kamag-anak)'},
  {'value': 'Landlord or tenant', 'label': 'Landlord or Renter (Umuupa)'},
  {'value': 'Friend', 'label': 'Friend or Acquaintance (Kakilala)'},
  {'value': 'Barangay resident', 'label': 'Fellow Barangay Resident (Kabarangay)',
  },
  {'value': 'Other', 'label': 'Other (type manually)'},
];

const _complaintTypeOptions = <Map<String, String>>[
  {
    'value': 'Noise',
    'baseType': 'Noise',
    'label': 'Loud noise / Karaoke (Videoke, loud music late at night)',
  },
  {
    'value': 'Boundary or property',
    'baseType': 'Boundary or property',
    'label': 'Land / Fence boundary (Halaman, bakod, o sanga ng puno)',
  },
  {
    'value': 'Unpaid debt',
    'baseType': 'Unpaid debt',
    'label': 'Unpaid debt / Money loan (Utang na hindi binabayaran)',
  },
  {
    'value': 'Threats or harassment',
    'baseType': 'Threats or harassment',
    'label': 'Threats, shouting, or fighting (Pananakot, away, sigawan)',
  },
  {
    'value': 'Animals',
    'baseType': 'Animals',
    'label': 'Dogs or pets (Tahol, asong gala, dumi ng alaga)',
  },
  {
    'value': 'Gossip or rumors',
    'baseType': 'Other',
    'label': 'Gossip or false rumors (Tsismis / paninirang-puri)',
  },
  {
    'value': 'Trash or drainage',
    'baseType': 'Other',
    'label': 'Trash or clogged canal (Pagtatapon ng basura, baradong kanal)',
  },
  {
    'value': 'Damaged property',
    'baseType': 'Other',
    'label': 'Damaged belongings (Nasirang gamit o ari-arian)',
  },
  {
    'value': 'Family dispute',
    'baseType': 'Other',
    'label': 'Family or domestic conflict (Away sa pamilya)',
  },
  {
    'value': 'Other',
    'baseType': 'Other',
    'label': 'Other barangay problem (type manually)',
  },
];

class _ComplaintFormPageState extends State<ComplaintFormPage> {
  BarangayLogoIdentity get _caseLogo => widget.existingComplaint == null
      ? BarangayLogoIdentity(id: bariliBarangayId(_barangay), name: _barangay)
      : (BarangayLogos.forSubmission(widget.existingComplaint!) ??
          BarangayLogoIdentity(
            id: widget.existingComplaint!.barangayId,
            name: widget.existingComplaint!.barangay,
          ));

  final _formKey = GlobalKey<FormState>();
  final _fieldFocus = <TextEditingController, FocusNode>{};
  bool _validationAttempted = false;
  bool _validationRefreshScheduled = false;
  String? _validationMessage;
  FormFieldState<Object?>? _firstInvalidField;
  final _name = TextEditingController();
  final _describe = TextEditingController();
  final _address = TextEditingController();
  final _when = TextEditingController();
  final _location = TextEditingController();
  final _details = TextEditingController();
  final _outcome = TextEditingController();
  final _witnesses = TextEditingController();
  final _customRelationship = TextEditingController();
  final _customType = TextEditingController();

  DateTime? _incidentDateTime;
  bool _nameUnknown = false;
  String _relationship = 'Neighbor';
  String? _type;
  late String _barangay;
  bool _sending = false;
  bool _reviewing = false;
  String? _submissionId;
  String? _draftId;

  Uint8List? _photoBytes;
  String? _photoMimeType;
  bool _removeExistingAttachment = false;
  String? _existingAttachmentUrl;
  String? _existingAttachmentStoragePath;

  @override
  void initState() {
    super.initState();
    _barangay =
        canonicalBariliBarangay(AuthService.currentUser?.barangay) ??
        bariliBarangays.first;

    final existing = widget.existingComplaint;
    if (existing != null) {
      _submissionId = existing.id;
      _draftId = 'complaint-revision-${DateTime.now().microsecondsSinceEpoch}';
      _existingAttachmentUrl = existing.attachmentUrl;
      _existingAttachmentStoragePath = existing.attachmentStoragePath;
      final compData = existing.complaint;
      final respName = (compData['respondentName'] ?? existing.respondentDisplayName)?.toString().trim() ?? '';
      _name.text = (respName == 'Name not given' || respName == 'Not specified') ? '' : respName;
      _describe.text = compData['respondentDescription']?.toString() ?? '';
      _nameUnknown = compData['respondentUnknown'] == true || _name.text.isEmpty;
      _address.text = (compData['respondentAddress'] ?? existing.location)?.toString() ?? '';
      _when.text = (existing.incidentDate != null && existing.incidentDate!.isNotEmpty)
          ? existing.incidentDate!
          : (compData['incidentDate']?.toString().isNotEmpty == true)
              ? compData['incidentDate'].toString()
              : DateFormat('MMMM d, y · h:mm a').format(existing.date);
      _details.text = existing.description;
      _outcome.text = compData['desiredOutcome']?.toString() ?? existing.requestedAction ?? '';
      _witnesses.text = compData['witnesses']?.toString() ?? '';

      final rel = compData['relationship']?.toString() ?? 'Neighbor';
      if (_relationshipOptions.any((opt) => opt['value'] == rel)) {
        _relationship = rel;
      } else {
        _relationship = 'Other';
        _customRelationship.text = rel;
      }

      final compType = compData['complaintType']?.toString() ?? existing.type;
      if (_complaintTypeOptions.any((opt) => opt['value'] == compType)) {
        _type = compType;
      } else if (compType.isNotEmpty) {
        _type = 'Other';
        _customType.text = compType;
      }

      if (existing.barangay != null && existing.barangay!.isNotEmpty) {
        _barangay = canonicalBariliBarangay(existing.barangay) ?? _barangay;
      }
    }
  }

  @override
  void dispose() {
    for (final focus in _fieldFocus.values) {
      focus.dispose();
    }
    for (final controller in [
      _name,
      _describe,
      _address,
      _when,
      _location,
      _details,
      _outcome,
      _witnesses,
      _customRelationship,
      _customType,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }


  Future<void> _pickIncidentDateTime() async {
    final now = DateTime.now();
    final initial = _incidentDateTime ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
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
      _when.text = DateFormat('MMMM d, y · h:mm a').format(combined);
    });
  }

  Future<void> _pickEvidence(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (photo == null || !mounted) return;
      final bytes = await photo.readAsBytes();
      setState(() {
        _photoBytes = bytes;
        _photoMimeType = photo.mimeType ?? 'image/jpeg';
        _removeExistingAttachment = false;
      });
    } catch (_) {
      if (mounted) {
        _showMessage('Could not attach the photo. Please try again.');
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? context.colors.infoSurface.withValues(alpha: 0.2392)
                        : context.colors.infoSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Attach Photo or Evidence',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: context.colors.primaryGreen,
                  ),
                ),
                title: Text(
                  'Take Photo with Camera',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickEvidence(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library_rounded, color: context.colors.primaryGreen,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickEvidence(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    if (_sending) return;
    if (!_validateComplaint()) return;
    setState(() => _sending = true);

    _submissionId ??= newComplaintReference();
    _draftId ??= 'complaint-${DateTime.now().microsecondsSinceEpoch}';

    // Resolve base type for Cloud Function contract
    final String resolvedType;
    if (_type == 'Noise' ||
        _type == 'Boundary or property' ||
        _type == 'Unpaid debt' ||
        _type == 'Threats or harassment' ||
        _type == 'Animals') {
      resolvedType = _type!;
    } else {
      resolvedType = 'Other';
    }

    // Resolve relationship
    final String resolvedRelationship;
    if (_relationship == 'Other') {
      resolvedRelationship = _customRelationship.text.trim().isNotEmpty
          ? _customRelationship.text.trim()
          : 'Other';
    } else {
      resolvedRelationship = _relationship;
    }

    // Details with custom manual type and specific location if applicable
    String detailsText = _details.text.trim();
    if (_location.text.trim().isNotEmpty) {
      detailsText = '[Location: ${_location.text.trim()}, Barangay $_barangay]\n\n$detailsText';
    }
    if (_type == 'Other' && _customType.text.trim().isNotEmpty) {
      detailsText = '[Problem: ${_customType.text.trim()}]\n\n$detailsText';
    } else if (resolvedType == 'Other' && _type != 'Other') {
      detailsText = '[Problem: $_type]\n\n$detailsText';
    }

    final resolvedAddress = _location.text.trim().isNotEmpty
        ? '${_location.text.trim()}, Barangay $_barangay'
        : (_address.text.trim().isNotEmpty
            ? _address.text.trim()
            : 'Barangay $_barangay');

    String finalAttachmentUrl = _removeExistingAttachment
        ? ''
        : (_existingAttachmentUrl ?? '');
    String finalAttachmentStoragePath = _removeExistingAttachment
        ? ''
        : (_existingAttachmentStoragePath ?? '');

    if (_photoBytes != null) {
      try {
        final currentUid = AuthService.currentUser?.uid ??
            FirebaseAuth.instance.currentUser?.uid ??
            'resident';
        final storagePath =
            'complaints/$currentUid/$_submissionId/evidence-${DateTime.now().microsecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref(storagePath);
        final rawMime = _photoMimeType?.trim().toLowerCase();
        final normalizedContentType =
            (rawMime == null || rawMime.isEmpty || rawMime == 'image/jpg')
                ? 'image/jpeg'
                : rawMime;
        await ref.putData(
          _photoBytes!,
          SettableMetadata(contentType: normalizedContentType),
        );
        finalAttachmentUrl = await ref.getDownloadURL();
        finalAttachmentStoragePath = storagePath;
      } catch (e, stack) {
        debugPrint('Error uploading complaint attachment: $e\n$stack');
        if (!mounted) return;
        setState(() => _sending = false);
        _showMessage('The attachment could not be uploaded. Retry or remove it before sending.',
        );
        return;
      }
    }

    try {
      final reference = await widget.submit(
        ComplaintRequest(
          respondentUnknown: _nameUnknown,
          respondentName: _name.text.trim(),
          respondentDescription: _describe.text.trim(),
          respondentAddress: resolvedAddress,
          barangay: _barangay,
          barangayId: bariliBarangayId(_barangay) ?? '',
          relationship: resolvedRelationship,
          complaintType: resolvedType,
          incidentDate: _when.text.trim(),
          description: detailsText,
          desiredOutcome: _outcome.text.trim(),
          witnesses: _witnesses.text.trim(),
          submissionId: _submissionId,
          draftId: _draftId,
          expectedVersion: widget.existingComplaint?.workflowVersion,
          removeAttachment: _removeExistingAttachment && _photoBytes == null,
          attachmentUrl: finalAttachmentUrl,
          attachmentStoragePath: finalAttachmentStoragePath,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(reference);
    } on ComplaintException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showMessage('Your complaint could not be sent. Check your connection and try again.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showAppSnackBar(
        AppSnackBar(
          content: Text(
            message,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          kind: FeedbackKind.error,
        ),
      );
  }

  String? _required(String? value, String message) =>
      (value ?? '').trim().isEmpty ? message : null;

  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
    String? helperText,
    bool isDark = false,
    bool enabled = true,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      helperMaxLines: 2,
      errorMaxLines: 3,
      labelStyle: GoogleFonts.outfit(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: context.colors.textPrimary,
      ),
      hintStyle: GoogleFonts.outfit(
        fontSize: 13,
        color: context.colors.info),
      helperStyle: GoogleFonts.outfit(
        fontSize: 11.5,
        color: context.colors.textSecondary,
      ),
      filled: true,
      fillColor: enabled
          ? context.colors.inputBackground
          : (isDark
              ? context.colors.surfaceAlt.withValues(alpha: 0.35)
              : context.colors.surfaceAlt.withValues(alpha: 0.65)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? context.colors.border.withValues(alpha: 0.08)
              : context.colors.border.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? context.colors.border.withValues(alpha: 0.1216)
              : context.colors.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? context.colors.border.withValues(alpha: 0.1216)
              : context.colors.border,
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: context.colors.primaryGreen,
          width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: context.colors.error,
          width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: context.colors.error,
          width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: !_reviewing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_reviewing) {
          setState(() => _reviewing = false);
        }
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(
          index: _reviewing ? 1 : 0,
          children: [
            _buildFormView(context, isDark),
            _buildReviewView(isDark),
                ],
              ),
            ),
            if (_validationMessage != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FormValidationNotice(
                    key: const ValueKey('complaint-validation-notice'),
                    message: _validationMessage!,
                    onFix: _revealInvalidField,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarangayRequestBanner(String reason, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.warningSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: context.colors.warning,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Information Requested by Barangay',
                  style: GoogleFonts.outfit(
                    color: context.colors.error,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: GoogleFonts.poppins(
                    color: context.colors.error,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView(BuildContext context, bool isDark) {
    return Form(
      onChanged: _refreshValidation,
      autovalidateMode: _validationAttempted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      key: _formKey,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            ESugidSliverPageHeader(
              title: 'File a Complaint',
              showBackButton: true,
              onBack: () => Navigator.of(context).maybePop(),
              iconWidget: BarangayLogo(
                barangayId: _caseLogo.id,
                barangayName: _caseLogo.name,
                size: 38,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
              sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.requestReason != null &&
                      widget.requestReason!.trim().isNotEmpty) ...[
                    _buildBarangayRequestBanner(
                      widget.requestReason!.trim(),
                      isDark,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _privacyNote(isDark),
                  const SizedBox(height: 16),

                  // ── SECTION 1: WHO IS IT ABOUT ──
                  _section(
                    isDark: isDark,
                    number: 1,
                    title: 'Who is this about?',
                    children: [
                      Opacity(
                        opacity: _nameUnknown ? 0.52 : 1.0,
                        child: IgnorePointer(
                          ignoring: _nameUnknown,
                          child: TextFormField(
                            focusNode: _focusFor(_name),
                            key: const ValueKey('complaint-respondent-name'),
                            controller: _name,
                            enabled: !_nameUnknown,
                            textCapitalization: TextCapitalization.words,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _nameUnknown
                                  ? context.colors.textSecondary.withValues(alpha: 0.5)
                                  : context.colors.textPrimary,
                            ),
                            decoration: _inputDecoration(
                              labelText: 'Their name',
                              hintText: _nameUnknown
                                  ? '(Name not known)'
                                  : 'e.g. Juan Dela Cruz',
                              isDark: isDark,
                              enabled: !_nameUnknown,
                            ),
                            validator: (value) => _nameUnknown
                                ? null
                                : _required(
                                    value,
                                    'Enter their name, or check the box below.',
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: context.colors.surfaceAlt,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark
                                ? context.colors.border.withValues(alpha: 0.1216,
                                  )
                              : context.colors.border,
                            width: 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          key: const ValueKey('complaint-name-unknown'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          dense: true,
                          activeColor: context.colors.brand,
                          checkColor: context.colors.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _nameUnknown,
                          onChanged: (value) {
                            final unknown = value ?? false;
                            setState(() {
                              _nameUnknown = unknown;
                              if (unknown) {
                                _name.clear();
                              }
                            });
                            _refreshValidation();
                          },
                          title: Text(
                            "I don't know their name",
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      if (_nameUnknown) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          focusNode: _focusFor(_describe),
                          controller: _describe,
                          maxLines: 2,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                          decoration: _inputDecoration(
                            labelText: 'Describe them',
                            hintText:
                                'e.g. The neighbor beside the chapel with the blue gate',
                            helperText:
                                'Help the barangay find who they are.',
                            isDark: isDark,
                          ),
                          validator: (value) => _required(
                            value,
                            'Describe the person so the barangay can find them.',
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('complaint-relationship-dropdown'),
                        initialValue: _relationship,
                        isExpanded: true,
                        dropdownColor: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: context.colors.primaryGreen,
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                        decoration: _inputDecoration(
                          labelText: 'They are my',
                          hintText: 'Select relationship',
                          isDark: isDark,
                        ),
                        items: [
                          for (final rel in _relationshipOptions)
                            DropdownMenuItem(
                              key: ValueKey('complaint-relationship-${rel['value']}',
                            ),
                              value: rel['value'],
                              child: Text(
                                rel['label']!,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _relationship = value);
                        },
                      ),
                      if (_relationship == 'Other') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          focusNode: _focusFor(_customRelationship),
                          key: const ValueKey('complaint-relationship-other'),
                          controller: _customRelationship,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                          decoration: _inputDecoration(
                            labelText: 'Describe relationship',
                            hintText: 'e.g. Co-worker, friend, business partner',
                            isDark: isDark,
                          ),
                          validator: (value) => _relationship == 'Other' &&
                                  (value ?? '').trim().isEmpty
                              ? 'Please tell us how you know them.'
                              : null,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── SECTION 2: WHAT HAPPENED ──
                  _section(
                    isDark: isDark,
                    number: 2,
                    title: 'What happened?',
                    children: [
                      DropdownButtonFormField<String>(
                        key: const ValueKey('complaint-type-dropdown'),
                        initialValue: _type,
                        isExpanded: true,
                        dropdownColor: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: context.colors.primaryGreen,
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                        decoration: _inputDecoration(
                          labelText: 'Type of problem',
                          hintText: 'Choose the problem',
                          isDark: isDark,
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty
                                ? 'Choose the type of problem.'
                                : null,
                        items: [
                          for (final opt in _complaintTypeOptions)
                            DropdownMenuItem(
                              key: ValueKey('complaint-type-${opt['value']}'),
                              value: opt['value'],
                              child: Text(
                                opt['label']!,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() => _type = value),
                      ),
                      if (_type == 'Other') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          focusNode: _focusFor(_customType),
                          key: const ValueKey('complaint-type-other'),
                          controller: _customType,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                          decoration: _inputDecoration(
                            labelText: 'Describe the problem type',
                            hintText: 'Type what kind of problem this is...',
                            isDark: isDark,
                          ),
                          validator: (value) => _type == 'Other' &&
                                  (value ?? '').trim().isEmpty
                              ? 'Please describe what kind of problem this is.'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        focusNode: _focusFor(_when),
                        key: const ValueKey('complaint-when'),
                        controller: _when,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                        decoration: _inputDecoration(
                          labelText: 'When did it happen? (Date & Time)',
                          hintText: 'e.g. Oct 7, 2026 · 10:30 AM or gahapon',
                          isDark: isDark,
                          prefixIcon: Icon(
                            Icons.access_time_rounded,
                            color: context.colors.primaryGreen,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            tooltip: 'Select date and time',
                            icon: Icon(
                              Icons.calendar_month_rounded,
                              color: context.colors.primaryGreen,
                              size: 20,
                            ),
                            onPressed: _pickIncidentDateTime,
                          ),
                        ),
                        validator: (value) =>
                            _required(value, 'Say when it happened.'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        focusNode: _focusFor(_location),
                        key: const ValueKey('complaint-location'),
                        controller: _location,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                        decoration: _inputDecoration(
                          labelText: 'Specific location in Barangay $_barangay',
                          hintText: 'e.g. Purok Manga, Sitio Tubod, or near chapel',
                          isDark: isDark,
                          prefixIcon: Icon(
                            Icons.place_rounded,
                            color: context.colors.primaryGreen,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        focusNode: _focusFor(_details),
                        key: const ValueKey('complaint-details'),
                        controller: _details,
                        maxLines: 4,
                        maxLength: 1000,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textPrimary,
                        ),
                        decoration: _inputDecoration(
                          labelText: 'Tell us what happened',
                          hintText:
                              'Describe clearly what happened so the barangay can help...',
                          helperText:
                              'At least 10 characters. Describe what happened.',
                          isDark: isDark,
                        ),
                        validator: (value) => (value ?? '').trim().length < 10
                            ? 'Description must have at least 10 characters.'
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── SECTION 3: DESIRED RESOLUTION ──
                  _section(
                    isDark: isDark,
                    number: 3,
                    title: 'What would solve this for you?',
                    children: [
                      TextFormField(
                        focusNode: _focusFor(_outcome),
                        controller: _outcome,
                        maxLines: 2,
                        maxLength: 300,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textPrimary,
                        ),
                        decoration: _inputDecoration(
                          labelText: 'Your requested solution',
                          hintText:
                              'e.g. That they stop loud noise after 10 PM, or fix the wall',
                          helperText:
                              'The barangay uses this during the peace talk.',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── SECTION 4: WITNESSES ──
                  _section(
                    isDark: isDark,
                    number: 4,
                    title: 'Witnesses (optional)',
                    children: [
                      TextFormField(
                        focusNode: _focusFor(_witnesses),
                        controller: _witnesses,
                        maxLength: 300,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textPrimary,
                        ),
                        decoration: _inputDecoration(
                          labelText: 'Witness names',
                          hintText: 'Names of people who saw or heard it',
                          helperText: 'Leave empty if no witnesses.',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── SECTION 5: PHOTO & EVIDENCE ──
                  _section(
                    isDark: isDark,
                    number: 5,
                    title: 'Photo & Evidence (optional)',
                    children: [
                      _buildPhotoEvidenceCard(isDark)],
                  ),
                  const SizedBox(height: 24),

                  // ── REVIEW & SUBMIT ACTIONS ──
                  _buildReviewButton(isDark),
                  const SizedBox(height: 12),
                  _buildSubmitButton(isDark),
                ],
              ),
            ),
          ),
        ],
        ),
      );
  }

  Widget _buildPhotoEvidenceCard(bool isDark) {
    final hasNewPhoto = _photoBytes != null;
    final hasExistingPhoto = !_removeExistingAttachment &&
        _existingAttachmentUrl != null &&
        _existingAttachmentUrl!.isNotEmpty;

    if (hasNewPhoto || hasExistingPhoto) {
      return Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                : context.colors.border,
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  color: isDark ? context.colors.infoSurface.withValues(alpha: 0.2588)
                      : context.colors.infoSurface,
                  child: hasNewPhoto
                      ? Image.memory(
                          _photoBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                        )
                      : Image.network(
                          _existingAttachmentUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: 40,
                              color: context.colors.info,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.brandStrong.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: context.colors.onAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Photo Attached',
                          style: GoogleFonts.outfit(
                            color: context.colors.onAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('complaint-change-photo'),
                      onPressed: _showImageSourcePicker,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        'Change Photo',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.primaryGreen,
                        side: BorderSide(
                          color: isDark ? context.colors.primaryGreen
                              : context.colors.border,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('complaint-remove-photo'),
                      onPressed: () {
                        setState(() {
                          _photoBytes = null;
                          _photoMimeType = null;
                          _removeExistingAttachment = true;
                        });
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: Text(
                        'Remove',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.error,
                        side: BorderSide(color: context.colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      key: const ValueKey('complaint-add-photo'),
      onTap: _showImageSourcePicker,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.border,
            width: 1.4),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colors.primaryGreen.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.add_a_photo_outlined,
                color: context.colors.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add Photo or Evidence',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Take a photo or upload from gallery (e.g. damage, incident site, receipt)',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacyNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? context.colors.border
              : context.colors.border.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: isDark ? 0.2 : 0.08,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: context.colors.highlight,
            blurRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7.5),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(
                color: context.colors.primaryGreen.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.shield_rounded,
              color: context.colors.primaryGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Private & Safe',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5.5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.warningSolid.withValues(alpha: 0.25,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'CONFIDENTIAL',
                        style: GoogleFonts.outfit(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: context.colors.warning,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Only you and barangay officials can see this complaint. '
                  'The other person will not see your report in the app.',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required bool isDark,
    required int number,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: context.colors.border,
          width: 1.2),
        boxShadow: [
          BoxShadow(
            color: (context.colors.brandStrong).withValues(
              alpha: isDark ? 0.35 : 0.06,
            ),
            blurRadius: 16,
            offset: const Offset(0, 5),
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
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.brand,
                          context.colors.brandStrong,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.35,
                          ),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: context.colors.highlight,
                          blurRadius: 0,
                          offset: Offset(0, -0.8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$number',
                        style: GoogleFonts.outfit(
                          color: context.colors.onAccent,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.brand,
            context.colors.brand,
            context.colors.brandStrong,
          ],
        ),
        border: Border.all(
          color: context.colors.primaryGreen.withValues(alpha: 0.55),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.38),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: context.colors.highlight,
            blurRadius: 0,
            offset: Offset(0, -1.2),
          ),
        ],
      ),
      child: FilledButton(
        key: const ValueKey('complaint-submit'),
        onPressed: _sending ? null : _send,
        style: FilledButton.styleFrom(
          foregroundColor: context.colors.onAccent,

          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _sending
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.send_rounded,
                    color: context.colors.onBrandMuted,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.existingComplaint != null
                          ? 'Resubmit Complaint'
                          : 'Submit Complaint',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,

                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }

  Widget _buildReviewButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? context.colors.border.withValues(alpha: 0.45)
              : context.colors.border,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: isDark ? 0.20 : 0.08,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('complaint-review'),
          borderRadius: BorderRadius.circular(16),
          onTap: _sending ? null : _openReview,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.rate_review_rounded,
                  color: context.colors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.existingComplaint != null
                        ? 'Review & Resubmit'
                        : 'Review Complaint',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openReview() {
    if (!_validateComplaint()) return;
    setState(() => _reviewing = true);
  }

  FocusNode _focusFor(TextEditingController controller) =>
      _fieldFocus.putIfAbsent(controller, FocusNode.new);

  bool _validateComplaint({bool reveal = true}) {
    final form = _formKey.currentState;
    if (form == null) return false;
    final invalid = form.validateGranularly().toList()
      ..sort((a, b) {
        double top(FormFieldState<Object?> field) {
          final box = field.context.findRenderObject();
          return box is RenderBox ? box.localToGlobal(Offset.zero).dy : 0;
        }

        return top(a).compareTo(top(b));
      });
    setState(() {
      _validationAttempted = true;
      _firstInvalidField = invalid.isEmpty ? null : invalid.first;
      _validationMessage = invalid.isEmpty ? null : invalid.first.errorText;
      if (invalid.length > 1) {
        final count = invalid.length - 1;
        _validationMessage =
            '$_validationMessage Check $count more ${count == 1 ? 'field' : 'fields'}.';
      }
      if (invalid.isNotEmpty) _reviewing = false;
    });
    if (invalid.isNotEmpty && reveal) _revealInvalidField();
    return invalid.isEmpty;
  }

  void _refreshValidation() {
    if (!_validationAttempted || _validationRefreshScheduled) return;
    _validationRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validationRefreshScheduled = false;
      if (mounted && !_sending && !_reviewing) {
        _validateComplaint(reveal: false);
      }
    });
  }

  void _revealInvalidField() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final field = _firstInvalidField;
      if (!mounted || field == null || !field.mounted) return;
      final widget = field.widget;
      if (widget is TextFormField) {
        _fieldFocus[widget.controller]?.requestFocus();
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !field.mounted) return;
      final box = field.context.findRenderObject();
      final viewport = Scrollable.of(field.context).position.viewportDimension;
      final space = viewport - (box is RenderBox ? box.size.height : 0);
      final header = responsiveCompactESugidPageHeaderExtent(
        MediaQuery.of(context),
      );
      final alignment = space > 0
          ? ((header + 12) / space).clamp(0.0, 1.0)
          : 0.0;
      await Scrollable.ensureVisible(
        field.context,
        alignment: alignment,
        duration: const Duration(milliseconds: 300),
      );
    });
  }

  Widget _buildReviewView(bool isDark) {
    final user = AuthService.currentUser;
    final residentName = user?.name.isNotEmpty == true
        ? user!.name
        : 'Resident';
    final residentBarangay = _barangay.isNotEmpty
        ? _barangay
        : (user?.barangay ?? 'Not specified');
    final datePrepared = DateFormat('MMM d, y').format(DateTime.now());
    final receivingOffice = 'Barangay $_barangay';

    final resolvedRespondent = _nameUnknown
        ? (_describe.text.trim().isNotEmpty
            ? 'Unknown (${_describe.text.trim()})'
            : 'Unknown Person')
        : (_name.text.trim().isNotEmpty ? _name.text.trim() : 'Not specified');

    final resolvedRel = _relationship == 'Other' && _customRelationship.text.trim().isNotEmpty
        ? _customRelationship.text.trim()
        : _relationship;

    final resolvedProblem = _type == 'Other' && _customType.text.trim().isNotEmpty
        ? _customType.text.trim()
        : (_type ?? 'Not specified');

    final resolvedAddress = _location.text.trim().isNotEmpty
        ? '${_location.text.trim()}, Barangay $_barangay'
        : (_address.text.trim().isNotEmpty
            ? _address.text.trim()
            : 'Barangay $_barangay');

    final detailsText = _details.text.trim().isEmpty
        ? 'No details provided.'
        : _details.text.trim();

    return Container(
      color: context.colors.brandStrong,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildReviewHeader(isDark),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  key: const PageStorageKey('complaint-review-scroll'),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 30),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 580),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildComplaintReviewSummary(
                            isDark: isDark,
                            residentName: residentName,
                            residentBarangay: residentBarangay,
                            datePrepared: datePrepared,
                            receivingOffice: receivingOffice,
                            resolvedRespondent: resolvedRespondent,
                            resolvedRel: resolvedRel,
                            resolvedAddress: resolvedAddress,
                            resolvedProblem: resolvedProblem,
                            detailsText: detailsText,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: OutlinedButton(
                                  onPressed: () => setState(() => _reviewing = false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14,
                                    ),
                                    side: BorderSide(
                                      color: isDark ? context.colors.border.withValues(
                                              alpha: 0.2392,
                                            )
                                          : context.colors.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    'Edit Details',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(
                                      colors: [
                                        context.colors.brand,
                                        context.colors.brand,
                                        context.colors.brandStrong,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.brandStrong
                                            .withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: FilledButton(
                                    key: const ValueKey('complaint-confirm-submit',
                                    ),
                                    onPressed: _sending ? null : _send,
                                    style: FilledButton.styleFrom(
                                      foregroundColor: context.colors.onAccent,

                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _sending
                                        ? SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color:
                                                    context.colors.onBrandMuted,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  widget.existingComplaint != null
                                                      ? 'Resubmit Complaint'
                                                      : 'Confirm & Submit',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.w800,

                                                    fontSize: 14.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  Widget _buildReviewHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _reviewing = false),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.surface.withValues(alpha: 0.16),
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.25),
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Review Your Complaint',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: context.colors.onAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Verify all details before submitting',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: context.colors.onAccent.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintReviewSummary({
    required bool isDark,
    required String residentName,
    required String residentBarangay,
    required String datePrepared,
    required String receivingOffice,
    required String resolvedRespondent,
    required String resolvedRel,
    required String resolvedAddress,
    required String resolvedProblem,
    required String detailsText,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? context.colors.border.withValues(alpha: 0.2392)
              : context.colors.border,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(
          children: [
            Image.asset(
              BarangayLogos.municipalityAsset,
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Check your details before sending. Formal documents are handled at the barangay office.'),
            ),
            const SizedBox(width: 8),
            BarangayLogo(
              barangayId: _caseLogo.id,
              barangayName: _caseLogo.name,
              size: 36,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildReviewSectionBox(icon: Icons.person_outline, title: 'RESIDENT INFORMATION', isDark: isDark,
          child: Column(children: [
            _reviewRow('Name', residentName, isDark: isDark),
            _reviewRow('Barangay', residentBarangay, isDark: isDark),
            _reviewRow('Receiving office', receivingOffice, isDark: isDark, isLast: true,
                ),
          ],
            ),
          ),
        _buildReviewSectionBox(icon: Icons.people_outline, title: 'WHO IT IS ABOUT', isDark: isDark,
          child: Column(children: [
            _reviewRow('Respondent', resolvedRespondent, isDark: isDark),
            _reviewRow('Relationship', resolvedRel, isDark: isDark),
            _reviewRow('Address', resolvedAddress, isDark: isDark, isLast: true,
                ),
          ],
            ),
          ),
        _buildReviewSectionBox(icon: Icons.description_outlined, title: 'WHAT HAPPENED', isDark: isDark,
          child: Column(children: [
            _reviewRow('Problem type', resolvedProblem, isDark: isDark),
            _reviewRow('When', _when.text.trim(), isDark: isDark),
            if (_location.text.trim().isNotEmpty)
              _reviewRow('Location', '${_location.text.trim()}, Barangay $_barangay', isDark: isDark,
                  ),
            _buildNarrativeBox(detailsText, isDark: isDark),
          ],
            ),
          ),
        if (_outcome.text.trim().isNotEmpty)
          _buildReviewSectionBox(icon: Icons.handshake_outlined, title: 'DESIRED RESOLUTION', isDark: isDark,
            child: _buildNarrativeBox(_outcome.text.trim(), isDark: isDark),
            ),
        if (_witnesses.text.trim().isNotEmpty)
          _buildReviewSectionBox(icon: Icons.groups_outlined, title: 'WITNESSES', isDark: isDark,
            child: _buildNarrativeBox(_witnesses.text.trim(), isDark: isDark),
            ),
        if (_photoBytes != null || (!_removeExistingAttachment && _existingAttachmentUrl?.isNotEmpty == true))
          const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('1 supporting attachment included'),
            ),
        _buildReviewSectionBox(icon: Icons.lock_outline, title: 'PRIVACY', isDark: isDark, isLast: true,
          child: _reviewRow('Visibility', 'Private in Barangay $_barangay', isDark: isDark, isLast: true,
            ),
          ),
      ],
      ),
    );
  }

  Widget _buildReviewSectionBox({
    required IconData icon,
    required String title,
    required Widget child,
    required bool isDark,
    bool isLast = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: context.colors.primaryGreen),
            const SizedBox(width: 7),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: context.colors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                  : context.colors.border,
            ),
          ),
      ],
    );
  }

  Widget _reviewRow(
    String label,
    String value, {
    required bool isDark,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: context.colors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 12,
            child: Text(
              ':',
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not specified' : value,
              style: GoogleFonts.poppins(
                color: context.colors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrativeBox(String text, {required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colors.border),
      ),
      child: Text(
        text.isEmpty ? 'Not specified' : text,
        style: GoogleFonts.poppins(
          color: context.colors.textPrimary,
          fontSize: 11,
          height: 1.45,
        ),
      ),
    );
  }
}
