const {test,expect}=require('@playwright/test');
const {loadAdminSession}=require('./helpers/admin-session');
const sample={id:'BC-2026-112159',kind:'complaint',complaintTrackingVersion:1,workflowVersion:0,status:'under_review',
  barangay:'Vito',barangayId:'barili_vito',residentName:'Test Resident',description:'Test complaint.',complaint:{respondentName:'Test Respondent'},hearings:[]};
async function setup(page,role='barangay_captain',record=sample) {
  await loadAdminSession(page,role);
  await page.evaluate(record=>{window.__adminSession.state.complaints=[record];window.navigateTo('complaints');},record);
}
async function deleteFromRow(page,id=sample.id) {
  await page.getByRole('button',{name:`Actions for complaint ${id}`,exact:true}).click();
  await page.getByRole('menuitem',{name:`Delete complaint ${id}`,exact:true}).click();
}
test('row menu Delete and case Delete use confirmation; cancellation makes no request',async({page})=>{
  await setup(page);let calls=0;
  await page.route('**/deleteComplaint',route=>{calls++;return route.fulfill({contentType:'application/json',body:JSON.stringify({result:{success:true,deleted:true}})});});
  await deleteFromRow(page);
  await expect(page.locator('#modalTitle')).toHaveText('Delete this complaint?');await expect(page.locator('#modalBody')).toContainText(sample.id);
  await page.getByRole('button',{name:'Keep complaint',exact:true}).click();expect(calls).toBe(0);
  await page.locator('#trackingDelete').click();await expect(page.locator('#modalBody')).toContainText('cannot be undone');
  expect(await page.evaluate(()=>window.__adminSession.state.complaints.length)).toBe(1);
});
test('deletion waits for server confirmation and preserves unrelated cases',async({page})=>{
  await setup(page,'super_admin');let release;let calls=0;
  await page.evaluate(record=>{window.__adminSession.state.complaints.push({...record,id:'BC-2026-999999'});window.navigateTo('complaints');},sample);
  await page.route('**/deleteComplaint',async route=>{calls++;expect(route.request().postDataJSON().data).toEqual({submissionId:sample.id,confirmDelete:true});await new Promise(resolve=>{release=resolve;});await route.fulfill({contentType:'application/json',body:JSON.stringify({result:{success:true,deleted:true}})});});
  await deleteFromRow(page);await page.locator('#confirmDeleteComplaint').click();
  await expect(page.locator('#adminModal')).toBeHidden();await expect.poll(()=>calls).toBe(1);
  expect(await page.evaluate(()=>window.__adminSession.state.complaints.length)).toBe(2);
  release();await expect(page.locator('.background-task--completed')).toContainText('Complaint deleted');
  expect(await page.evaluate(()=>window.__adminSession.state.complaints.map(c=>c.id))).toEqual(['BC-2026-999999']);
  await expect(page.locator('[data-delete-case="BC-2026-112159"]')).toHaveCount(0);
});
test('failed complaint deletion keeps the case and offers a retry',async({page})=>{
  await setup(page);let attempts=0;
  await page.route('**/deleteComplaint',route=>{attempts++;return route.fulfill(attempts===1?{status:503,contentType:'application/json',body:JSON.stringify({error:{status:'UNAVAILABLE',message:'Please retry'}})}:{contentType:'application/json',body:JSON.stringify({result:{success:true,deleted:true}})});});
  await deleteFromRow(page);await page.locator('#confirmDeleteComplaint').click();
  await expect(page.locator('.background-task--failed')).toBeVisible();expect(await page.evaluate(()=>window.__adminSession.state.complaints.length)).toBe(1);
  await page.getByRole('button',{name:'Retry',exact:true}).click();await expect(page.locator('.background-task--completed')).toContainText('Complaint deleted');
  expect(await page.evaluate(()=>window.__adminSession.state.complaints.length)).toBe(0);
});
test('row menu opens by keyboard, closes on Escape and outside click, and stays in the viewport',async({page})=>{
  await page.setViewportSize({width:1280,height:650});await setup(page,'super_admin');
  const toggle=page.getByRole('button',{name:`Actions for complaint ${sample.id}`,exact:true});
  const menu=page.getByRole('menu',{name:`Complaint ${sample.id} actions`,exact:true});
  await expect(page.getByRole('menuitem')).toHaveCount(0);
  await toggle.focus();await page.keyboard.press('Enter');await expect(menu).toBeVisible();
  await expect(toggle).toHaveAttribute('aria-expanded','true');
  await expect(menu.getByRole('menuitem',{name:`Open case ${sample.id}`,exact:true})).toBeFocused();
  await page.keyboard.press('ArrowDown');await expect(menu.getByRole('menuitem',{name:`Delete complaint ${sample.id}`,exact:true})).toBeFocused();
  const bounds=await menu.boundingBox();expect(bounds.x).toBeGreaterThanOrEqual(0);expect(bounds.y).toBeGreaterThanOrEqual(0);expect(bounds.y+bounds.height).toBeLessThanOrEqual(650);
  await page.keyboard.press('Escape');await expect(menu).toBeHidden();await expect(toggle).toBeFocused();
  await toggle.click();await page.locator('#complaintViewSummary').click();await expect(menu).toBeHidden();
  await toggle.click();await menu.getByRole('menuitem',{name:`Open case ${sample.id}`,exact:true}).click();
  await expect(menu).toBeHidden();await expect(page.locator('#modalTitle')).toHaveText(sample.id);
});
test('last-row menu stays visible on a narrow screen without being clipped by the table',async({page})=>{
  await page.setViewportSize({width:390,height:540});await setup(page,'super_admin');
  await page.evaluate(record=>{window.__adminSession.state.complaints=Array.from({length:7},(_,i)=>({...record,id:`BC-2026-${100000+i}`}));window.navigateTo('complaints');},sample);
  await page.getByRole('button',{name:'Actions for complaint BC-2026-100006',exact:true}).click();
  const menu=page.getByRole('menu',{name:'Complaint BC-2026-100006 actions',exact:true});await expect(menu).toBeVisible();
  const bounds=await menu.boundingBox();expect(bounds.x).toBeGreaterThanOrEqual(0);expect(bounds.x+bounds.width).toBeLessThanOrEqual(390);expect(bounds.y).toBeGreaterThanOrEqual(0);expect(bounds.y+bounds.height).toBeLessThanOrEqual(540);
  await page.screenshot({path:'output/complaint-menu-mobile.png'});
  await menu.getByRole('menuitem',{name:'Delete complaint BC-2026-100006',exact:true}).click();
  await expect(page.locator('#modalTitle')).toHaveText('Delete this complaint?');
});
test('delete is hidden from other offices, wrong barangays and non-complaint records',async({page})=>{
  await setup(page,'organization');await expect(page.locator('[data-delete-case]')).toHaveCount(0);
  await page.evaluate(record=>{window.configureRoleAccess({id:'official',role:'barangay_captain',barangay:'Poblacion',barangayId:'barili_poblacion',status:'approved'});window.__adminSession.state.complaints=[record];window.navigateTo('complaints');window.openComplaintCase(record.id);},sample);
  await expect(page.locator('[data-delete-case]')).toHaveCount(0);await expect(page.locator('#trackingDelete')).toHaveCount(0);
  await page.evaluate(()=>window.requestDeleteComplaint('BC-2026-112159'));await expect(page.locator('#confirmDeleteComplaint')).toHaveCount(0);
  await page.evaluate(record=>{window.configureRoleAccess({id:'admin',role:'super_admin',status:'approved'});window.__adminSession.state.complaints=[{...record,kind:'concern'}];window.navigateTo('complaints');window.openComplaintCase(record.id);},sample);
  await expect(page.locator('[data-delete-case]')).toHaveCount(0);await expect(page.locator('#trackingDelete')).toHaveCount(0);
});
test('delete cannot run while the same complaint has an update in progress',async({page})=>{
  await setup(page);let updates=0;let deletes=0;let release;
  await page.route('**/advanceComplaintWorkflow',async route=>{updates++;await new Promise(resolve=>{release=resolve;});await route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:{status:'UNAVAILABLE',message:'Test update stopped'}})});});
  await page.route('**/deleteComplaint',route=>{deletes++;return route.fulfill({contentType:'application/json',body:JSON.stringify({result:{success:true}})});});
  await page.evaluate(record=>window.openComplaintCase(record.id),sample);
  await page.locator('.case-secondary-actions > summary').click();
  await page.locator('[data-tracking-action="request_information"]').click();await page.locator('#trackingForm [name="reason"]').fill('Please provide more details.');await page.locator('#trackingSave').click();
  await expect.poll(()=>updates).toBe(1);
  await page.evaluate(record=>window.requestDeleteComplaint(record.id),sample);await page.locator('#confirmDeleteComplaint').click();
  expect(deletes).toBe(0);await expect(page.locator('#confirmDeleteComplaint')).toBeVisible();
  release();await expect(page.locator('.background-task--failed')).toHaveCount(1);
});
