import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/esugid_page_header.dart';
import '../widgets/notebook_binding.dart';
import '../app_motion.dart';

class SchoolInfo {
  final String name;
  final String type;
  final String location;
  final String description;
  final IconData icon;
  final LatLng position;

  const SchoolInfo({
    required this.name,
    required this.type,
    required this.location,
    required this.description,
    required this.icon,
    required this.position,
  });
}

const List<SchoolInfo> _bariliSchools = [
  SchoolInfo(
    name: 'Cebu Technological University',
    type: 'Public University • Barili Campus',
    location: 'Poblacion, Barili, Cebu',
    description:
        'The premier agricultural and technological institution in Southern Cebu, empowering Barilinons through quality education.',
    icon: Icons.account_balance_rounded,
    position: LatLng(10.1114, 123.5113),
  ),
  SchoolInfo(
    name: 'Barili National High School',
    type: 'Public Secondary',
    location: 'Poblacion, Barili, Cebu',
    description:
        'Providing accessible and quality secondary education to the youth of Barili for generations.',
    icon: Icons.school_rounded,
    position: LatLng(10.1130, 123.5120),
  ),
  SchoolInfo(
    name: 'St. Anne\'s Academy',
    type: 'Private Catholic School',
    location: 'Poblacion, Barili, Cebu',
    description:
        'A cornerstone of faith-based education in Barili, fostering academic excellence and spiritual growth.',
    icon: Icons.church_rounded,
    position: LatLng(10.1105, 123.5100),
  ),
  SchoolInfo(
    name: 'Guibuangan National High School',
    type: 'Public Secondary',
    location: 'Guibuangan, Barili, Cebu',
    description:
        'Serving the educational needs of students in the coastal barangays of Barili.',
    icon: Icons.scuba_diving_rounded,
    position: LatLng(10.1450, 123.5250),
  ),
];

class SchoolsPage extends StatefulWidget {
  const SchoolsPage({super.key});

  @override
  State<SchoolsPage> createState() => _SchoolsPageState();
}

class _SchoolsPageState extends State<SchoolsPage> {
  final MapController _mapController = MapController();
  int? _activeSchoolIndex;

  void _focusOnSchool(int index) {
    setState(() => _activeSchoolIndex = index);
    _mapController.move(_bariliSchools[index].position, 15.5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          const ESugidSliverPageHeader(
            sectionLabel: 'Explore Barili',
            title: 'Schools & Education',
            subtitle: 'Empowering the next generation of Barilinons',
            icon: Icons.school_rounded,
            showBackButton: true,
          ),

          // 3D Styled Interactive Map
          SliverToBoxAdapter(
            child: Container(
              height: 260,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.colors.border, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.brandStrong.withValues(alpha: 0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                  // Inner bevel highlight
                  BoxShadow(
                    color: context.colors.highlight.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _bariliSchools[0].position,
                      initialZoom: 13.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.esugid',
                      ),
                      MarkerLayer(
                        markers: _bariliSchools.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final school = entry.value;
                          final isActive = _activeSchoolIndex == idx;

                          return Marker(
                            point: school.position,
                            width: 80,
                            height: 80,
                            child: GestureDetector(
                              onTap: () => _focusOnSchool(idx),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                child: _build3DMarker(school, isActive),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  // Top Vignette for depth
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            context.colors.shadow.withValues(alpha: 0.1),
                            Colors.transparent,
                            Colors.transparent,
                            context.colors.shadow.withValues(alpha: 0.05),
                          ],
                          stops: const [0, 0.2, 0.8, 1],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return _SchoolNotebookCard(
                  school: _bariliSchools[index],
                  isActive: _activeSchoolIndex == index,
                  onMapFocus: () => _focusOnSchool(index),
                );
              }, childCount: _bariliSchools.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DMarker(SchoolInfo school, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? context.colors.brandStrong : context.colors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            school.icon,
            color: active ? context.colors.onAccent
                : context.colors.textPrimary,
            size: active ? 22 : 18,
          ),
        ),
        if (active) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              school.name,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

class _SchoolNotebookCard extends StatefulWidget {
  final SchoolInfo school;
  final bool isActive;
  final VoidCallback onMapFocus;

  const _SchoolNotebookCard({
    required this.school,
    required this.isActive,
    required this.onMapFocus,
  });

  @override
  State<_SchoolNotebookCard> createState() => _SchoolNotebookCardState();
}

class _SchoolNotebookCardState extends State<_SchoolNotebookCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: ESugidMotion.standard,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: ESugidMotion.enterCurve,
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 200,
      child: Stack(
        children: [
          // The Notebook Page
          Positioned.fill(
            left: 12,
            child: ESugidPressable(
              onTap: () {
                if (_rotationController.isCompleted) {
                  _rotationController.reverse();
                } else {
                  _rotationController.forward();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                  border: Border.all(
                    color: widget.isActive
                        ? (isDark
                            ? context.colors.primaryGreen.withValues(alpha: 0.6,
                                )
                            : context.colors.primaryGreen.withValues(alpha: 0.3,
                                ))
                        : (isDark ? context.colors.border : Colors.transparent),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (widget.isActive
                                  ? context.colors.brandStrong
                                  : context.colors.brandStrong)
                              .withValues(alpha: 0.08),
                      blurRadius: 15,
                      offset: const Offset(4, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 28), // Space for binding
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 20, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.school.name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: context.colors.textPrimary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      Text(
                                        widget.school.type,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: context.colors.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedBuilder(
                                  animation: _rotationAnimation,
                                  builder: (context, child) {
                                    return Transform(
                                      transform: Matrix4.identity()
                                        ..setEntry(3, 2, 0.001)
                                        ..rotateY(
                                          _rotationAnimation.value * math.pi,
                                        ),
                                      alignment: Alignment.center,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: context.colors.surfaceAlt,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: context.colors.border,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.colors.shadow
                                              .withValues(
                                            alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      widget.school.icon,
                                      color: context.colors.primaryGreen,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              widget.school.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                height: 1.4,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_rounded,
                                            size: 14,
                                            color: context.colors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget.school.location,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                _buildGetDirectionsButton(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The Binding
          const Positioned(
            left: 0,
            top: 15,
            bottom: 15,
            child: NotebookWireBinding(),
          ),
        ],
      ),
    );
  }

  Widget _buildGetDirectionsButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.brandStrong, context.colors.brand],
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          // 3D Bevel effect
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: 0.3),
            blurRadius: 0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // First focus on the map at the top
            widget.onMapFocus();

            // Then provide option to open external map
            final url =
                'https://www.google.com/maps/search/?api=1&query=${widget.school.position.latitude},${widget.school.position.longitude}';
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url));
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.near_me_rounded,
                  color: context.colors.onAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Directions',
                  style: GoogleFonts.outfit(
                    color: context.colors.onAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
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
}
