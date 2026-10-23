import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme/semantic_colors.dart';

/// The seller keeps the remaining row width, so long names can wrap in place.
class MarketplaceSellerByline extends StatelessWidget {
  const MarketplaceSellerByline({
    super.key,
    required this.sellerName,
    required this.age,
    required this.avatar,
    required this.onSellerTap,
  });

  final String sellerName;
  final String age;
  final Widget avatar;
  final VoidCallback? onSellerTap;

  @override
  Widget build(BuildContext context) {
    final seller = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSellerTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offered by ${sellerName.isNotEmpty ? sellerName : 'Barili Resident'}',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.verified_rounded,
            size: 14,
            color: context.colors.primaryGreen,
          ),
        ],
      ),
    );
    final timestamp = Text(
      age,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: context.colors.textSecondary,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(13) > 17) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              seller,
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 4),
                child: timestamp,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: seller),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '|',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            timestamp,
          ],
        );
      },
    );
  }
}
