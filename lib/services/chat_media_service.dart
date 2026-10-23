import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/core/errors/user_facing_error.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../widgets/esugid_page_header.dart';

class ChatMediaService {
  ChatMediaService._();

  static final ImagePicker _picker = ImagePicker();

  /// Prompts the user to pick an image from Camera or Gallery.
  static Future<XFile?> pickChatImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: sheetContext.colors.infoSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Send Photo',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: sheetContext.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sheetContext.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: sheetContext.colors.primaryGreen,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'Use your device camera',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: sheetContext.colors.textSecondary,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sheetContext.colors.infoSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: sheetContext.colors.info,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'Pick from your photos',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: sheetContext.colors.textSecondary,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;

    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(userFacingError(e, fallback: 'Could not open camera/gallery. Please try again.')),
            kind: FeedbackKind.error,
          ),
        );
      }
      return null;
    }
  }

  /// Uploads picked image to Firebase Storage and returns download URL.
  static Future<String> uploadChatImage({
    required XFile file,
    required String userId,
    required String conversationId,
    String folder = 'chat_attachments',
  }) async {
    if (Firebase.apps.isEmpty) {
      throw StateError('Photo upload is unavailable until Firebase starts.');
    }

    try {
      await auth.FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {}

    final rawExt = file.path.split('.').lastOrNull?.toLowerCase() ?? 'jpg';
    final ext = (rawExt == 'jpeg' || rawExt == 'jpg')
        ? 'jpg'
        : (rawExt == 'png' ? 'png' : (rawExt == 'webp' ? 'webp' : 'jpg'));
    final uuid = const Uuid().v4();
    final bytes = await file.readAsBytes();

    String contentType = file.mimeType?.trim().toLowerCase() ?? '';
    if (contentType.isEmpty || contentType == 'image/jpg' || contentType == 'application/octet-stream') {
      if (ext == 'png') {
        contentType = 'image/png';
      } else if (ext == 'webp') {
        contentType = 'image/webp';
      } else {
        contentType = 'image/jpeg';
      }
    }

    // No fallback folder: private chat photos must never land in a public one.
    final path = '$folder/$userId/${conversationId}_$uuid.$ext';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return await ref.getDownloadURL();
  }

  /// Opens full-screen interactive image viewer
  static void openFullScreenImage(
    BuildContext context,
    String imageUrl, {
    String? title,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrl: imageUrl,
          title: title),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.title});

  final String imageUrl;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.shadow,
      appBar: AppBar(
        backgroundColor: context.colors.shadow.withValues(alpha: 0.7),
        elevation: 0,
        iconTheme: IconThemeData(color: context.colors.onAccent),
        title: title != null
            ? Text(
                title!,
                style: GoogleFonts.outfit(
                  color: context.colors.onAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(color: context.colors.onAccent,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_rounded,
                  color: context.colors.onBrandMuted,
                  size: 54,
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load image',
                  style: GoogleFonts.outfit(color: context.colors.onBrandMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
