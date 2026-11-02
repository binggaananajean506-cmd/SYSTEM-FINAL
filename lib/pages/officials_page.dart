import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/esugid_page_header.dart';

class OfficialsPage extends StatelessWidget {
  const OfficialsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          const ESugidSliverPageHeader(
            sectionLabel: 'Government',
            title: 'Municipal Officials',
            subtitle: 'Elected leaders of Barili',
            icon: Icons.account_balance_rounded,
            showBackButton: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildExecutiveSection(context),
                const SizedBox(height: 32),
                _buildCouncilSection(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'EXECUTIVE BRANCH', Icons.account_balance_rounded,
        ),
        const SizedBox(height: 16),
        _buildTactileOfficialCard(
          context: context,
          name: 'Pablo John "John-John" D. Garcia IV',
          position: 'Municipal Mayor',
          imagePath: 'assets/images/resident_dashboard/mayor.png',
          isPrimary: true,
        ),
        const SizedBox(height: 16),
        _buildTactileOfficialCard(
          context: context,
          name: 'Luisito "Loy" L. Ponsica',
          position: 'Municipal Vice Mayor',
          imagePath: 'assets/images/resident_dashboard/luisito.png',
        ),
      ],
    );
  }

  Widget _buildCouncilSection(BuildContext context) {
    final councilors = [
      {
        'name': 'JAYRA ANGELIC RUIZ-JAVIER',
        'image': 'assets/images/resident_dashboard/jayra.png',
      },
      {
        'name': 'ROBERT ARTHUR "BOBET" P. ALQUIZOLA',
        'image': 'assets/images/resident_dashboard/bobet.png',
      },
      {
        'name': 'JOHN JOSHUA L. RICARDEL',
        'image': 'assets/images/resident_dashboard/ricardel.png',
      },
      {
        'name': 'JOHN ANTHONY "JOHN-JOHN" T. AÑOBER',
        'image': 'assets/images/resident_dashboard/anober.png',
      },
      {
        'name': 'SHELOMITH ANN C. EWICAN',
        'image': 'assets/images/resident_dashboard/shelomith.png',
      },
      {
        'name': 'TERESITO P. MARIÑAS',
        'image': 'assets/images/resident_dashboard/teresito.png',
      },
      {
        'name': 'Nelson G. Gingoyon',
        'image': 'assets/images/resident_dashboard/nelson.png',
      },
      {
        'name': 'Andres C. Alpas',
        'image': 'assets/images/resident_dashboard/andres.png',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'SANGGUNIANG BAYAN MEMBERS', Icons.groups_rounded,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: councilors.length,
          itemBuilder: (context, index) {
            return _buildCouncilorCard(
              context,
              councilors[index]['name']!,
              councilors[index]['image']!,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: context.colors.primaryGreen, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            color: context.colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTactileOfficialCard({
    required BuildContext context,
    required String name,
    required String position,
    required String imagePath,
    bool isPrimary = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showOfficialProfile(context, name, position, imagePath),
      child: Container(
        height: isPrimary ? 200 : 170,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? context.colors.brandStrong.withValues(alpha: 0.3)
                  : context.colors.brandStrong.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colors.brandStrong,
                        context.colors.brand,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Container(
                      width: isPrimary ? 120 : 100,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? context.colors.brandStrong
                            : context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark
                              ? context.colors.border
                              : context.colors.primaryGreen.withValues(alpha: 0.2,
                                ),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.person_rounded,
                                color: context.colors.textSecondary,
                                size: 40,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.brandStrong,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              position.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: context.colors.onAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              color: context.colors.textPrimary,
                              fontSize: isPrimary ? 20 : 17,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: context.colors.primaryGreen,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Government of Barili',
                                style: GoogleFonts.outfit(
                                  color: isDark
                                      ? context.colors.info
                                      : context.colors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildCouncilorCard(
    BuildContext context,
    String name,
    String imagePath,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showOfficialProfile(context, name, 'Councilor', imagePath),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
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
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 20,
              bottom: 20,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: context.colors.brand.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.primaryGreen.withValues(alpha: 0.15,
                        ),
                        width: 2,
                      ),
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                context.colors.brandStrong,
                                context.colors.disabledBackground,
                              ]
                            : [
                                context.colors.surface,
                                context.colors.surfaceAlt,
                              ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.person_rounded,
                              color: context.colors.textSecondary,
                              size: 35,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'COUNCILOR',
                      style: GoogleFonts.outfit(
                        color: context.colors.primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: context.colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOfficialProfile(
    BuildContext context,
    String name,
    String position,
    String imagePath,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: context.colors.shadow.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation1, animation2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: animation,
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 340),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.shadow.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Background Decorative Orb
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colors.brand.withValues(
                              alpha: 0.05,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded),
                                color: context.colors.textSecondary,
                                style: IconButton.styleFrom(
                                  backgroundColor: context.colors.surfaceAlt,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Official Image
                            Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.colors.primaryGreen
                                          .withValues(
                                    alpha: 0.2),
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colors.brandStrong
                                            .withValues(
                                      alpha: 0.1),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                        Icons.person_rounded,
                                        color: context.colors.textSecondary,
                                        size: 80,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Position Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                        context.colors.brandStrong,
                                        context.colors.brand,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                position.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: context.colors.onAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Name
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: context.colors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Verification
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                    Icon(
                                  Icons.verified_rounded,
                                  color: context.colors.primaryGreen,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Government of Barili',
                                  style: GoogleFonts.outfit(
                                    color: isDark
                                        ? context.colors.info
                                            : context.colors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Action Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? context.colors.brandStrong
                                          : context.colors.surfaceAlt,
                                  foregroundColor: context.colors.onAccent,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: context.colors.border,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Close Profile',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
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
              },
            ),
          ),
            ),
          ),
        );
      },
    );
  }
}
