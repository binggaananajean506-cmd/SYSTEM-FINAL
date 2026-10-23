# Barangay seals

The Flutter app bundles the 38 supplied seals in `assets/images/barangays/`.
JPEG/JFIF files keep their original bytes under `.jpg` filenames; PNGs retain
their original transparency. Do not invert, stretch, or clip the seals.

`lib/services/barangay_logo_service.dart` is the only asset mapping. It accepts
stable IDs (`barili_vito`), recipient IDs (`barangay-barili_vito`), names and
legacy prefixes. Case, repeated spaces, underscores and hyphens are normalized.
Guiwanon also resolves to the registry's official Giwanon name.

- `BarangayLogos.forResident(user)` prefers the verified barangay ID.
- `BarangayLogos.forSubmission(submission)` uses stored receiving/case identity,
  independently of the viewer. Organization recipients retain their own branding.
- `BarangayLogo` renders the full seal with `BoxFit.contain`, accessible labels,
  display-density decoding and a safe municipality fallback.
- `BarangayLogos.loadBytes(id: ..., name: ...)` supplies the same local asset to
  document renderers. The Flutter app currently has no PDF/print export feature;
  adding one must reuse this helper, rather than introduce another mapping.

Azucena, Cagay, Luyo and Sayaw have no supplied image and use the Municipality
of Barili placeholder. Missing mappings/assets are reported once in debug mode.
To add a seal, bundle the image in the same folder and extend the central map.
Keep only IDs/names in stored records; never upload these assets to Firestore.

Verification: `flutter test test/barangay_logo_test.dart`.
