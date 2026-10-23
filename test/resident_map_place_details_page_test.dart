import 'package:esugid/auth_service.dart';
import 'package:esugid/features/map/domain/resident_map_place.dart';
import 'package:esugid/features/map/presentation/resident_map_place_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('place details show facts, save locally, and return directions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const place = ResidentMapPlace(
      id: 'osm:N:123',
      name: 'Barili Community Clinic',
      address: 'Poblacion, Barili, Cebu',
      category: ResidentMapPlaceCategory.healthFacility,
      position: LatLng(10.1, 123.5),
      description: 'A local health facility in Barili.',
      openingHours: 'Monday to Friday',
      contact: '123-4567',
      sourceLabel: 'OpenStreetMap',
    );
    var directionsCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResidentMapPlaceDetailsPage(
                      place: place,
                      onDirections: () => directionsCount++,
                    ),
                  ),
                ),
                child: const Text('Open details'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    expect(find.text('Photo unavailable'), findsOneWidget);
    expect(find.text('Barili Community Clinic'), findsOneWidget);
    expect(find.text('Health Facilities'), findsOneWidget);
    expect(find.text('Poblacion, Barili, Cebu'), findsOneWidget);
    expect(find.text('A local health facility in Barili.'), findsOneWidget);
    expect(find.text('Hours: Monday to Friday'), findsOneWidget);
    expect(find.text('Contact: 123-4567'), findsOneWidget);
    expect(find.text('Information source: OpenStreetMap'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('map-place-save')));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('resident_map.saved_places.guest'),
      contains(place.id),
    );
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('map-place-directions')));
    await tester.pumpAndSettle();
    expect(directionsCount, 1);
    expect(find.text('Open details'), findsOneWidget);

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
