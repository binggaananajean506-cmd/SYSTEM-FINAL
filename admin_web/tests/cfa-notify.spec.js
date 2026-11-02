const {test,expect}=require('@playwright/test');
const {loadAdminSession}=require('./helpers/admin-session');
const {planTrackingUpdate}=require('../../functions/complaint_tracking');
const sample=form=>({id:'BC-2026-112159',kind:'complaint',status:'closed',closureOutcome:'cfa_issued',cfaForm:form,
  cfaIssuedAt:'2026-10-30T07:00:00Z',workflowVersion:10,complaintTrackingVersion:1,
  barangay:'Vito',barangayId:'barili_vito',userId:'resident',residentName:'Maria Santos',complaint:{respondentName:'Juan Cruz'},hearings:[]});
for(const form of ['20-A','20-B']) {
  test(`${form} has its own CFA notice and keeps the case closed after sending`,async({page})=>{
    await loadAdminSession(page,'barangay_captain');let record=sample(form);const requests=[];let release;
    await page.route('**/advanceComplaintWorkflow',async route=>{
      const request=route.request().postDataJSON().data;requests.push(request);await new Promise(resolve=>{release=resolve;});
      const plan=planTrackingUpdate(record,request,new Date('2026-10-30T08:00:00Z'),{id:'official',name:'Captain',role:'barangay_captain'});record={...record,...plan.update};
      await route.fulfill({contentType:'application/json',body:JSON.stringify({result:{success:true,workflowVersion:record.workflowVersion,update:plan.update,event:plan.event}})});
    });
    await page.evaluate(record=>{window.__adminSession.state.complaints=[record];window.openOfficialCfaModal(record.id);},record);
    await page.locator('#officialSummonsNotifyBtn').click();
    await expect(page.locator('#modalTitle')).toHaveText('Notify complainant');await expect(page.locator('#cfaNoticeMessage')).toContainText(`KP Form ${form}`);
    expect(await page.locator('#cfaNoticeMessage').inputValue()).not.toMatch(/hearing|summons|tanod/i);
    await expect(page.locator('[name="date"],#complaintConfirmHandoff')).toHaveCount(0);
    await page.locator('#cfaNoticeBack').click();expect(requests).toHaveLength(0);await expect(page.locator('#officialSummonsModalOverlay')).toBeVisible();
    await page.locator('#officialSummonsNotifyBtn').click();await page.locator('#cfaNoticeSend').click();
    await expect(page.locator('#adminModal')).toBeHidden();await expect.poll(()=>requests.length).toBe(1);
    expect(requests[0].action).toBe('notify_cfa');expect(requests[0].expectedVersion).toBe(10);
    expect(await page.evaluate(()=>window.__adminSession.state.complaints[0].cfaLastNotifiedAt)).toBeUndefined();
    await page.evaluate(()=>window.navigateTo('dashboard'));release();await expect(page.locator('.background-task--completed')).toContainText('CFA notification sent');
    expect(record.status).toBe('closed');expect(record.closureOutcome).toBe('cfa_issued');expect(record.cfaForm).toBe(form);expect(record.cfaIssuedAt).toBe('2026-10-30T07:00:00Z');
    await page.getByRole('button',{name:'View CFA',exact:true}).click();await expect(page.locator('#officialSummonsModalTitle')).toContainText(form);
  });
}
test('a failed CFA notice retries the same operation and does not report success early',async({page})=>{
  await loadAdminSession(page,'barangay_captain');const record=sample('20-A');const requests=[];
  await page.route('**/advanceComplaintWorkflow',async route=>{
    const input=route.request().postDataJSON().data;requests.push(input);
    if(requests.length===1) return route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:{status:'UNAVAILABLE',message:'Please retry'}})});
    const plan=planTrackingUpdate(record,input,new Date('2026-10-30T08:00:00Z'),{id:'official',name:'Captain',role:'barangay_captain'});
    await route.fulfill({contentType:'application/json',body:JSON.stringify({result:{success:true,workflowVersion:plan.update.workflowVersion,update:plan.update,event:plan.event}})});
  });
  await page.evaluate(record=>{window.__adminSession.state.complaints=[record];window.openOfficialCfaModal(record.id);},record);
  await page.locator('#officialSummonsNotifyBtn').click();await page.locator('#cfaNoticeMessage').fill('Your CFA is ready. Contact the barangay office.');await page.locator('#cfaNoticeSend').click();
  await expect(page.locator('.background-task--failed')).toBeVisible();expect(await page.evaluate(()=>window.__adminSession.state.complaints[0].cfaLastNotifiedAt)).toBeUndefined();
  await page.getByRole('button',{name:'Retry',exact:true}).click();await expect(page.locator('.background-task--completed')).toContainText('CFA notification sent');
  expect(requests[0].operationId).toBe(requests[1].operationId);expect(requests[1].message).toBe('Your CFA is ready. Contact the barangay office.');
});
