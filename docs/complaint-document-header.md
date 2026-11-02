# Complaint document header

CFA previews and printed certificates use the same official header as summons: the case barangay seal on the left and Municipality of Barili seal on the right. CFA PDF generation embeds both seals with the same barangay resolver and municipal fallback already used by summons. Both 20-A and 20-B retain their saved form-specific text and dates.

The shared complaint-document dialog gives the title and X their own header row and wraps document actions below. The document body scrolls independently, keeping the X available even at the bottom of a long document. A minimum paper width preserves the document layout on narrow screens; horizontal scrolling stays inside the document body. Screen-only rules leave the print layout unrestricted.

Removed forced display overrides from action button styles so document-specific hide/show logic works. CFA now has a dedicated Notify complainant action, and Kasunduan does not show unrelated download/notification actions. Existing summons notification controls remain available where permitted.

The CFA notice form identifies the case, form and complainant, and previews an editable CFA-specific message. Sending uses notify_cfa in the existing authenticated complaint workflow. The server requires an issued CFA and a linked resident account, checks office scope and operation/version guards, and atomically records an audit entry, an in-app notification and a durable push outbox job. Replaying the same operation cannot duplicate notices. Notification metadata never reopens the case, changes the certificate or schedules a hearing. The existing floating submission panel supports safe retries and navigation while sending. Tests stub delivery; no production notices are sent during development.

Browser checks cover loaded barangay/municipal seals, left/right order, both CFA variants in preview/print/PDF, responsive toolbar bounds, the X after scrolling, document switching, and existing summons/logo flows.
