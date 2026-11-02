const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');
const { instrumentAdminBundle } = require('./helpers/admin-bundle');
const { planTrackingUpdate } = require('../../functions/complaint_tracking');

test('same-day past rescheduling stays in form; future Philippine time saves attendance and the next round',async({page})=>{
  await page.clock.setFixedTime(new Date('2026-10-30T06:09:00Z'));
  await loadAdminSession(page,'barangay_captain');
  let record={id:'BC-2026-112159',kind:'complaint',complaintTrackingVersion:1,workflowVersion:0,status:'hearing_scheduled',barangay:'Vito',barangayId:'barili_vito',residentName:'Test Resident',complaint:{respondentName:'Test Respondent'},hearings:[{id:'first-hearing',number:1,status:'scheduled',date:'2026-10-30',time:'11:21',venue:'Barangay Hall'}]};
  let requests=0;
  await page.route('**/advanceComplaintWorkflow',async route=>{
    requests++;const input=route.request().postDataJSON().data;
    const plan=planTrackingUpdate(record,input,new Date('2026-10-30T06:09:00Z'),{id:'official',name:'Captain',role:'barangay_captain'});
    record={...record,...plan.update};
    await route.fulfill({contentType:'application/json',body:JSON.stringify({result:{success:true,update:plan.update,event:plan.event,workflowVersion:record.workflowVersion}})});
  });
  await page.evaluate(record=>{window.__adminSession.state.complaints=[record];window.openComplaintCase(record.id);},record);
  await page.locator('[data-tracking-action="record_result"]').click();
  await page.locator('[name="outcome"][value="no_agreement"]').check();
  await page.locator('[name=respondentAttendance]').uncheck();
  await page.locator('[name=summary]').fill('Respondent was absent.');await page.locator('#trackingSave').click();
  await page.getByRole('button',{name:'Schedule next hearing',exact:true}).click();
  await expect(page.locator('[name=date]')).toHaveValue('');await expect(page.locator('[name=time]')).toHaveValue('');
  await page.locator('[name=date]').fill('2026-10-30');await page.locator('[name=time]').fill('09:00');
  await page.locator('#trackingSave').click();
  await expect(page.locator('#trackingError')).toContainText('Choose a future hearing');expect(requests).toBe(1);
  expect(record.hearings[0].complainantAttendance).toBe('present');expect(record.hearings[0].respondentAttendance).toBe('absent');
  await page.locator('[name=time]').fill('15:00');await page.locator('#trackingSave').click();
  await expect(page.locator('.background-task--completed')).toContainText('Complaint update saved');expect(requests).toBe(2);
  expect(record.hearings[0].status).toBe('completed');expect(record.hearings[0].respondentAttendance).toBe('absent');
  expect(record.hearings[1].number).toBe(2);expect(record.hearings[1].time).toBe('15:00');
});

async function deletionSession(page,role='barangay_captain') {
  await page.route('**/app.bundle.js*',async route=>{const response=await route.fetch();await route.fulfill({response,body:await instrumentAdminBundle('window.__cleanup = {state,auth,enhancedActionAndReportMarkup};')});});
  await page.goto('/');await page.waitForFunction(()=>!!window.__cleanup);
  await page.evaluate(async role=>{
    await window.__cleanup.auth.authStateReady();
    document.querySelector('#login-screen').hidden=true;document.querySelector('#login-screen').style.display='none';document.querySelector('#admin-dashboard').hidden=false;document.querySelector('#admin-dashboard').style.display='';
    window.configureRoleAccess({id:'official',role,barangay:'Vito',barangayId:'barili_vito',status:'approved',name:'Test Official'});
    const item={id:'CON-2026-123456',kind:'concern',title:'Test nonsense report',description:'Test concern text',status:'new',barangay:'Vito',barangayId:'barili_vito',residentName:'Resident'};
    window.__cleanup.state.concerns=[item];window.navigateTo('concerns');
    document.querySelector('#concernDetailPane').innerHTML=window.__cleanup.enhancedActionAndReportMarkup(item,[]);
    document.querySelector('#concernDetailPane').dataset.view='workspace';
    document.querySelector('#page-concerns').classList.add('show-detail');
  },role);
}
test('delete concern requires confirmation and removes only the confirmed record after server success',async({page})=>{
  await deletionSession(page);let calls=0;let release;
  await page.route('**/deleteConcern',async route=>{calls++;expect(route.request().postDataJSON().data).toEqual({submissionId:'CON-2026-123456',confirmDelete:true});await new Promise(resolve=>{release=resolve;});await route.fulfill({contentType:'application/json',body:JSON.stringify({result:{success:true,deleted:true}})});});
  await page.getByRole('button',{name:'Delete concern',exact:true}).click();
  await expect(page.locator('#modalBody')).toContainText('Test nonsense report');
  await page.getByRole('button',{name:'Keep concern',exact:true}).click();expect(calls).toBe(0);
  await page.getByRole('button',{name:'Delete concern',exact:true}).click();await page.locator('#confirmDeleteConcern').click();
  await expect(page.locator('#adminModal')).toBeHidden();
  await expect.poll(()=>calls).toBe(1);expect(await page.evaluate(()=>window.__cleanup.state.concerns.length)).toBe(1);
  release();await expect(page.locator('.background-task--completed')).toContainText('Concern deleted');
  expect(await page.evaluate(()=>window.__cleanup.state.concerns.length)).toBe(0);
});
test('failed delete retains the concern with retry available',async({page})=>{
  await deletionSession(page);await page.route('**/deleteConcern',route=>route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:{status:'UNAVAILABLE',message:'Please retry'}})}));
  await page.getByRole('button',{name:'Delete concern',exact:true}).click();await page.locator('#confirmDeleteConcern').click();
  await expect(page.locator('.background-task--failed')).toBeVisible();expect(await page.evaluate(()=>window.__cleanup.state.concerns.length)).toBe(1);
  await expect(page.getByRole('button',{name:'Retry',exact:true})).toBeVisible();
});
test('delete control is hidden from organizations and out-of-scope leaders',async({page})=>{
  await deletionSession(page,'organization');await expect(page.getByRole('button',{name:'Delete concern',exact:true})).toHaveCount(0);
  await page.evaluate(()=>{window.__cleanup.state.currentProfile.role='barangay_captain';window.__cleanup.state.currentProfile.barangayId='barili_poblacion';document.querySelector('#concernDetailPane').innerHTML=window.__cleanup.enhancedActionAndReportMarkup(window.__cleanup.state.concerns[0],[]);});
  await expect(page.getByRole('button',{name:'Delete concern',exact:true})).toHaveCount(0);
});

for (const grouped of [false, true]) {
  test(`administrator can delete from the ${grouped ? 'group report Action' : 'single report three-dot'} menu`,async({page})=>{
    await page.setViewportSize({width:1280,height:850});
    await loadAdminSession(page,'super_admin');
    await page.evaluate(grouped=>{
      window.__adminSession.state.concerns=[{id:'CON-2026-746040',kind:'concern',title:'Test water report',description:'Water service report.',category:'Water Services',status:'new',barangay:'Vito',barangayId:'barili_vito',residentName:'Test Resident',userId:'test-resident',date:'2026-10-17T12:23:00Z',reporterCount:grouped?2:1}];
      window.openBarangayConcernsByCategory('Water Services');
    },grouped);
    await page.locator(grouped?'.grouped-action-btn':'.grouped-action-btn-compact').first().click();
    const menu=page.locator('#groupActionDropdown_CON-2026-746040');
    await expect(menu.getByRole('button',{name:'Delete concern',exact:true})).toBeVisible();
    const bounds=await menu.boundingBox();expect(bounds.y).toBeGreaterThanOrEqual(0);expect(bounds.y+bounds.height).toBeLessThanOrEqual(850);
    await menu.getByRole('button',{name:'Delete concern',exact:true}).click();
    await expect(page.locator('#modalTitle')).toHaveText('Delete this concern?');
    await expect(page.locator('#modalBody')).toContainText('Test water report');
    await expect(menu).toBeHidden();
    await page.getByRole('button',{name:'Keep concern',exact:true}).click();
    expect(await page.evaluate(()=>window.__adminSession.state.concerns.length)).toBe(1);
  });
}
