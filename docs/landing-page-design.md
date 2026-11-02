# E-SUGID public landing page

## Landing day and night modes

The public page supports a separate persisted light/dark choice, defaults to the visitor's system setting, and applies it before paint. A 44px keyboard-accessible header toggle shows the sun setting below a small horizon and the moon rising in its place. A matching decorative sun/moon beside the hero phone reinforces the change without blocking content or moving the layout. Use a deep green night palette across the gallery, FAQ, footer and image viewer. Keep original screenshot pixels and the admin theme unchanged. Use CSS transform/opacity motion tokens with reversible transitions; reduced-motion users switch immediately. No animation library or overlay is needed for this static site. Verify both modes at 320, 390 and 1440px, persisted preference, system changes, blocked storage, keyboard, rapid switching, and admin theme isolation.

The front page introduces E-SUGID to Barili residents and links to the current signed Android APK. Keep Admin Login in the header, the console at /admin, and Back to home on the login screen.

Use only the 11 distinct original app screenshots supplied by the user on October 29, 2026 for the hero and screenshot showcase. Do not use images extracted from Word documents, document montages, supplemental document links, or admin screenshot galleries. The complete allowed inventory is landing_web/showcase.json; each original JPEG lives in landing_web/assets/screenshots/. Source selections are recorded in landing-screenshot-sources.md.

The hero uses the supplied Home dashboard capture, home-dashboard.jpg. A single horizontal showcase presents Home, Updates, Report Center, Services, Emergency Alerts, Hotlines, Bayanihan, Marketplace, Assistant, Carabao Runner, and Profile as individual portrait screenshots. Keep cream backgrounds, green typography, restrained gold accents, and the existing local identity. Cards should show one complete screenshot with a short title and caption, with visible navigation and shortcuts to alerts and the game. Avoid giant image panels and nested screenshot groups.

Keep each screenshot unchanged and uncropped. Each gallery image sits inside a matching CSS phone frame with a dark rounded bezel, subtle metallic edge, side buttons, and a soft shadow. Keep the bezel outside the image and avoid any notch overlay over the screenshot. Preserve native horizontal scrolling, optional arrow buttons, and a full-size viewer with fit/zoom, previous/next, a counter, Escape dismissal, and focus return. Without JavaScript, images remain normal links to their originals. Respect reduced motion and lazy-load gallery images. Keep the existing local brand/photo assets outside the app screenshot showcase.

Build static HTML through scripts/landing-showcase.mjs and the existing Firebase staging script. Run the mandatory admin build, hosting staging, and Firebase Hosting deployment. Keep the current signed output/app-release.apk; do not build an APK for this web change.

Verify at 320x844, 390x844, and 1440x1000: all 11 images match the supplied originals, no duplicate or document images appear, old document image URLs return 404, gallery ends and modal controls work, no horizontal page overflow, keyboard and no-JavaScript access work, and admin/login/APK links remain functional. Record rendered evidence under output/landing-review/.
