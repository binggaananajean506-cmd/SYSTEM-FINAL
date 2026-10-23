import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app_motion.dart';
import '../../../auth_service.dart';

double authenticatedBottomNavigationHeight(BuildContext context) {
  final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(9.5) * 1.35;
  final contentHeight = 56 + scaledLabelHeight;
  return contentHeight > 70 ? contentHeight : 70;
}

double authenticatedBottomNavigationReservedHeight(BuildContext context) =>
    authenticatedBottomNavigationHeight(context) +
    MediaQuery.viewPaddingOf(context).bottom +
    24;

class AuthenticatedBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final User user;
  final ValueChanged<int> onSelect;
  final VoidCallback onPrimaryAction;

  const AuthenticatedBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.user,
    required this.onSelect,
    required this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final navigationHeight = authenticatedBottomNavigationHeight(context);
    final totalHeight = navigationHeight + bottomInset + 24;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: navigationHeight + bottomInset,
                padding: EdgeInsets.fromLTRB(6, 6, 6, bottomInset),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? context.colors.border.withValues(alpha: 0.14)
                          : context.colors.border,
                      width: 1.5,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(
                        alpha: isDark ? 0.45 : 0.12,
                      ),
                      blurRadius: 26,
                      offset: const Offset(0, -7),
                    ),
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(
                        alpha: isDark ? 0.2 : 0.08,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                    BoxShadow(
                      color: context.colors.highlight.withValues(
                        alpha: isDark ? 0.03 : 0.95,
                      ),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _item(context, 0, Icons.home_rounded, 'HOME', largeText),
                    _item(
                      context,
                      1,
                      Icons.newspaper_rounded,
                      'UPDATES',
                      largeText,
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: largeText ? 36 : 33),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.role == UserRole.resident ? 'CONCERN' : 'POST',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: selectedIndex == 2
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: selectedIndex == 2
                                    ? (context.colors.textPrimary)
                                          : (context.colors.primaryGreen),
                                letterSpacing: 0.35,
                              ),
                            ),
                            if (!largeText)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.only(top: 2),
                                width: selectedIndex == 2 ? 14 : 0,
                                height: 2.5,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: selectedIndex == 2
                                      ? LinearGradient(
                                          colors: [
                                            context.colors.brand,
                                            context.colors.brand,
                                                ],
                                        )
                                      : null,
                                  boxShadow: selectedIndex == 2
                                      ? [
                                          BoxShadow(
                                            color: (context.colors.brandStrong)
                                                .withValues(alpha: 0.5),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    _item(
                      context,
                      3,
                      Icons.grid_view_rounded,
                      'SERVICES',
                      largeText,
                    ),
                    _item(
                      context,
                      4,
                      Icons.person_rounded,
                      'PROFILE',
                      largeText,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(top: 0, child: _primaryAction(context)),
          ],
        ),
      ),
    );
  }

  Widget _primaryAction(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final restricted = !user.canUseInteractiveFeatures;
    final label = user.role == UserRole.resident
        ? 'File a concern'
        : 'Create an announcement';
    return Semantics(
      button: true,
      label: label,
      child: ESugidPressable(
        onTap: onPrimaryAction,
        pressedScale: 0.92,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colors.surface,
                context.colors.surfaceAlt,
                context.colors.surfaceAlt,
                context.colors.surfaceAlt,
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: isDark ? 0.6 : 0.32,
                ),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: context.colors.brandStrong.withValues(
                  alpha: isDark ? 0.5 : 0.35,
                ),
                blurRadius: 22,
                spreadRadius: 1.5,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: context.colors.highlight.withValues(alpha: isDark ? 0.15 : 0.95,
                ),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3.5),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.28, 0.72, 1.0],
                colors: restricted
                    ? [
                        context.colors.disabledBackground,
                        context.colors.disabledBackground,
                        context.colors.disabledBackground,
                        context.colors.disabledBackground,
                      ]
                    : ([
                        context.colors.brand,
                        context.colors.brand,
                        context.colors.brand,
                        context.colors.brandStrong,
                            ]),
              ),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.38),
                width: 1.0,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 2,
                  child: Container(
                    width: 36,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          context.colors.surface.withValues(alpha: 0.45),
                          context.colors.surface.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Icon(
                  restricted ? Icons.lock_outline_rounded : Icons.add_rounded,
                  color: context.colors.onAccent,
                  size: restricted ? 23 : 31,
                  shadows: [
                    Shadow(
                      color: context.colors.textPrimary,
                      blurRadius: 4,
                      offset: Offset(0, 1.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    int index,
    IconData icon,
    String label,
    bool largeText,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = selectedIndex == index;
    final restricted =
        user.role == UserRole.resident &&
        !user.canUseInteractiveFeatures &&
        (index == 2 || index == 3);
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label.toLowerCase(),
        child: ESugidPressable(
          onTap: () => onSelect(index),
          pressedScale: 0.93,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: 31,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: active
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.brand,
                            context.colors.brand,
                            context.colors.brandStrong,
                                ],
                        )
                      : null,
                  color: active ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active
                        ? context.colors.border.withValues(alpha: isDark ? 0.35 : 0.45,
                          )
                        : Colors.transparent,
                    width: 1.1,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: (context.colors.brandStrong)
                                .withValues(alpha: 0.36,
                            ),
                            blurRadius: 9,
                            offset: const Offset(0, 3.5),
                          ),
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.08,
                            ),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: AnimatedScale(
                  scale: active ? 1.0 : 0.93,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    restricted ? Icons.lock_outline_rounded : icon,
                    color: active
                        ? context.colors.onAccent
                        : _itemColor(context, false, restricted: restricted),
                    size: restricted ? 19 : 20,
                    shadows: active
                        ? [
                            Shadow(
                              color: context.colors.textPrimary,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _labelStyle(context, active, restricted: restricted),
              ),
              if (!largeText)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(top: 2),
                  width: active ? 14 : 0,
                  height: 2.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: active
                        ? LinearGradient(
                            colors: [
                              context.colors.brand,
                              context.colors.brand,
                                  ],
                          )
                        : null,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: (context.colors.brandStrong)
                                  .withValues(alpha: 0.5,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle(
    BuildContext context,
    bool active, {
    bool restricted = false,
  }) {
    return GoogleFonts.outfit(
      fontSize: 9.5,
      color: _itemColor(context, active, restricted: restricted),
      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
      letterSpacing: active ? 0.35 : 0.15,
    );
  }

  Color _itemColor(
    BuildContext context,
    bool active, {
    bool restricted = false,
  }) {
    if (restricted) {
      return context.colors.textSecondary;
    }
    if (active) {
      return context.colors.textPrimary;
    }
    return context.colors.textSecondary;
  }
}
