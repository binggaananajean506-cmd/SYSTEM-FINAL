# Non-blocking web submissions

Announcement posting/drafts/edits, concern progress/information/outcome/resolution updates, complaint workflow forms and resident verification decisions should close their form immediately after local validation and show a floating activity panel. The panel stays available across internal navigation, with real upload percentages, indeterminate database-saving state, confirmed completion and persistent failure recovery. Finishing a job must not clear a newer draft, reopen an old modal or change the user's page.

Capture all fields, files, actor and target before starting asynchronous work. Keep files/drafts in this tab's memory only. A standard browser unload warning protects running or failed submissions; forcibly closing/reloading cannot keep an in-memory upload running. Logout hides the panel and completion cannot mutate a different signed-in account's state. Do not introduce browser notification permission or store private drafts/passwords in localStorage.

Completed notices expire automatically three seconds after success, including a collapsed finished header when no jobs remain. Expiry removes only that exact completed job; it must not remove newer work reusing the same case key, other running submissions, or failed submissions awaiting recovery.

Only database confirmation means success. Complaint retries reuse their operation ID/version; other non-idempotent workflows offer Review submission. Failed announcement recovery checks for an already-created post before reopening its draft, and never replaces an unrelated unsaved draft. Completed work offers an explicit View action; complaint review offers Set hearing rather than forcing the next form open. Running work for the same case is blocked while independent cases/posts can proceed concurrently.

Validate delayed success/failure, multiple jobs, exact frozen fields, retained files, duplicate prevention, recovery and retries, navigation, account changes, mobile/dark/keyboard/reduced motion. Preserve authorization and all six hearings/summons/CFA rules. Build, stage and deploy Hosting; no APK build.
