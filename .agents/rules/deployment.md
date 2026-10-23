# Web Deployment Rule

Whenever ANY changes are made to the web codebase (`landing_page/`, `admin_web/`, or related web assets/configurations):

1. **Rebuild Admin Bundle**:
   ```powershell
   npm.cmd --prefix admin_web run build
   ```

2. **Stage Unified Hosting Directory**:
   ```powershell
   node scripts/prepare-deploy.mjs
   ```
   This stages `landing_page/` at the root `/` and `admin_web/` (with `<base href="/admin/">`) at `/admin/`.

3. **Deploy to Firebase Hosting**:
   ```powershell
   firebase.cmd deploy --only hosting
   ```

4. **Verify and Report**:
   Ensure both `https://e-sugid.web.app/` (Landing Page) and `https://e-sugid.web.app/admin` (Admin Console) are live and report status to the user.
