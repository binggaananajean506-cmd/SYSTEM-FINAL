const {test,expect}=require('@playwright/test');
const {loadAdminSession}=require('./helpers/admin-session');
const {planTrackingUpdate}=require('../../functions/complaint_tracking');
async function setup(page) {
  await page.clock.setFixedTime(new Date('2026-10-30T06:00:00Z'));
  await loadAdminSession(page,'barangay_captain');
  let record={id:'BC-2026-112159',kind:'complaint',complaintTrackingVersion:1,workflowVersion:0,status:'hearing_scheduled',
    barangay:'Vito',barangayId:'barili_vito',residentName:'Test Resident',description:'Test complaint.',complaint:{respondentName:'Test Respondent'},
    hearings:[{id:'hearing1',number:1,status:'scheduled',date:'2026-10-30',time:'09:00',venue:'Barangay Hall'}]};
  const inputs=[];
  await page.route('**/advanceComplaintWorkflow',async route=>{
    const input=route.request().postDataJSON().data;inputs.push(input);
    const plan=planTrackingUpdate(record,input,new Date('2026-10-30T06:00:00Z'),{id:'official',name:'Captain',role:'barangay_captain'});
    record={...record,...plan.update};
    await route.fulfill({contentType:'application/json',body:JSON.stringify({result:{success:true,workflowVersion:record.workflowVersion,update:plan.update,event:plan.event}})});
  });
  await page.evaluate(record=>{window.__adminSession.state.complaints=[record];window.navigateTo('complaints');window.openComplaintCase(record.id);},record);
  await expect(page.locator('.case-main-action button')).toHaveCount(1);
  await page.getByRole('button',{name:'Record result',exact:true}).click();
  return {inputs,record:()=>record};
}
test('Settled saves the agreement and closes the case without offering another hearing',async({page})=>{
  const h=await setup(page);
  await page.locator('[name="outcome"][value="settled"]').check();await page.locator('[name="summary"]').fill('Both parties agreed to stop the noise.');
  await page.getByRole('button',{name:'Save and close case',exact:true}).click();await page.getByRole('button',{name:'View case',exact:true}).click();
  expect(h.inputs[0].action).toBe('record_result');expect(h.record().closureOutcome).toBe('settled');
  await expect(page.locator('.case-conclusion')).toContainText('Case closed');await expect(page.locator('[data-tracking-action="schedule_another_hearing"]')).toHaveCount(0);
});
test('Not settled with both present saves the result before opening the next hearing form',async({page})=>{
  const h=await setup(page);
  await page.locator('[name="outcome"][value="no_agreement"]').check();await page.locator('[name="summary"]').fill('Both attended but did not agree.');
  await page.locator('#trackingSave').click();await page.getByRole('button',{name:'Schedule next hearing',exact:true}).click();
  expect(h.inputs[0].action).toBe('record_result');expect(h.record().status).toBe('awaiting_next_schedule');expect(h.record().hearings).toHaveLength(1);
  await expect(page.locator('#trackingForm')).toContainText('Barangay Hearing 2 of 3');await expect(page.locator('[name="date"]')).toHaveValue('');
  await expect(page.locator('[name="complainantAttendance"]')).toHaveCount(0);
});
test('an absent respondent cannot be marked settled; Not settled preserves actual absence',async({page})=>{
  const h=await setup(page);
  await page.locator('[name="respondentAttendance"]').uncheck();await page.locator('[name="outcome"][value="settled"]').check();await page.locator('[name="summary"]').fill('The respondent did not attend.');
  await page.locator('#trackingSave').click();expect(h.inputs).toHaveLength(0);await expect(page.locator('#trackingForm')).toBeVisible();
  await page.locator('[name="outcome"][value="no_agreement"]').check();await page.locator('#trackingSave').click();
  await page.getByRole('button',{name:'Schedule next hearing',exact:true}).click();
  expect(h.inputs[0].action).toBe('record_nonattendance');expect(h.inputs[0].reason).toBe('The respondent did not attend.');
  expect(h.record().hearings[0].respondentAttendance).toBe('absent');expect(h.record().status).toBe('awaiting_next_schedule');
});
