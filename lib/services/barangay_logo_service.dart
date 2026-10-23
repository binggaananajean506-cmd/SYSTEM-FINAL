import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import '../barili_barangays.dart';
import '../submission_service.dart';

/// Identity comes from the resident verification or the receiving case record,
/// never from the account currently viewing someone else's document.
class BarangayLogoIdentity {
  const BarangayLogoIdentity({this.id, this.name});

  final String? id;
  final String? name;

  String? get canonicalName => BarangayLogos.nameFor(id: id, name: name);
  String get assetPath => BarangayLogos.assetFor(id: id, name: name);
}

/// Shared local seal registry for widgets and document/export renderers.
class BarangayLogos {
  BarangayLogos._();

  static const municipalityAsset =
      'assets/images/resident_dashboard/barili-logoo.png';
  static const _folder = 'assets/images/barangays/';

  // Keys use official names; the supplied Guiwanon seal also serves the
  // registry's official spelling, Giwanon. Original image bytes are preserved.
  static const assets = <String, String>{
    'bagakay': '${_folder}bagakay.jpg',
    'balao': '${_folder}balao.jpg',
    'bolocboloc': '${_folder}bolocboloc.jpg',
    'budbud': '${_folder}budbud.png',
    'bugtongkawayan': '${_folder}bugtong_kawayan.jpg',
    'cabcaban': '${_folder}cabcaban.jpg',
    'cagay': '${_folder}cagay.png',
    'campangga': '${_folder}campangga.jpg',
    'candugay': '${_folder}candugay.jpg',
    'dakit': '${_folder}dakit.jpg',
    'giloctog': '${_folder}giloctog.png',
    'guibuangan': '${_folder}guibuangan.jpg',
    'giwanon': '${_folder}guiwanon.jpg',
    'gunting': '${_folder}gunting.jpg',
    'hilasgasan': '${_folder}hilasgasan.jpg',
    'japitan': '${_folder}japitan.jpg',
    'kalubihan': '${_folder}kalubihan.png',
    'kangdampas': '${_folder}kangdampas.jpg',
    'luhod': '${_folder}luhod.png',
    'lupo': '${_folder}lupo.png',
    'maghanoy': '${_folder}maghanoy.png',
    'maigang': '${_folder}maigang.jpg',
    'malolos': '${_folder}malolos.jpg',
    'mantalongon': '${_folder}mantalongon.jpg',
    'mantayupan': '${_folder}mantayupan.jpg',
    'mayana': '${_folder}mayana.jpg',
    'minolos': '${_folder}minolos.jpg',
    'nabunturan': '${_folder}nabunturan.jpg',
    'nasipit': '${_folder}nasipit.jpg',
    'pancil': '${_folder}pancil.png',
    'pangpang': '${_folder}pangpang.png',
    'paril': '${_folder}paril.jpg',
    'patupat': '${_folder}patupat.jpg',
    'poblacion': '${_folder}poblacion.jpg',
    'sanrafael': '${_folder}san_rafael.jpg',
    'santaana': '${_folder}santa_ana.jpg',
    'talot': '${_folder}tal_ot.png',
    'tubod': '${_folder}tubod.jpg',
    'vito': '${_folder}vito.png',
  };

  static final _reportedMissing = <String>{};
  static final _bytes = <String, Future<Uint8List>>{};
  static final _namesByKey = {
    for (final name in bariliBarangays) _normalize(name): name,
  };

  static String _normalize(String? value) {
    var key = (value ?? '')
        .trim()
        .toLowerCase()
        .replaceFirst(
          RegExp(r'^(?:(?:barangay|brgy|bgy|barili)[\s_:.-]+)+'),
          '',
        )
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (key == 'guiwanon') key = 'giwanon';
    return key;
  }

  static String? _nameForValue(String? value) {
    final key = _normalize(value);
    return key.isEmpty ? null : _namesByKey[key];
  }

  static String? nameFor({String? id, String? name}) =>
      _nameForValue(id) ?? _nameForValue(name);

  static String assetFor({String? id, String? name}) {
    final canonical = nameFor(id: id, name: name);
    final asset = assets[_normalize(canonical)];
    if (asset != null) return asset;
    reportMissing('No local seal for ${id ?? name ?? "unspecified barangay"}');
    return municipalityAsset;
  }

  static void reportMissing(String message) {
    if (kDebugMode && _reportedMissing.add(message)) {
      debugPrint('[BarangayLogos] $message; using municipality placeholder.');
    }
  }

  static BarangayLogoIdentity forResident(User? resident) =>
      BarangayLogoIdentity(
        id: _first([resident?.verifiedBarangayId, resident?.barangayId]),
        name: resident?.barangay,
      );

  /// Null denotes a municipal/organization recipient, which must keep its
  /// existing identity even if the reporter lives in a barangay.
  static BarangayLogoIdentity? forSubmission(Submission submission) {
    final isBarangay =
        submission.isComplaint ||
        submission.recipientType == 'barangay' ||
        _first([submission.receivingBarangayId]) != null ||
        _nameForValue(submission.receivingBarangayName) != null ||
        ((submission.recipientType?.trim().isEmpty ?? true) &&
            (_nameForValue(submission.department) != null ||
                _nameForValue(submission.recipientId) != null ||
                ((submission.department?.trim().isEmpty ?? true) &&
                    nameFor(
                          id: submission.barangayId,
                          name: submission.barangay,
                        ) !=
                        null)));
    if (!isBarangay) return null;
    return BarangayLogoIdentity(
      id: _firstRecognizedId([
        submission.receivingBarangayId,
        if (!submission.isComplaint) submission.recipientId,
        submission.barangayId,
        submission.summons?['barangayId']?.toString(),
      ]),
      name: _first([
        submission.receivingBarangayName,
        if (_nameForValue(submission.department) != null) submission.department,
        submission.barangay,
        submission.summons?['barangay']?.toString(),
      ]),
    );
  }

  static String? _first(List<String?> values) {
    for (final value in values) {
      if (value?.trim().isNotEmpty == true) return value!.trim();
    }
    return null;
  }

  static String? _firstRecognizedId(List<String?> values) {
    for (final value in values) {
      if (_nameForValue(value) != null) return value!.trim();
    }
    return _first(values);
  }

  /// PDF/print code can use the very same lookup without a network request or
  /// a second mapping. Successful loads are shared across repeated exports.
  static Future<Uint8List> loadBytes({String? id, String? name}) {
    final path = assetFor(id: id, name: name);
    return _bytes.putIfAbsent(path, () async {
      ByteData data;
      try {
        data = await rootBundle.load(path);
      } catch (_) {
        reportMissing('Unable to load $path');
        data = await rootBundle.load(municipalityAsset);
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    });
  }
}
