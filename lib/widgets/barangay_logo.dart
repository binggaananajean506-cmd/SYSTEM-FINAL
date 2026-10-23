import 'package:flutter/material.dart';

import '../services/barangay_logo_service.dart';

/// Contains the entire seal, including non-circular emblems such as Vito's.
/// The surrounding page may decorate it, but must not clip it to a circle.
class BarangayLogo extends StatelessWidget {
  const BarangayLogo({
    super.key,
    this.barangayId,
    this.barangayName,
    this.size = 48,
  });

  final String? barangayId;
  final String? barangayName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final identity = BarangayLogoIdentity(id: barangayId, name: barangayName);
    final path = identity.assetPath;
    final pixelSize =
        (size * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1)).ceil();
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: pixelSize,
      semanticLabel: path == BarangayLogos.municipalityAsset
          ? 'Municipality of Barili seal'
          : 'Barangay ${identity.canonicalName} seal',
      errorBuilder: (context, error, stack) {
        BarangayLogos.reportMissing('Unable to display $path');
        return Image.asset(
          BarangayLogos.municipalityAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          cacheWidth: pixelSize,
          semanticLabel: 'Municipality of Barili seal',
          errorBuilder: (context, error, stack) => SizedBox.square(
            dimension: size,
            child: Icon(
              Icons.account_balance_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      },
    );
  }
}
