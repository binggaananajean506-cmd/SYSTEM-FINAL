# E-Sugid Admin Simplification Plan

**Status:** Implemented locally, including the simplified staff-role model. Awaiting authenticated Firebase QA and deployment approval.  
**Prepared:** August 10, 2026  
**Implementation target:** `admin_web/`  
**Purpose:** Give the implementation model a complete, checkable specification for rebuilding the web admin as a simple, readable workspace with the approved role model and matching Firebase security boundaries.

---

## 1. Why the admin needs to change

The current admin is visually polished but difficult to scan. The same idea is often repeated as a page title, subtitle, uppercase eyebrow, card label, and helper sentence. Important controls and record values then compete with filler copy. The stylesheet also contains many interface sizes between 7px and 11px, which are not reliably readable.

The rebuild must solve four problems:

1. **Too much text:** remove decorative and repeated explanations.
2. **Small text:** make all operational text comfortably readable.
3. **Unclear terms:** replace internal or technical wording with plain terms.
4. **Too much on one screen:** show the next action first and move supporting detail into record views, tabs, drawers, or dialogs.

This is an information-architecture and usability rebuild, not only a font-size change.

---

## 2. Outcomes

After the rebuild, a staff member should be able to:

- recognize the current page immediately;
- understand which items need action without reading helper paragraphs;
- open the correct task in one click;
- read every label and value without zooming the browser;
- use the admin at 100% browser zoom on a 1366×768 display;
- use the main workflows with keyboard, mouse, or touch;
- see only the pages and records allowed for their role;
- understand status names without knowing LGU workflow jargon.

The visual theme remains E-Sugid: deep municipal green, white cards, soft green background, rounded corners, clear status colors, and the existing icon family. The existing dark-green, rounded, collapsible side menu is retained as the recognizable anchor of the admin. The content area around it will be completely recomposed.

---

## 3. Non-negotiable safeguards

The implementation must not:

- change Firestore collection names, document shapes, or stored status values solely for display copy;
- widen a query or snapshot listener to make role filtering easier in the browser;
- rely on hidden buttons as authorization;
- weaken the approved LGU, barangay, or organization permission boundaries;
- allow barangay staff to see another barangay's restricted data;
- allow service organizations to verify residents or publish outside their LGU-approved service area;
- remove a working feature merely because its current presentation is removed;
- combine emergency reports with ordinary concerns;
- add a new UI framework or large dependency;
- deploy before role, responsive, console-error, and Firebase-rule checks pass.

Use display-label adapters where a simpler term differs from the persisted status. Existing documents and mobile-client behavior must remain compatible.

---

## 4. Access model to preserve

| Area | Super Admin | LGU | Captain / Secretary | Councilor | Organization |
| --- | --- | --- | --- | --- | --- |
| Dashboard | Municipality-wide | Municipality-wide | Own barangay | Own barangay | Organization and routed tasks |
| Emergencies | All; may send alerts | All; may send alerts | Own barangay | Own barangay | Routed reports only |
| Concerns | Full | Full | Own barangay | No access | No access |
| Requests | Full | Full | No access | No access | No access |
| Announcements | Any audience; direct | Any audience; direct | Own barangay; direct | Own barangay; direct | Approved service area or all Barili; direct |
| Resident verification | All barangays | All barangays | Own barangay only | No access | No access |
| Account creation | Any staff role | Barangay and organization roles | Request lower barangay roles | No access | Request another organization user |
| Account-request approval | Yes | Yes | No | No | No |
| Reports and settings | Full | Full | Scoped reports | No access | No access |

Legacy `barangay` profiles are treated as Barangay Captain and legacy `partner`
profiles are treated as Organization Staff. New accounts use the explicit role
names shown above.

Every staff profile must remain approved before the console loads. Role, barangay, organization, audience, and emergency-routing limits must continue to be enforced by Firestore and Storage rules, not only by the interface.

---

## 5. Plain-language rules

### 5.1 Writing standard

- Use common words and short labels.
- Prefer one to four words for navigation, tabs, buttons, and statuses.
- Use sentence case: `New concerns`, not `NEW CONCERNS`.
- Begin buttons with a clear verb: `Open`, `Assign`, `Save`, `Send`, `Approve`.
- Do not use a subtitle when the page title and visible controls already explain the page.
- Do not use decorative uppercase eyebrow text above a clear heading.
- Explain consequences only where a choice could surprise the user.
- Show help beside the unfamiliar field, not as a general paragraph above the form.
- Use the same term everywhere. Do not alternate between “inbox,” “queue,” “case,” and “submission” for the same record type.
- Use friendly empty states that say what is absent: `No new concerns.`
- Error messages must say what happened and what the user can do next.

### 5.2 Required copy replacements

| Current copy | New copy or action |
| --- | --- |
| Operations Dashboard | Dashboard |
| Manage community services with clarity. | Remove |
| Emergency Center | Emergencies |
| Acknowledge incidents and publish time-sensitive public warnings. | Remove from page header |
| Concern Management | Concerns |
| Triage, assign, respond to, and resolve resident cases. | Remove from page header |
| Service Requests | Requests |
| Process document applications and resident support tickets. | Remove from page header |
| People & Organizations | People |
| Reports & Audit | Reports |
| System Settings | Settings |
| Emergency Reports (summary card) | Emergencies |
| Awaiting acknowledgement | Remove from summary card |
| New Concerns | New concerns |
| Awaiting triage | Remove from summary card |
| Service Requests (summary card) | Pending requests |
| Pending action | Remove from summary card |
| Pending Approvals | Pending reviews |
| Accounts and posts | Remove from summary card |
| Case management | Remove |
| Concern Inbox | Concerns or Needs action, depending on context |
| View all concerns | View concerns |
| Needs attention | Remove |
| Priority Queue | Needs action |
| Unacknowledged | New |
| Triage | Review |
| Review concern | Open |
| Awaiting resident | Waiting for resident |
| Resident services | Remove |
| Incoming incidents | Remove |
| Urgent communication | Remove |
| Publish Emergency Alert | Send emergency alert |
| Review & Publish Alert | Review alert |
| Public warning history | Remove |
| Service Request Inbox | Requests |
| Official LGU channel | Remove |
| Publishing history | Remove |
| Announcement library | Announcements |
| Content (announcement step) | Write |
| Audience (announcement step) | Recipients |
| Delivery (announcement step) | Send |
| Select barangays | Choose barangays |
| Publish announcement | Send announcement |
| Account administration | Remove |
| Pending verifications | User reviews |
| User directory | Users |
| Case outcomes | Remove |
| Community access | Remove |
| Department workload | Remove |
| Accountability | Remove |
| Administrator Audit Log | Activity log |
| Platform configuration | Remove |
| Service targets | Time limits |
| Concern SLA (hours) | Concern time limit |
| Helpdesk SLA (hours) | Help desk time limit |
| Document processing target (days) | Document processing time |

Keep technical values such as reference numbers available, but do not make technical terms the main instruction.

---

## 6. Readability and accessibility standard

### 6.1 Type sizes

The following are minimum rendered sizes, not suggestions:

| Element | Desktop | Small screen |
| --- | --- | --- |
| Page title | 30–32px | 26–28px |
| Section title | 22–24px | 20–22px |
| Card count | 30–34px | 28–32px |
| Body, input, button, navigation | 16px | 16px |
| Table content | 15px | 15–16px |
| Field label, table heading | 14px | 14px |
| Secondary metadata | 13px | 13px |

No operational text may render below 13px. Remove the current 7–11px declarations from functional UI. Brand artwork may use smaller decorative text only if it is not needed to understand or operate the system.

Use a body line height of 1.5 or more. Use weight and spacing before reducing font size to fit content.

### 6.2 Interaction and visual access

- Meet WCAG 2.2 AA contrast: 4.5:1 for normal text and 3:1 for large text and UI boundaries.
- Use visible keyboard focus on every interactive element.
- Keep click/touch targets at least 44×44px.
- Never communicate status through color alone; pair color with a word or icon.
- Every icon-only button requires an accessible name and a visible tooltip on hover/focus.
- Place validation text next to its field and move focus to the first error on submit.
- Keep form labels visible; placeholders do not replace labels.
- Respect browser zoom to 200% without hiding actions or creating two-axis scrolling.
- Avoid all-caps UI labels and excessive letter spacing.

---

## 7. Complete revamp direction and global shell

### 7.1 What “complete revamp” means

This must produce a visibly new admin web application, not the current page with larger fonts and deleted subtitles.

Retain:

- the existing dark-green side menu treatment, rounded outer corners, icon style, hover/collapse behavior, and E-Sugid identity;
- the green/white/soft-mint color family;
- the current Firebase-backed workflows and permissions;
- clear visual correspondence with the resident mobile app.

Replace:

- the complete main-content layout of every page;
- the current dashboard card/panel arrangement;
- dense always-visible forms;
- repeated panel headings and eyebrow labels;
- tiny tables and metadata;
- duplicated summaries, queues, and charts;
- page-specific one-off spacing and sizing.

Use a 12-column responsive content grid with consistent 24–32px desktop gutters and 16px small-screen gutters. Pages should use substantial whitespace and fewer, larger surfaces. Content hierarchy should come from position, size, and proximity—not extra explanatory text.

The implementation must not preserve current content markup merely because it already exists. Reuse data logic and secure query boundaries, then render that data into the new page structures described below.

### 7.2 Correspondence with the mobile app

The admin and mobile app serve opposite sides of the same workflow. The new layout must make these relationships explicit in naming, status mapping, and test coverage:

| Resident mobile area | Admin area | Shared outcome |
| --- | --- | --- |
| Home and Community Bulletin | Dashboard and Announcements | Staff updates become resident-visible bulletin content for the correct audience |
| Alerts | Emergencies | Resident emergency reports reach authorized staff; staff alerts reach targeted residents |
| Concern and My Submissions | Concerns | A submitted concern appears for LGU handling and its progress returns to the resident |
| Services and document requests | Requests | Resident applications/tickets appear in the staff queue and status changes return to mobile |
| Sign-up and profile verification | People > User reviews | Authorized staff approve the same resident or official account request |
| Resident barangay | Announcement recipients and staff scope | Barangay targeting and authorization use the same canonical barangay value |

For each workflow, implementation QA must create or identify a mobile-side record, confirm it appears in the correct authorized admin view, perform an allowed staff update, and confirm the mobile-side status or feed updates correctly.

### 7.3 Navigation content

Use this order for LGU staff:

1. Dashboard
2. Emergencies
3. Concerns
4. Requests
5. Announcements
6. People
7. Reports
8. Settings

This plan deliberately keeps eight top-level destinations. No additional top-level menu is needed:

- account reviews remain in `People`;
- announcement reviews remain in `Announcements`;
- the dashboard `Pending reviews` count links to the relevant filtered view;
- activity history remains a tab inside `Reports`;
- emergency alert creation remains an action inside `Emergencies`.

This removes redundant destination concepts without removing functionality. Role filtering stays in place: users only see authorized destinations.

Preserve the current side menu's visual design and collapsed/hover expansion behavior. The revamp may shorten labels as listed above, but must not replace the green rounded rail with a different navigation pattern. Preserve its current equal top/bottom margins, icon alignment, background blur while expanded, and automatic collapse after pointer exit or page selection. Add accessible labels/tooltips and equivalent keyboard/focus expansion so hover is not the only way to discover labels. On tablet/mobile, use the existing menu concept as a drawer. Opening it must not shift the page or leave an invisible overlay.

Keep Sign out at the bottom as a simple text action with an icon. Do not style it as a competing primary button.

### 7.4 Top bar

- Left: page title only. Remove default page subtitles.
- Right: page search only on pages where it searches useful page data; otherwise omit it.
- Keep notifications and the signed-in account menu.
- Account menu contains name, role, barangay/organization when relevant, and Sign out.
- Do not repeat the account email and role in multiple places.

### 7.5 Shared page structure

Each page should normally contain:

1. page title and one primary action;
2. optional count cards only when they help choose the next task;
3. search and filters;
4. the primary list/table;
5. record details in a drawer or dialog.

Avoid nested white cards inside white cards. Use one clear container per task.

### 7.6 New page layout families

Use four deliberate layouts instead of forcing every feature into the same card grid:

1. **Action dashboard:** counts, one prioritized work list, and shortcuts.
2. **Work queue:** filters and list on the main canvas; record detail opens beside or above it.
3. **Content library:** searchable list first; creation/editing is a separate focused flow.
4. **Reports/settings:** tabbed analysis or grouped forms with no operational queue mixed in.

Conceptual dashboard structure:

```text
┌──────────────────────────────────────────────────────────────────┐
│ Dashboard                              Search   Alerts   Account │
├──────────────┬──────────────┬──────────────┬────────────────────┤
│ Emergencies  │ New concerns │ Requests     │ Pending reviews    │
├───────────────────────────────────────────┬──────────────────────┤
│                                           │ Quick actions        │
│ Needs action                              │                      │
│ Large readable rows, sorted by urgency    │ Role-aware actions   │
│                                           │ only                 │
└───────────────────────────────────────────┴──────────────────────┘
```

Conceptual work-queue structure:

```text
┌──────────────────────────────────────────────────────────────────┐
│ Page title                                  Primary action       │
├──────────────────────────────────────────────────────────────────┤
│ Search                    Main filters              More filters │
├──────────────────────────────────────────────────────────────────┤
│ Readable list/table with one Open action per record              │
│ Record detail replaces or overlays part of this area when opened │
└──────────────────────────────────────────────────────────────────┘
```

---

## 8. Dashboard replacement

### 8.1 Purpose

The dashboard answers one question: **What needs my attention now?** It must not duplicate the Reports page or become a full data archive.

### 8.2 New layout

1. Header: `Dashboard` with no subtitle.
2. Four large summary cards:
   - `Emergencies`
   - `New concerns`
   - `Pending requests`
   - `Pending reviews`
3. One wide `Needs action` list, sorted by urgency and age.
4. A small role-aware `Quick actions` panel.

Remove from the dashboard:

- `Case management`, `Needs attention`, `Last seven days`, and `Accountability` eyebrow labels;
- the separate Concern Inbox and Priority Queue that repeat the same work;
- Weekly Concern Trend, because trends belong in Reports;
- Recent Admin Activity, because audit history belongs in Reports;
- filler lines under the four summary counts.

### 8.3 Needs action list

Each row shows only:

- type/icon;
- short title or resident name;
- barangay or source;
- how long it has waited in human terms;
- simple status;
- one `Open` action.

Order: new critical emergency, overdue emergency, overdue concern/request, pending review, then remaining oldest items. A count card or row opens the already-authorized source page with the correct filter. Do not duplicate records within the list.

### 8.4 Role-aware dashboard

- LGU sees all four relevant municipality counts.
- Barangay staff see their barangay emergencies, announcement work, and allowed user reviews. Do not show inaccessible concern/request cards with zeroes.
- Organizations see routed emergencies and announcement submissions/reviews. Do not show user review or municipal service cards.

### 8.5 Quick actions

Show at most three actions relevant to the role, for example:

- LGU: `Send alert`, `New announcement`, `Review users`.
- Barangay: `New announcement`, `Review users`.
- Organization: `New announcement`, `View emergencies`.

---

## 9. Page-by-page redesign

### 9.1 Emergencies

**Page title:** `Emergencies`

- Use tabs or filter chips: `New`, `In progress`, `Closed`, `All`.
- Put the report list first. Columns: `Report`, `Location`, `Reported`, `Assigned to`, `Status`, `Action`.
- Use a visible red indicator only for genuinely critical/new items.
- Open report details in a large accessible drawer/dialog with description, map/location, contact information when authorized, timeline, assignment, notes, and actions.
- Replace the always-visible alert form with one LGU-only `Send emergency alert` button. The button opens a focused form.
- Alert form sequence: title, message, severity, recipients, end time, review, send.
- Alert history follows the report list or uses an `Alerts sent` tab. Do not show two competing full-page panels.

### 9.2 Concerns

**Page title:** `Concerns`

- Keep a single main concern list.
- Filters: status, barangay, assigned office, date. Place less-used filters behind `More filters`.
- Search reference, resident, or title from one search box.
- Table columns: `Reference`, `Concern`, `Barangay`, `Assigned to`, `Status`, `Action`.
- Move timestamps, resident details, internal notes, complete history, and attachments into the concern detail view.
- Show a clear overdue badge beside the status when necessary; do not show an unexplained hour count such as `250h overdue` as the main label.
- Display statuses as: `New`, `Reviewed`, `Assigned`, `In progress`, `Waiting for resident`, `Resolved`, `Rejected`, `Reopened`. Keep stored status values unchanged.
- Primary row action is `Open`.
- Detail actions must be presented in workflow order and disabled with an explanation when not currently valid.

### 9.3 Requests

**Page title:** `Requests`

- Keep two clear tabs: `Documents` and `Help desk`.
- Do not repeat “service request,” “resident service,” and “inbox” above the same list.
- Documents columns: `Reference`, `Applicant`, `Document`, `Submitted`, `Status`, `Action`. Move payment detail into the record unless it requires immediate action.
- Help desk columns: `Ticket`, `Resident`, `Subject`, `Updated`, `Status`, `Action`. Show priority only when it differs from normal.
- Record details provide the full workflow, notes, payment, files, and history.

### 9.4 Announcements

**Page title:** `Announcements`

- Make this list-first. The primary button is `New announcement`.
- Show the announcement list with tabs: `Published`, `Scheduled`, `Drafts`, `For review`, `Archived`.
- Hide tabs that are not meaningful for the current role.
- Columns: `Announcement`, `Status`, `Sent by`, `Recipients`, `Date`, `Action`.
- Open creation in a dedicated view or wide dialog instead of keeping a large three-column form permanently on screen.

The creation flow has three short steps:

1. **Write:** category, title, message, optional image.
2. **Recipients:** all Barili or chosen barangays, within the publisher's permitted scope.
3. **Send:** send now/schedule, importance, optional end date, notification choice.

Use `Back` and `Next` between steps. The final action is `Send announcement` or `Submit for review` according to role. Show one plain explanation for restricted roles:

- Barangay: `This will be sent only to [Barangay].`
- Organization: `LGU staff will review this before it is sent.`

Do not show a recipient estimate unless it comes from reliable current data. Do not reintroduce the removed mobile preview.

### 9.5 People

**Page title:** `People`

- LGU tabs: `User reviews`, `Users`, `Organizations`.
- Barangay staff only see allowed `User reviews`; if only one view is available, remove the tab bar entirely.
- Review columns: `Name`, `Requested role`, `Barangay/organization`, `Submitted`, `Status`, `Action`.
- Users columns: `Name`, `Role`, `Barangay/organization`, `Status`, `Action`.
- Put submitted documents and approval/rejection controls in the detail dialog.
- Require a reason for rejection and show the consequence before confirmation.
- Do not expose email, ID images, or other personal data in the table when it is not needed for the immediate decision.

### 9.6 Reports

**Page title:** `Reports`

- Put a readable date range and `Export` action at the top.
- Use simple chart names: `Concerns by status`, `Users by role`, `Concerns by office`.
- Provide a short accessible summary or table for each chart.
- Put `Activity log` in a separate tab so operational reports and accountability records do not compete.
- Activity columns: `Date`, `Staff member`, `Action`, `Item`, `Reference`.
- Remove decorative chart eyebrow labels.

### 9.7 Settings

**Page title:** `Settings`

- Use three sections: `Municipality`, `Time limits`, `Announcement rules`.
- Use plain field names from the copy table.
- Show units beside or inside fields (`hours`, `days`) rather than relying only on the label.
- Explain moderation switches with one short consequence sentence.
- Keep organization review mandatory and disabled, but explain: `Organization announcements always need LGU review.`
- Use a visible save bar only when values changed. Confirm success without reloading the page.

### 9.8 Sign-in

- Keep `Staff sign in`.
- Remove marketing or filler copy not needed to identify the system.
- Keep clear email/password labels, password visibility control, `Sign in`, loading state, and actionable access errors.
- Use at least 16px text in both inputs to remain readable and avoid mobile browser zoom.

---

## 10. Shared component rules

### Summary cards

- One icon, one label, one number.
- No subtitle unless it changes the meaning of the number.
- Entire card may be clickable when it has one clear destination.
- Preserve visible keyboard focus and an accessible name.

### Tables and lists

- Use readable headers, no uppercase 8–10px text.
- Default to 15px row text and comfortable row height.
- Avoid more than six visible columns.
- Keep the first identifying column visible and meaningful.
- Use one main row action; put secondary actions inside the detail view or overflow menu.
- Include loading, empty, error, and permission-denied states.
- On narrow screens, convert rows to stacked record cards rather than forcing horizontal scrolling.
- Paginate long collections and preserve search/filter state.

### Forms

- Group fields by the decision being made.
- Use a single-column form by default; use two columns only for short related fields on wide screens.
- Put required markers and validation in a consistent place.
- Do not put three independent workflows side by side.
- Keep primary and secondary actions visually distinct.
- Confirm destructive or irreversible actions in plain language.

### Dialogs and drawers

- Use a dialog for short decisions and a drawer/dedicated page for long record details.
- Title identifies the record or action; remove modal eyebrow filler.
- Trap focus, support Escape, return focus to the opener, and prevent background scroll.
- Do not close a form with unsaved edits without warning.

### Statuses

- Centralize persisted-value-to-display-label mapping.
- Use the same label and color in cards, lists, details, and charts.
- Status color must have readable text contrast and a non-color cue.

---

## 11. Responsive behavior

Verify these viewport widths at 100% zoom:

- 1440px desktop
- 1366px common laptop
- 1280px small desktop
- 1024px tablet landscape
- 768px tablet portrait
- 390px phone
- 320px minimum supported narrow screen

Required behavior:

- no clipped page titles, steps, buttons, or badges;
- no horizontal page scrolling;
- no controls pushed outside a card;
- no overlapping fixed navigation or top bar;
- sidebar labels visible by default on desktop and drawer behavior on small screens;
- summary cards wrap to 2×2 and then one column;
- tables become readable cards at the defined breakpoint;
- dialogs remain inside the viewport and scroll internally when necessary;
- browser zoom at 200% preserves all actions.

---

## 12. Implementation sequence

The implementation model should complete these phases in order and mark the checklist as it goes.

### Phase 0 — Baseline and contract

- [ ] Read this entire document before editing.
- [ ] Inspect `admin_web/index.html`, `admin_web/style.css`, and `admin_web/app.js`.
- [ ] Read the staff access matrix in `README.md` and the relevant Firebase rules/tests.
- [ ] Capture baseline screenshots for every authorized page at 1366px and 390px.
- [ ] Record current console/network errors separately from visual defects.
- [ ] List all active query/listener boundaries by role before changing rendering.
- [ ] Confirm that no unrelated user changes will be overwritten.

### Phase 1 — Foundation

- [ ] Define shared typography, spacing, radius, color, focus, and control-size tokens in `style.css`.
- [ ] Remove operational text styles below 13px.
- [ ] Build consistent page header, card, button, input, tab, filter, table, status, empty, error, dialog, and drawer styles.
- [ ] Create a centralized display-copy/status-label map in `app.js` without altering stored values.
- [ ] Preserve the current collapsed/hover side-menu interaction while adding keyboard/focus parity, tooltips, and reliable automatic collapse.
- [ ] Implement small-screen drawer behavior and accessible overlays.

### Phase 2 — Shell and dashboard

- [ ] Replace all page titles/navigation labels according to this plan.
- [ ] Remove default header subtitles and decorative eyebrow labels.
- [ ] Simplify top search and account controls.
- [ ] Rebuild role-aware summary cards.
- [ ] Replace duplicate dashboard panels with one `Needs action` list.
- [ ] Add role-aware quick actions.
- [ ] Remove charts and activity log from Dashboard while preserving them in Reports.

### Phase 3 — Operational pages

- [ ] Rebuild Emergencies and move alert creation into a focused LGU-only flow.
- [ ] Rebuild Concerns with the reduced table and full detail workflow.
- [ ] Rebuild Requests with Documents/Help desk tabs and reduced columns.
- [ ] Rebuild Announcements as list-first with a three-step creation flow.
- [ ] Rebuild People with role-aware tabs and privacy-conscious tables.
- [ ] Rebuild Reports with an Activity log tab.
- [ ] Rebuild Settings with three plain-language sections.
- [ ] Simplify Sign-in copy while preserving access verification and errors.

### Phase 4 — Role and data regression

- [ ] Test LGU page visibility, queries, actions, and direct publish behavior.
- [ ] Test barangay page visibility, own-barangay query scope, reviews, and announcements.
- [ ] Test organization page visibility, routed emergencies, publishing scope, and required review.
- [ ] Test an unapproved staff profile is denied.
- [ ] Test a resident cannot enter the staff console.
- [ ] Test direct URLs cannot reveal unauthorized page data.
- [ ] Confirm every listener is detached on sign-out and when no longer needed.
- [ ] Run one mobile-to-admin-to-mobile record round trip for announcements, concerns, requests, emergencies, and account reviews where test data and role access permit.

### Phase 5 — Accessibility and responsive QA

- [ ] Test keyboard-only navigation for sign-in, sidebar, tabs, filters, tables, forms, and dialogs.
- [ ] Test focus order, visible focus, dialog focus trap, Escape, and focus return.
- [ ] Verify accessible names for icon-only controls.
- [ ] Check text and component contrast.
- [ ] Check browser zoom at 200%.
- [ ] Test all viewport widths in Section 11.
- [ ] Test loading, empty, validation, network failure, permission denial, and success states.
- [ ] Confirm no functional interface text renders below 13px.

### Phase 6 — Verification and release

- [ ] Run JavaScript syntax checks.
- [ ] Run the repository's HTML ID/reference integrity check or equivalent targeted script.
- [ ] Run Firebase Firestore and Storage rule tests.
- [ ] Run Flutter analysis/tests to catch shared-contract regressions where relevant.
- [ ] Use Playwright for every admin page at desktop and phone widths.
- [ ] Assert no uncaught console errors or failed Firebase reads in authorized flows.
- [ ] Review the final diff for unrelated changes, duplicated styles, debug code, secrets, and generated artifacts.
- [ ] Update `README.md` only where navigation or documented behavior changed.
- [ ] Present before/after screenshots and verification results for approval.
- [ ] Deploy only after the user approves the reviewed implementation.

---

## 13. File-level guidance

### `admin_web/index.html`

- Simplify headings and static copy.
- Reorder and reduce visible page containers.
- Add accessible structure for navigation, tabs, dialogs, and drawers.
- Preserve IDs relied upon by `app.js` unless the script is changed in the same phase and all references are verified.

### `admin_web/style.css`

- Introduce a small token set and remove conflicting one-off tiny font rules.
- Keep responsive rules close to their component or in clearly ordered breakpoint sections.
- Avoid solving overflow with smaller text, hidden content, fixed heights, or arbitrary negative margins.
- Preserve the existing E-Sugid palette while meeting contrast requirements.

### `admin_web/app.js`

- Preserve authentication, role resolution, query scopes, and Firebase writes.
- Separate display wording from stored statuses.
- Update renderers to the reduced information hierarchy.
- Keep listener cleanup and error handling explicit.
- If the large file is split, extract only cohesive view/rendering responsibilities; do not perform an unrelated architecture rewrite.

### Firebase rules and indexes

- UI simplification does not require weaker rules.
- Change rules or indexes only if a confirmed authorized query cannot be expressed under the current secure model.
- Any rule change requires focused emulator tests for allow and deny cases.

---

## 14. Acceptance criteria

The rebuild is complete only when all of the following are true:

### Simplicity

- [ ] Every page has one obvious title.
- [ ] No page has a generic subtitle that repeats its purpose.
- [ ] Decorative eyebrow labels are gone.
- [ ] Summary cards contain no filler sentence.
- [ ] Dashboard records are not duplicated in two competing panels.
- [ ] Main table rows have one obvious action.
- [ ] Terms in Section 5.2 are consistently replaced.

### Readability

- [ ] Body, controls, and navigation render at 16px or larger.
- [ ] Table content renders at 15px or larger.
- [ ] Metadata never renders below 13px.
- [ ] Text remains readable at common laptop resolution and 200% zoom.
- [ ] Contrast and focus indicators meet the standard in Section 6.

### Functionality

- [ ] All existing admin workflows remain reachable.
- [ ] Role restrictions match Section 4.
- [ ] Status display changes do not migrate or corrupt stored values.
- [ ] Announcement, emergency, concern, request, review, report, and settings flows work end to end.
- [ ] Authorized pages do not produce permission-denied snapshot errors.
- [ ] Unauthorized reads and writes remain denied by rules.

### Quality

- [ ] The main content of every admin page is visibly recomposed; this is not the old layout with copy removed.
- [ ] The current dark-green rounded side menu and E-Sugid color identity remain recognizable.
- [ ] No horizontal page overflow at the required widths.
- [ ] No uncaught browser console errors in tested flows.
- [ ] Loading, empty, error, and success states are readable.
- [ ] Automated checks and manual role tests are documented honestly.
- [ ] No temporary screenshots, test credentials, logs, or generated artifacts are committed.

---

## 15. Decisions intentionally deferred

These items are outside the first simplification implementation unless the user separately approves them:

- Cebuano/Filipino localization. The new copy should be localization-friendly, but this plan uses plain English first.
- Firestore schema migrations.
- New administrator roles beyond LGU, barangay, and service organization.
- A new design framework or component library.
- Changes to the resident mobile application beyond compatibility fixes exposed by testing.
- New analytics or reporting metrics.

---

## 16. Handoff rule for the implementation model

Implement the plan as a coherent sequence, not as a broad rewrite in one pass. After each phase:

1. run the smallest relevant checks;
2. inspect the affected pages at desktop and phone widths;
3. verify all three staff roles still receive only their allowed data;
4. mark completed items in this document;
5. stop and report any required schema, permission, or product decision instead of guessing.

The key test is not whether the redesign looks empty or modern. It is whether a first-time staff member can read the screen, understand what needs action, and complete the task without decoding internal terminology.

---

## 17. Implementation record — August 10, 2026

### Completed locally

- [x] Rebuilt the content layout for all eight staff areas while retaining the E-Sugid colors and collapsible side menu.
- [x] Replaced the old navigation with Dashboard, Emergencies, Concerns, Requests, Announcements, People, Reports, and Settings.
- [x] Replaced repeated dashboard panels with one `Needs action` list and role-aware quick actions.
- [x] Reduced tables to essential columns and one primary row action.
- [x] Added focused emergency and announcement creation flows; the announcement form now uses Write, Recipients, and Send steps.
- [x] Preserved the LGU, barangay, and service-organization capability model in the interface.
- [x] Kept stored Firebase statuses separate from the simpler display labels.
- [x] Verified no horizontal overflow on the sign-in screen and all admin pages at 320, 390, 768, 1024, 1280, 1366, and 1440 pixels.
- [x] Verified the tested browser session reports no console errors or warnings.
- [x] Verified JavaScript syntax, Flutter static analysis, and the Flutter test suite.

### Required before deployment

- [ ] Run authenticated LGU, barangay, and service-organization workflow tests against Firebase.
- [ ] Run the Firestore and Storage allow/deny test suites when the local Firebase emulator runner is available.
- [ ] Confirm the final interface with the product owner, then deploy the approved build.

The implementation deliberately does not deploy itself because this plan requires an approval checkpoint after the local role, responsive, and security verification passes.
