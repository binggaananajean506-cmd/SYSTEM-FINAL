# Mobile UI fixes and device verification

User request: repair invisible concern-calendar dates, low-contrast Bayanihan
actions and market layout, restrict barangay seals to forms/documents, improve
page/keyboard motion, and perform a quick visual UI pass.

- Preserve current sources in output/ui-polish-2026-10-17/baseline; no Git writes.
- Reproduce and fix calendar typography/state contrast and compact-sheet layout.
- Fix Bayanihan button contrast and marketplace long-name/action overflow.
- Remove decorative barangay seals from navigation, feeds, headers and publisher
  avatars; retain form letterheads, document previews/exports and seal assets.
- Inspect shared navigation and keyboard inset rebuilds; verify listener/rebuild
  counts with controlled regressions and check transitions/IME on the emulator.
  The initial phone HWUI sample reported zero frames for the controlled run and
  cannot support a Flutter FPS comparison; do not present it as one.
- Run focused regressions and full Flutter suite; analyze changed sources.
- Build and inspect the updated app on an Android emulator (user changed the
  verification target after initial phone setup; no further phone changes).
  Quick pass covers concern form/calendar, home/barangay, market and Bayanihan,
  light/dark appearance and compact/larger-text layouts using local fixtures.
- No real concern, listing, offer, message or emergency will be submitted during
  verification. Web is outside scope unless shared web files actually need edits;
  any web edit requires the full mandatory deployment pipeline.

Known environment: Flutter D:/Apps/Flutter; Android SDK D:/Apps/AndroidSDK;
JDK D:/Apps/Java; paired phone currently adb transport 2. Working root is
D:/Downloads/esugid; historical nested copy is archived outside this project.

Completed 2026-10-18: calendar/actions/layout/seal/motion changes implemented;
641 full-suite tests passed, plus 29 focused checks after the final modal handle
adjustment. Android profile build and emulator fixture checks passed. Final actual
app installed and launched on emulator-5554. Emulator window reset to (100, 40)
at scale 0.2 to fit on-screen. User must complete initial permission setup and
sign in for live account testing. Full evidence and limitations:
`output/ui-polish-2026-10-17/README.md`.

Signed-in follow-up completed 2026-10-18: live account screens checked; fixed
status-bar contrast on shared green headers and the concern form, plus the
duplicate My Listings Manage-sheet handle. Final suite: 643 passed; focused
regressions: 54 passed; analysis: no issues. Latest profile APK installed with
sign-in preserved. No production concern/listing/offer/message was submitted.
