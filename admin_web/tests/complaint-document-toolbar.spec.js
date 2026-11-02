const {test,expect}=require('@playwright/test');
const {loadAdminSession}=require('./helpers/admin-session');
const cfa={id:'BC-2026-112159',kind:'complaint',status:'cfa_issued',closureOutcome:'cfa_issued',cfaForm:'20-A',
  cfaIssuedAt:'2026-10-30T08:00:00Z',cfaReason:'No settlement after the barangay and Pangkat proceedings.',
  barangay:'Cagay',barangayId:'barili_cagay',residentName:'Test Complainant',complaint:{respondentName:'Test Respondent'}};
for(const width of [390,900,1280]) {
  test(`CFA seals load and the close button remains reachable at ${width}px`,async({page})=>{
    await page.setViewportSize({width,height:720});await loadAdminSession(page,'super_admin');
    await page.evaluate(record=>{window.__adminSession.state.complaints=[record];window.openOfficialCfaModal(record.id);},cfa);
    const close=page.locator('#officialSummonsCloseBtn');
    await expect(close).toBeVisible();
    const bounds=await close.boundingBox();expect(bounds.x).toBeGreaterThanOrEqual(0);expect(bounds.x+bounds.width).toBeLessThanOrEqual(width);expect(bounds.y+bounds.height).toBeLessThanOrEqual(720);
    await expect(page.locator('#officialSummonsNotifyBtn')).toBeVisible();
    const body=page.locator('#officialSummonsModalContent');
    await expect(body.locator('.kp-header-seal--barangay')).toHaveAttribute('src','assets/barangays/cagay.png');
    for(const seal of await body.locator('.kp-header-seal').all()) await expect.poll(()=>seal.evaluate(img=>img.naturalWidth)).toBeGreaterThan(0);
    const left=await body.locator('.kp-header-seal--barangay').boundingBox();const right=await body.locator('.kp-header-seal--municipal').boundingBox();expect(left.x).toBeLessThan(right.x);
    for(const button of await page.locator('.official-summons-modal-header button:visible').all()) {
      const box=await button.boundingBox();expect(box.x).toBeGreaterThanOrEqual(0);expect(box.x+box.width).toBeLessThanOrEqual(width);
    }
    expect(await page.locator('#officialSummonsModalOverlay .official-report-modal-dialog').evaluate(el=>el.scrollWidth<=el.clientWidth)).toBe(true);
    if(width===390) expect(await body.evaluate(el=>el.scrollWidth>el.clientWidth)).toBe(true);
    await page.screenshot({path:`output/cfa-toolbar-${width}.png`});
    await body.evaluate(el=>{el.scrollTop=el.scrollHeight;});
    await expect(close).toBeVisible();const after=await close.boundingBox();expect(Math.abs(after.y-bounds.y)).toBeLessThan(1);
    await close.click();await expect(page.locator('#officialSummonsModalOverlay')).toBeHidden();
  });
}
test('document switching hides unavailable actions and preserves the shared close button',async({page})=>{
  await loadAdminSession(page,'super_admin');
  await page.evaluate(record=>{window.__adminSession.state.complaints=[record,{...record,id:'BC-2026-900002',status:'settled',closureOutcome:'settled',resolutionSummary:'Both parties agreed.'}];window.openOfficialCfaModal(record.id);},cfa);
  await expect(page.locator('#officialSummonsDownloadPdfBtn')).toBeVisible();await expect(page.locator('#officialSummonsNotifyBtn')).toBeVisible();
  await page.evaluate(()=>window.openOfficialKasunduanModal('BC-2026-900002'));
  await expect(page.locator('#officialSummonsDownloadPdfBtn')).toBeHidden();await expect(page.locator('#officialSummonsNotifyBtn')).toBeHidden();
  await page.locator('#officialSummonsCloseBtn').click();await expect(page.locator('#officialSummonsModalOverlay')).toBeHidden();
});
