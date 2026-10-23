# Web Changes Deployment Rule

Whenever changes are made to `admin_web/` or `landing_page/`:

1. **Build and Stage**:
   - Rebuild the admin bundle: `npm.cmd --prefix admin_web run build`
   - Stage unified site: `node scripts/prepare-deploy.mjs`

2. **Always Deploy Immediately**:
   - Deploy to Firebase Hosting immediately without waiting: `firebase.cmd deploy --only hosting` (from workspace root)

3. **Verify Deployment**:
   - Confirm `https://e-sugid.web.app/` (Landing Page) and `https://e-sugid.web.app/admin` (Admin Console) are live.
