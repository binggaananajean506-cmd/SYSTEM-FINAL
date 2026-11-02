# Project Guidelines for E-SUGID

## Mandatory Web Deployment Rule
**CRITICAL**: Whenever you make ANY changes to the web codebase (in `admin_web/` or related assets/scripts/configurations):

You **MUST ALWAYS** automatically execute the full 3-step build and deployment pipeline before ending your turn:

1. **Rebuild Admin Bundle**:
   ```powershell
   npm.cmd --prefix admin_web run build
   ```

2. **Stage Unified Hosting Directory**:
   ```powershell
   node scripts/prepare-deploy.mjs
   ```
   (This stages `landing_web/` at `/`, `admin_web/` at `/admin/`, and the current signed `output/app-release.apk` at `/downloads/app-release.apk` in `deploy_web/`. The user requested the public landing page as the front page.)

3. **Deploy to Firebase Hosting**:
   ```powershell
   firebase.cmd deploy --only hosting
   ```

4. **Verify Deployment**:
   - Check that `https://e-sugid.web.app/` serves the public landing page with HTTP 200.
   - Check that `https://e-sugid.web.app/admin` (Admin Console) is live and returns HTTP 200.
   - Check that `/downloads/app-release.apk` serves the current release and matches `release.json`.
   - Report the status to the user.

Do not wait for the user to ask you to deploy. Deploy it immediately on every edit.
