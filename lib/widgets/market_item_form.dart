import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../auth_service.dart';
import '../app_motion.dart';
import '../marketplace_service.dart';
import '../app/theme/app_colors.dart';
import '../core/validation/esugid_input_formatters.dart';
import '../core/validation/esugid_validators.dart';
import '../features/bayanihan_messages/presentation/widgets/bayanihan_unread_button.dart';
import 'esugid_3d_ui.dart';

class MarketItemForm extends StatefulWidget {
  final MarketplaceItem? initialItem;
  final VoidCallback? onSubmitted;

  const MarketItemForm({super.key, this.initialItem, this.onSubmitted});

  @override
  State<MarketItemForm> createState() => _MarketItemFormState();
}

class _MarketItemFormState extends State<MarketItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _quantity;
  late final TextEditingController _barangay;
  late final TextEditingController _meetup;

  final List<XFile> _newImages = [];
  final List<Uint8List> _newImageBytes = [];
  final List<String> _existingImageUrls = [];

  String _category = 'Farm Produce';
  String _unit = 'piece';
  String _availability = 'Available';
  bool _isSubmitting = false;

  final List<({String name, IconData icon})> _categories = [
    (name: 'Farm Produce', icon: Icons.grass_rounded),
    (name: 'Livestock', icon: Icons.pets_rounded),
    (name: 'Plants', icon: Icons.local_florist_rounded),
    (name: 'Handmade', icon: Icons.brush_rounded),
    (name: 'Tools', icon: Icons.handyman_rounded),
    (name: 'Household', icon: Icons.home_rounded),
    (name: 'Other', icon: Icons.more_horiz_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _name = TextEditingController(text: item?.name ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _price = TextEditingController(
      text: item == null ? '' : ESugidValidators.formatPeso(item.price),
    );
    _quantity = TextEditingController(text: item?.quantity.toString() ?? '1');
    _barangay = TextEditingController(text: item?.location ?? '');
    _meetup = TextEditingController(text: item?.meetupArea ?? '');

    if (item != null) {
      _category = item.category;
      _unit = item.priceUnit;
      _availability = item.status;
      _existingImageUrls.add(item.imageUrl);
      _existingImageUrls.addAll(item.additionalImages);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _quantity.dispose();
    _barangay.dispose();
    _meetup.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if ((_newImages.length + _existingImageUrls.length) >= 5) return;
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1400,
    );
    if (image == null) return;
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
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _newImages.add(image);
      _newImageBytes.add(bytes);
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_newImages.isEmpty && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(content: Text('Please add at least one product photo.'),
          kind: FeedbackKind.warning,
        ),
      );
      return;
    }

    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(content: Text('Please sign in to continue.'),
          kind: FeedbackKind.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final itemId = widget.initialItem?.id ?? const Uuid().v4();
      final urls = List<String>.from(_existingImageUrls);
      final storagePaths = <String>[];

      for (var i = 0; i < _newImageBytes.length; i++) {
        final index = urls.length;
        final path = 'marketplace/${user.uid}/$itemId-$index.jpg';
        final reference = FirebaseStorage.instance.ref(path);
        await reference.putData(
          _newImageBytes[i],
          SettableMetadata(contentType: _newImages[i].mimeType ?? 'image/jpeg'),
        );
        final url = await reference.getDownloadURL();
        urls.add(url);
        storagePaths.add(path);
      }

      final item = MarketplaceItem(
        id: itemId,
        name: _name.text.trim(),
        price: ESugidValidators.normalizePeso(_price.text),
        priceUnit: _unit,
        description: _description.text.trim(),
        imageUrl: urls.first,
        additionalImages: urls.skip(1).toList(),
        imageStoragePath: storagePaths.isNotEmpty
            ? storagePaths.first
            : (widget.initialItem?.imageStoragePath ?? ''),
        sellerId: user.uid,
        sellerName: user.name,
        category: _category,
        condition: 'New',
        location: _barangay.text.trim(),
        meetupArea: _meetup.text.trim(),
        contact: 'E-SUGID messaging',
        quantity: int.tryParse(_quantity.text.trim()) ?? 1,
        createdAt: widget.initialItem?.createdAt ?? DateTime.now(),
        status: widget.initialItem == null ? 'Available' : _availability,
      );

      if (widget.initialItem == null) {
        await MarketplaceService.addItem(item);
      } else {
        await MarketplaceService.updateItem(item);
      }

      if (mounted) {
        widget.onSubmitted?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
              widget.initialItem == null
                  ? 'Item posted successfully!'
                  : 'Item updated successfully!',
            ),
            kind: FeedbackKind.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(content: Text('Error saving item. Please try again.'),
            kind: FeedbackKind.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Container(
      margin: const EdgeInsets.only(left: 12, right: 10),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: context.colors.brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(icon, size: 18, color: context.colors.primaryGreen),
      ),
    ),
    filled: true,
    fillColor: context.colors.inputBackground,
    labelStyle: GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: context.colors.textSecondary,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: context.colors.border.withValues(alpha: 0.8),
        width: 1.2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: context.colors.primaryGreen, width: 1.8),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
  );

  Widget _section(String number, String title, String subtitle, Widget child,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 3D Minted Step Medallion
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
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
                      color: context.colors.border.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  BoxShadow(
                        color: context.colors.highlight.withValues(alpha: 0.2392),
                        blurRadius: 0,
                        offset: Offset(0, -1.5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: context.colors.onAccent,
                        shadows: [
                          Shadow(
                            color: context.colors.textPrimary.withValues(alpha: 0.4,
                        ),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: context.colors.textPrimary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      );

  Widget _responsiveFieldPair({required Widget first, required Widget second}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackFields = constraints.maxWidth < 340 || textScale > 1.25;

        if (stackFields) {
          return Column(children: [first, const SizedBox(height: 12), second]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final compactWidth = MediaQuery.sizeOf(context).width < 360;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                compactWidth ? 12 : 16,
                14,
                compactWidth ? 12 : 16,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3D Frosted-Glass Tip Card with Amber Radial Glow
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: 0.9),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.warningSolid.withValues(alpha: 0.12,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.surface,
                                  context.colors.warningSurface,
                                  context.colors.warningSurface,
                                ],
                              ),
                              border: Border.all(
                                color: context.colors.border.withValues(alpha: 0.6,
                                ),
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        context.colors.warningSolid,
                                        context.colors.warningSolid,
                                        context.colors.warningSolid,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: context.colors.border,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.warningSolid
                                            .withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.lightbulb_rounded,
                                      size: 22,
                                      color: context.colors.onAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PRO SELLING TIP',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: context.colors.warning,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Clear photos and honest descriptions build trust with your neighbors.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          color: context.colors.error,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Top Specular Crystal Highlight Line
                          Positioned(
                            top: 0,
                            left: 20,
                            right: 20,
                            height: 1.2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    context.colors.surface.withValues(alpha: 0.9,
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    '1',
                    'Choose Category',
                    'What kind of item are you listing?',
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _categories.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemBuilder: (_, index) {
                          final cat = _categories[index];
                          final selected = cat.name == _category;
                          return ESugidPressable(
                            onTap: () => setState(() => _category = cat.name),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: selected
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          context.colors.brand,
                                          context.colors.brand,
                                        ],
                                      )
                                    : LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          context.colors.surface,
                                          context.colors.surface,
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? context.colors.border.withValues(alpha: 0.45,
                                        )
                                      : context.colors.border.withValues(alpha: 0.8,
                                        ),
                                  width: 1.2,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: context.colors.brandStrong
                                              .withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                        BoxShadow(
                                          color: context.colors.highlight
                                              .withValues(alpha: 0.35),
                                          offset: const Offset(0, -1.2),
                                          blurRadius: 0,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: context.colors.shadow
                                              .withValues(alpha: 0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? context.colors.surface.withValues(alpha: 0.2,
                                            )
                                          : context.colors.brand.withValues(alpha: 0.09,
                                            ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        cat.icon,
                                        size: 13,
                                        color: selected
                                            ? context.colors.onAccent
                                            : context.colors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    cat.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: selected
                                          ? context.colors.onAccent
                                          : context.colors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _section(
                    '2',
                    'Product Photos',
                    'Add up to 5 clear photos of your item.',
                    SizedBox(
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            _existingImageUrls.length +
                            _newImages.length +
                            ((_existingImageUrls.length + _newImages.length) < 5
                                ? 1
                                : 0),
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (_, index) {
                          if (index ==
                              (_existingImageUrls.length + _newImages.length)) {
                            return ESugidPressable(
                              onTap: _addPhoto,
                              child: Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      context.colors.surface,
                                      context.colors.surfaceAlt,
                                      context.colors.surfaceAlt,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: context.colors.primaryGreen
                                        .withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.brandStrong
                                          .withValues(alpha: 0.12),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            context.colors.brand,
                                            context.colors.brand,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: context.colors.brandStrong
                                                .withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.add_a_photo_rounded,
                                          size: 19,
                                          color: context.colors.onAccent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Add Photo',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final isExisting = index < _existingImageUrls.length;
                          return Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: context.colors.border,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.shadow.withValues(alpha: 0.12,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        isExisting
                                            ? Image.network(
                                                _existingImageUrls[index],
                                                fit: BoxFit.cover,
                                              )
                                            : Image.memory(
                                                _newImageBytes[index -
                                                    _existingImageUrls.length],
                                                fit: BoxFit.cover,
                                              ),
                                        // Glass highlight sheen
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topRight,
                                              end: Alignment.bottomLeft,
                                              colors: [
                                                context.colors.surface
                                                    .withValues(alpha: 0.18),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      if (isExisting) {
                                        _existingImageUrls.removeAt(index);
                                      } else {
                                        final newIdx =
                                            index - _existingImageUrls.length;
                                        _newImages.removeAt(newIdx);
                                        _newImageBytes.removeAt(newIdx);
                                      }
                                    }),
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            context.colors.errorSolid,
                                            context.colors.errorSolid,
                                          ],
                                        ),
                                        border: Border.all(
                                          color: context.colors.border,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: context.colors.shadow
                                                .withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: context.colors.onAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _section(
                    '3',
                    'Item Details',
                    '',
                    Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              ESugidInputLimits.shortTitle,
                            ),
                          ],
                          decoration: _decoration(
                            'Item name',
                            Icons.inventory_2_outlined,
                          ),
                          validator: (value) => ESugidValidators.requiredText(
                            value,
                            label: 'Item name',
                            minLength: 3,
                            maxLength: ESugidInputLimits.shortTitle,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          minLines: 3,
                          maxLines: 5,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              ESugidInputLimits.description,
                            ),
                          ],
                          decoration: _decoration(
                            'Description',
                            Icons.notes_outlined,
                          ),
                          validator: (value) => ESugidValidators.requiredText(
                            value,
                            label: 'Description',
                            minLength: 10,
                            maxLength: ESugidInputLimits.description,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _responsiveFieldPair(
                          first: TextFormField(
                            controller: _price,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: const [PesoInputFormatter()],
                            decoration: _decoration(
                              'Price (PHP)',
                              Icons.payments_outlined,
                            ),
                            validator: ESugidValidators.pesoAmount,
                          ),
                          second: DropdownButtonFormField<String>(
                            initialValue: _unit,
                            isExpanded: true,
                            decoration: _decoration(
                              'Price unit',
                              Icons.straighten_outlined,
                            ),
                            items:
                                const ['piece', 'kg', 'bundle', 'sack', 'liter']
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(
                                          'per $e',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(() => _unit = v!),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _responsiveFieldPair(
                          first: TextFormField(
                            controller: _quantity,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: _decoration(
                              'Quantity available',
                              Icons.numbers_outlined,
                            ),
                            validator: ESugidValidators.positiveWholeNumber,
                          ),
                          second: DropdownButtonFormField<String>(
                            initialValue: _availability,
                            isExpanded: true,
                            decoration: _decoration(
                              'Availability',
                              Icons.check_circle_outline_rounded,
                            ),
                            items:
                                (widget.initialItem == null
                                        ? const ['Available']
                                        : const [
                                            'Available',
                                            'Reserved',
                                            'Sold',
                                            'Unavailable',
                                          ])
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(
                                          e,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) =>
                                setState(() => _availability = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _section(
                    '4',
                    'Location',
                    '',
                    Column(
                      children: [
                        TextFormField(
                          controller: _barangay,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              ESugidInputLimits.address,
                            ),
                          ],
                          decoration: _decoration(
                            'Barangay',
                            Icons.location_on_outlined,
                          ),
                          validator: (value) => ESugidValidators.requiredText(
                            value,
                            label: 'Barangay',
                            minLength: 2,
                            maxLength: ESugidInputLimits.address,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _meetup,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              ESugidInputLimits.address,
                            ),
                          ],
                          decoration: _decoration(
                            'Meetup / pickup area (optional)',
                            Icons.place_outlined,
                          ),
                          validator: (value) => ESugidValidators.optionalText(
                            value,
                            label: 'Meetup area',
                            maxLength: ESugidInputLimits.address,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _section(
                    '5',
                    'Contact Preference',
                    '',
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.surface,
                            context.colors.surface,
                            context.colors.surfaceAlt,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.colors.border,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.05,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(alpha: 0.08,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.brand,
                                  context.colors.brand,
                                ],
                              ),
                              border: Border.all(
                                color: context.colors.border.withValues(alpha: 0.4,
                                ),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.brandStrong.withValues(alpha: 0.35,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: CustomPaint(
                                size: Size(20, 20),
                                painter: CivicChatEmblemPainter(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'E-SUGID Civic Messaging',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: context.colors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Buyers will message you securely through E-SUGID.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: context.colors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.check_circle_rounded,
                            color: context.colors.primaryGreen,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: EdgeInsets.all(compactWidth ? 12 : 16),
            child: ESugid3DActionButton(
              label: widget.initialItem == null
                  ? 'Post Item for Sale'
                  : 'Save Changes',
              onTap: _submit,
              isLoading: _isSubmitting,
              icon: widget.initialItem == null
                  ? Icons.storefront_outlined
                  : Icons.save_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
