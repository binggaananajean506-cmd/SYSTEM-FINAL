import 'dart:ui' as ui show ImageFilter, Path;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/esugid_page_header.dart';

class ChurchInfo {
  final String name;
  final String location;
  final String type;
  final String description;
  final LatLng position;
  final String imageUrl;

  const ChurchInfo({
    required this.name,
    required this.location,
    required this.type,
    required this.description,
    required this.position,
    required this.imageUrl,
  });
}

const List<ChurchInfo> _bariliChurches = [
  ChurchInfo(
    name: 'St. Anne Parish Church',
    location: 'Poblacion, Barili, Cebu',
    type: 'Parish Church (Catholic)',
    description:
        'Founded in 1848, this historic landmark features massive stone walls and a neoclassical facade, standing as the spiritual heart of Barili.',
    position: LatLng(10.1105, 123.5100),
    imageUrl:
        'https://images.unsplash.com/photo-1548625361-58a9b86aa83b?q=80&w=1200',
  ),
  ChurchInfo(
    name: 'San Vicente Ferrer Parish',
    location: 'Vito, Barili, Cebu',
    type: 'Parish Church (Catholic)',
    description:
        'A vibrant parish serving the southern community of Barili, known for its solemn atmosphere and community-driven festivities.',
    position: LatLng(10.0460, 123.5120),
    imageUrl:
        'https://images.unsplash.com/photo-1519639476810-093b48226d9c?q=80&w=1200',
  ),
  ChurchInfo(
    name: 'Our Lady of Fatima Chapel',
    location: 'Gunting, Barili, Cebu',
    type: 'Community Chapel',
    description:
        'A serene hilltop chapel offering a peaceful place for reflection with a overlooking view of the Barili valley.',
    position: LatLng(10.0810, 123.5350),
    imageUrl:
        'https://images.unsplash.com/photo-1447958272669-9c562446304f?q=80&w=1200',
  ),
  ChurchInfo(
    name: 'San Roque Chapel',
    location: 'Japitan, Barili, Cebu',
    type: 'Community Chapel',
    description:
        'Located near the coast, this chapel is a beacon of faith for the local fishermen and their families in Japitan.',
    position: LatLng(10.0958, 123.5238),
    imageUrl:
        'https://images.unsplash.com/photo-1478147427282-58a87a120781?q=80&w=1200',
  ),
  ChurchInfo(
    name: 'Sto. Niño Chapel',
    location: 'Mantalongon, Barili, Cebu',
    type: 'Community Chapel',
    description:
        'Serving the highland community, this chapel celebrates the Holy Child with deep devotion and traditional Cebuano faith.',
    position: LatLng(10.1120, 123.5520),
    imageUrl:
        'https://images.unsplash.com/photo-1545620846-51203b5f79ca?q=80&w=1200',
  ),
];

class ChurchesPage extends StatefulWidget {
  const ChurchesPage({super.key});

  @override
  State<ChurchesPage> createState() => _ChurchesPageState();
}

class _ChurchesPageState extends State<ChurchesPage> {
  final MapController _mapController = MapController();
  int _selectedIndex = 0;

  void _scrollToIndex(int index) {
    setState(() => _selectedIndex = index);
    _mapController.move(_bariliChurches[index].position, 16.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              const ESugidSliverPageHeader(
                sectionLabel: 'Explore Barili',
                title: 'Spiritual Heritage',
                subtitle: 'Churches and places of faith in Barili',
                icon: Icons.church_rounded,
                showBackButton: true,
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // 3D-effect Map Container
                    Container(
                      height: 280,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.15,
                            ),
                            blurRadius: 25,
                            offset: const Offset(0, 15),
                          ),
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(alpha: 0.1,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _bariliChurches[0].position,
                              initialZoom: 13,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.esugid',
                              ),
                              MarkerLayer(
                                markers: _bariliChurches.asMap().entries.map((
                                  entry,
                                ) {
                                  final i = entry.key;
                                  final church = entry.value;
                                  final active = _selectedIndex == i;
                                  return Marker(
                                    point: church.position,
                                    width: 80,
                                    height: 80,
                                    child: GestureDetector(
                                      onTap: () => _scrollToIndex(i),
                                      child: _build3DMarker(active),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          // Vignette overlay for depth
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.transparent,
                                    context.colors.shadow.withValues(alpha: 0.05,
                                    ),
                                    context.colors.shadow.withValues(alpha: 0.2,
                                    ),
                                  ],
                                  stops: const [0.6, 0.8, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _ChurchCard(
                      church: _bariliChurches[index],
                      isSelected: _selectedIndex == index,
                      onTap: () => _scrollToIndex(index),
                    );
                  }, childCount: _bariliChurches.length),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build3DMarker(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      transform: Matrix4.identity()
        ..scaleByDouble(active ? 1.2 : 1.0, active ? 1.2 : 1.0, 1.0, 1.0),
      transformAlignment: Alignment.bottomCenter,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Shadow
          Container(
            width: 20,
            height: 6,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          // Pin
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: active ? context.colors.brandStrong
                      : context.colors.surface,
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
                  Icons.church_rounded,
                  color: active ? context.colors.onAccent
                      : context.colors.textPrimary,
                  size: active ? 24 : 18,
                ),
              ),
              CustomPaint(
                size: const Size(12, 8),
                painter: _TrianglePainter(
                  color: active ? context.colors.brandStrong
                      : context.colors.surface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChurchCard extends StatelessWidget {
  final ChurchInfo church;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChurchCard({
    required this.church,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: context.colors.surface,
        border: Border.all(
          color: isDark ? context.colors.border : Colors.transparent,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSelected ? context.colors.brandStrong
                        : context.colors.shadow)
                .withValues(alpha: isDark ? 0.35 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with Depth Effect
              Stack(
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    foregroundDecoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          context.colors.shadow.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                    child: Image.network(church.imageUrl, fit: BoxFit.cover),
                  ),
                  // Floating Type Badge
                  Positioned(
                    top: 20,
                    left: 20,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.surface.withValues(alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: context.colors.border.withValues(alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            church.type.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: context.colors.onAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      church.name,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_pin,
                          size: 16,
                          color: context.colors.primaryGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          church.location,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: isDark
                                ? context.colors.info
                                : context.colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      church.description,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: context.colors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // 3D Styled Button
                    GestureDetector(
                      onTap: () async {
                        final url =
                            'https://www.google.com/maps/search/?api=1&query=${church.position.latitude},${church.position.longitude}';
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            colors: [
                              context.colors.brand,
                              context.colors.brand,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.brandStrong.withValues(alpha: 0.35,
                              ),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: context.colors.highlight.withValues(alpha: 0.2,
                              ),
                              blurRadius: 0,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.near_me_rounded,
                              color: context.colors.onAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'GET DIRECTIONS',
                              style: GoogleFonts.outfit(
                                color: context.colors.onAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
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
}
