import 'dart:ui' as ui;

import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/barili_barangays.dart';
import 'package:esugid/community_service.dart';
import 'package:esugid/features/complaints/complaint_modals.dart';
import 'package:esugid/models/public_civic_entity.dart';
import 'package:esugid/pages/public_entity_profile_page.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/pages/complaint_form_page.dart';
import 'package:esugid/services/barangay_logo_service.dart';
import 'package:esugid/services/publisher_avatar_service.dart';
import 'package:esugid/submission_service.dart';
import 'package:esugid/widgets/barangay_logo.dart';
import 'package:esugid/widgets/community_post_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Submission record(Map<String, dynamic> data) => Submission.fromMap({
  'id': 'concern-1',
  'date': '2026-10-01T01:00:00Z',
  'recipientType': 'barangay',
  ...data,
});

class MissingSealBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.endsWith('/vito.png')) throw StateError('Missing test asset');
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AuthService.currentUser = null);

  test(
    'stable IDs, prefixes, spacing, case and hyphens resolve consistently',
    () {
      for (final value in [
        'barili_santa_ana',
        ' BARILI_SANTA_ANA ',
        'Barangay Santa Ana',
        'BRGY.  santa   ana',
        'barangay-barili_santa_ana',
        'barangay_santa_ana',
        'barangay:Santa Ana',
        'Santa-Ana',
      ]) {
        expect(
          BarangayLogos.assetFor(id: value),
          'assets/images/barangays/santa_ana.jpg',
          reason: value,
        );
      }
      expect(
        BarangayLogos.assetFor(name: 'Tal-ot'),
        'assets/images/barangays/tal_ot.png',
      );
      expect(
        BarangayLogos.assetFor(id: 'barili_giwanon'),
        BarangayLogos.assetFor(name: 'Guiwanon'),
      );
      expect(
        BarangayLogos.assetFor(id: 'barili_cagay'),
        'assets/images/barangays/cagay.png',
      );
    },
  );

  test('known ID wins over a conflicting name, including missing seals', () {
    expect(
      BarangayLogos.assetFor(id: 'barili_vito', name: 'Pangpang'),
      endsWith('/vito.png'),
    );
    expect(
      BarangayLogos.assetFor(id: 'barili_azucena', name: 'Vito'),
      BarangayLogos.municipalityAsset,
    );
    expect(
      BarangayLogos.assetFor(id: 'legacy-opaque-id', name: 'Lupo'),
      endsWith('/lupo.png'),
    );
  });

  test('all 42 barangays use supplied seals or the municipality fallback', () {
    expect(BarangayLogos.assets, hasLength(39));
    for (final name in bariliBarangays) {
      final asset = BarangayLogos.assetFor(id: bariliBarangayId(name));
      if (['Azucena', 'Luyo', 'Sayaw'].contains(name)) {
        expect(asset, BarangayLogos.municipalityAsset);
      } else {
        expect(BarangayLogos.assets.values, contains(asset), reason: name);
      }
    }
  });

  test('missing lookup logs once and falls back without throwing', () {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? text, {int? wrapWidth}) => messages.add(text ?? '');
    try {
      for (var i = 0; i < 3; i++) {
        expect(
          BarangayLogos.assetFor(name: 'Unknown test barangay'),
          BarangayLogos.municipalityAsset,
        );
      }
      expect(messages, hasLength(1));
      expect(messages.single, contains('Unknown test barangay'));
    } finally {
      debugPrint = original;
    }
  });

  test('verified resident ID wins over profile name and unverified ID', () {
    final resident = User(
      uid: 'resident',
      email: 'resident@example.com',
      role: UserRole.resident,
      name: 'Resident',
      barangay: 'Vito',
      barangayId: 'barili_vito',
      verifiedBarangayId: 'barili_pangpang',
    );
    expect(
      BarangayLogos.forResident(resident).assetPath,
      endsWith('/pangpang.png'),
    );
  });

  test(
    'receiving IDs and case IDs drive documents independently of viewer',
    () {
      AuthService.currentUser = User(
        uid: 'viewer',
        email: 'viewer@example.com',
        role: UserRole.resident,
        name: 'Viewer',
        barangay: 'Vito',
        verifiedBarangayId: 'barili_vito',
      );
      final concern = record({
        'receivingBarangayId': 'barili_lupo',
        'barangayId': 'barili_vito',
        'department': 'Barangay Vito',
      });
      expect(
        BarangayLogos.forSubmission(concern)!.assetPath,
        endsWith('/lupo.png'),
      );
      final routed = record({
        'recipientId': 'barangay-barili_pangpang',
        'barangayId': 'barili_vito',
        'barangay': 'Vito',
      });
      expect(
        BarangayLogos.forSubmission(routed)!.assetPath,
        endsWith('/pangpang.png'),
      );
      final complaint = record({
        'kind': 'complaint',
        'barangayId': 'barili_tubod',
        'barangay': 'Vito',
        'summons': {'barangay': 'Lupo'},
      });
      expect(
        BarangayLogos.forSubmission(complaint)!.assetPath,
        endsWith('/tubod.jpg'),
      );
    },
  );

  test('legacy records fall back to stored names, never the current user', () {
    expect(
      BarangayLogos.forSubmission(
        record({'barangay': 'Barangay Lupo'}),
      )!.assetPath,
      endsWith('/lupo.png'),
    );
    expect(
      BarangayLogos.forSubmission(
        record({'recipientId': 'opaque-id', 'barangayId': 'barili_lupo'}),
      )!.assetPath,
      endsWith('/lupo.png'),
    );
    expect(
      BarangayLogos.forSubmission(record({}))!.assetPath,
      BarangayLogos.municipalityAsset,
    );
    expect(
      BarangayLogos.forSubmission(
        record({
          'recipientType': 'organization',
          'barangayId': 'barili_vito',
          'department': 'Barili MDRRMO',
        }),
      ),
      isNull,
    );
  });

  test(
    'receiving metadata survives parsing and copying without image data',
    () {
      final item = record({
        'receivingBarangayId': 'barili_lupo',
        'receivingBarangayName': 'Lupo',
      }).copyWith(title: 'Updated');
      expect(item.toMap()['receivingBarangayId'], 'barili_lupo');
      expect(item.toMap()['receivingBarangayName'], 'Lupo');
      expect(item.toMap().keys, isNot(contains('logo')));
    },
  );

  test(
    'all bundled seals and placeholder decode; document bytes share lookup',
    () async {
      for (final asset in {
        ...BarangayLogos.assets.values,
        BarangayLogos.municipalityAsset,
      }) {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0), reason: asset);
        expect(frame.image.height, greaterThan(0), reason: asset);
        frame.image.dispose();
        codec.dispose();
      }
      final expected = await rootBundle.load(
        BarangayLogos.assetFor(id: 'barili_vito'),
      );
      expect(
        await BarangayLogos.loadBytes(id: 'barili_vito'),
        expected.buffer.asUint8List(
          expected.offsetInBytes,
          expected.lengthInBytes,
        ),
      );
      expect(
        identical(
          BarangayLogos.loadBytes(id: 'barili_vito'),
          BarangayLogos.loadBytes(name: 'Vito'),
        ),
        isTrue,
      );
      expect(
        await BarangayLogos.loadBytes(name: 'Unknown export barangay'),
        isNotEmpty,
      );
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'seals contain the full image without clipping in $brightness',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(brightness),
            home: const Scaffold(body: BarangayLogo(barangayId: 'barili_vito')),
          ),
        );
        await tester.pumpAndSettle();
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.fit, BoxFit.contain);
        expect(image.semanticLabel, 'Barangay Vito seal');
        expect(
          find.ancestor(
            of: find.byType(Image),
            matching: find.byType(ClipOval),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('missing image uses the municipality placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: MissingSealBundle(),
          child: const Scaffold(body: BarangayLogo(barangayId: 'barili_vito')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Municipality of Barili seal'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'barangay publisher keeps an office icon when its identity changes',
    (tester) async {
      Widget avatar(String name) => MaterialApp(
        home: Scaffold(
          body: PublisherAvatar(barangay: name, size: 40),
        ),
      );
      await tester.pumpWidget(avatar('Vito'));
      await tester.pumpAndSettle();
      expect(find.byType(BarangayLogo), findsNothing);
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      await tester.pumpWidget(avatar('Pangpang'));
      await tester.pumpAndSettle();
      expect(find.byType(BarangayLogo), findsNothing);
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'barangay publisher does not display an uploaded seal as an avatar',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PublisherAvatar(
              barangayId: 'barili_vito',
              photoUrl: 'assets/images/barangays/vito.png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BarangayLogo), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ordinary publisher retains its uploaded profile photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PublisherAvatar(
            photoUrl:
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
            isOfficial: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    expect(find.byType(BarangayLogo), findsNothing);
    expect(find.byIcon(Icons.account_balance_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resident and organization avatars ignore the audience barangay seal cache',
    (tester) async {
      const photoUrl =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=';
      PublisherAvatarService.remember(
        'Santa Ana',
        'assets/images/barangays/santa_ana.jpg',
      );
      for (final role in ['resident', 'organization']) {
        final authorId = 'avatar-regression-$role';
        final organizationId = role == 'organization'
            ? 'avatar-regression-org'
            : '';
        PublisherAvatarService.remember(
          organizationId.isEmpty ? authorId : organizationId,
          photoUrl,
        );
        final post = CommunityPost(
          id: 'avatar-post-$role',
          title: 'Community update',
          content: 'Community update',
          authorName: 'Community publisher',
          authorId: authorId,
          authorRole: role,
          authorBarangay: 'Santa Ana',
          authorOrganizationName: '',
          publisherEntityId: organizationId,
          targetAudience: 'barangay',
          targetBarangay: 'Santa Ana',
          targetBarangays: const ['Santa Ana'],
          visibility: 'public',
          status: 'approved',
          tag: '',
          createdAt: DateTime(2026, 10, 1),
        );
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: PublisherAvatar(post: post))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BarangayLogo), findsNothing);
        expect(find.byType(Image), findsOneWidget);
        expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'municipal post targeted at a barangay keeps its publisher identity',
    (tester) async {
      final post = CommunityPost(
        id: 'municipal-post',
        title: 'Update',
        content: 'Update',
        category: 'Notice',
        authorId: 'lgu',
        authorRole: 'lgu',
        authorName: 'Municipality',
        authorOrganizationName: 'Municipality of Barili',
        authorBarangay: 'Vito',
        targetAudience: 'barangay',
        targetBarangay: 'Vito',
        targetBarangays: const ['Vito'],
        visibility: 'public',
        status: 'approved',
        tag: 'LGU',
        createdAt: DateTime(2026, 10, 1),
        authorPhotoUrl: BarangayLogos.municipalityAsset,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PublisherAvatar(post: post)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BarangayLogo), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'barangay profile shows its office icon without a seal',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PublicEntityProfilePage(
            entity: PublicCivicEntity.forBarangay('Vito'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BarangayLogo), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.location_city_rounded), findsWidgets);
      expect(find.text('Barangay Vito'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 600.0]) {
    testWidgets('summons uses stored case ID and both seals at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final complaint = record({
        'kind': 'complaint',
        'barangayId': 'barili_pangpang',
        'barangay': 'Vito',
        'summons': {
          'barangay': 'Lupo',
          'appearanceDate': '2026-11-01',
          'appearanceTime': '09:00',
        },
      });
      await tester.pumpWidget(
        MaterialApp(home: OfficialSummonsPage(complaint: complaint)),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Barangay Pangpang seal'), findsOneWidget);
      expect(find.text('BARANGAY PANGPANG'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  BarangayLogos.municipalityAsset,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'concern review letterhead uses the selected verified recipient in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AuthService.currentUser = User(
          uid: 'resident',
          email: 'resident@example.com',
          role: UserRole.resident,
          name: 'Resident',
          barangay: 'Vito',
          verifiedBarangayId: 'barili_pangpang',
          verificationStatus: VerificationStatus.verified,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(brightness),
            home: ConcernCenterPage(
              formOnly: true,
              categoryLoader: () async => [
                {
                  'id': 'public_safety',
                  'name': 'Public Safety',
                  'sector': 'public',
                },
              ],
              similarConcernChecker: (_) async => [],
              draft: {
                'id': 'logo-draft',
                'createdAt': '2026-10-01T01:00:00Z',
                'handlerType': 'barangay',
                'categoryId': 'public_safety',
                'category': 'Public Safety',
                'title': 'Street light is broken',
                'description':
                    'The street light near the hall has been broken for several days.',
                'location': 'Near the barangay hall',
                'visibility': 'public',
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var step = 0; step < 2; step++) {
          await tester.ensureVisible(find.text('Continue'));
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Review Concern'));
        await tester.tap(find.text('Review Concern'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('review-summary')), findsOneWidget);
        expect(find.bySemanticsLabel('Barangay Pangpang seal'), findsOneWidget);
        expect(find.bySemanticsLabel('Barangay Vito seal'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'complaint revision header uses the stored case in $brightness',
      (tester) async {
        AuthService.currentUser = User(
          uid: 'viewer',
          email: 'viewer@example.com',
          role: UserRole.resident,
          name: 'Viewer',
          barangay: 'Vito',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(brightness),
            home: ComplaintFormPage(
              submit: (_) async => 'unused',
              existingComplaint: record({
                'kind': 'complaint',
                'barangayId': 'barili_lupo',
                'barangay': 'Vito',
                'description': 'A complaint description.',
              }),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final header = find
            .byType(BarangayLogo)
            .evaluate()
            .map((element) => element.widget as BarangayLogo);
        expect(header, isNotEmpty);
        expect(
          header.every((logo) => logo.barangayId == 'barili_lupo'),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
