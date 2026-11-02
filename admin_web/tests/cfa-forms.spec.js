const {test,expect}=require('@playwright/test');
const {loadAdminSession}=require('./helpers/admin-session');
const {planTrackingUpdate}=require('../../functions/complaint_tracking');
const {readFileSync}=require('node:fs');
for(const form of ['20-A','20-B']) {
  test(`KP ${form} saves its ground and prints/downloads the matching certificate`,async({page})=>{
    await page.setViewportSize({width:1280,height:900});
    let record={id:'BC-2026-200020',kind:'complaint',status:'awaiting_cfa',complaintTrackingVersion:1,workflowVersion:10,
      residentName:'Maria Santos',barangay:'Vito',barangayId:'barili_vito',type:'Noise',complaint:{respondentName:'Juan Cruz'},
      hearings:Array.from({length:6},(_,i)=>({id:`h${i+1}`,number:i+1,status:'completed',outcome:'no_agreement',date:`2026-10-${10+i}`,time:'09:00',venue:'Hall',complainantAttendance:'present',respondentAttendance:form==='20-B'&&i===5?'absent':'present'}))};
    let submitted;
    await loadAdminSession(page,'barangay_captain');
    await page.route('**/advanceComplaintWorkflow',async route=>{
      submitted=route.request().postDataJSON().data;
      const plan=planTrackingUpdate(record,submitted,new Date('2026-10-30T08:00:00Z'),{id:'official',name:'Official',role:'barangay_captain'});
      record={...record,...plan.update};
      await route.fulfill({contentType:'application/json',body:JSON.stringify({result:{success:true,workflowVersion:11,update:plan.update,event:plan.event}})});
    });
    await page.evaluate(record=>{window.__adminSession.state.complaints=[record];window.openComplaintCase(record.id);},record);
    await page.locator('[data-tracking-action="issue_cfa"]').click();
    const selection=page.locator('[name=cfaForm]');
    await expect(selection.locator(`option[value="${form==='20-A'?'20-B':'20-A'}"]`)).toHaveJSProperty('disabled',true);
    await selection.selectOption(form);
    await page.locator('[name=reason]').fill(form==='20-B'?'Respondent absent after proper notice, without a valid reason.':'No agreement after mediation and Pangkat conciliation.');
    await page.locator('[name=pangkatSecretaryName]').fill('Elena Reyes');
    await page.locator('[name=pangkatChairName]').fill('Pedro Ramos');
    await page.locator('[name=confirmEligibility]').check();
    if(form==='20-B') {
      await page.locator('#trackingSave').click();expect(submitted).toBeUndefined();
      await page.locator('[name=confirmUnjustifiedAbsence]').check();
    }
    await page.locator('#trackingSave').click();
    await page.getByRole('button',{name:'View case',exact:true}).click();
    expect(submitted.cfaForm).toBe(form);expect(record.cfaForm).toBe(form);
    await page.locator('[data-tracking-action="view_cfa"]').click();
    await expect(page.locator('#officialSummonsModalTitle')).toContainText(form);
    const preview=page.locator('#officialSummonsModalContent');
    await expect(preview.locator('.kp-header-seal--barangay')).toHaveAttribute('src','assets/barangays/vito.png');
    await expect(preview.locator('.kp-header-seal--municipal')).toHaveAttribute('src','assets/barili-logoo.png');
    for(const seal of await preview.locator('.kp-header-seal').all()) await expect.poll(()=>seal.evaluate(img=>img.naturalWidth)).toBeGreaterThan(0);
    await expect(page.locator('#officialSummonsNotifyBtn')).toBeVisible();
    await expect(preview).toContainText(form);await expect(preview).toContainText('PANGKAT SECRETARY');
    await expect(preview).toContainText('Elena Reyes');await expect(preview).toContainText('Pedro Ramos');
    if(form==='20-B') await expect(preview).toContainText('willfully failed or refused');
    else await expect(preview).not.toContainText('willfully failed or refused');
    await page.evaluate(()=>{window.print=()=>{window.__printedCfa=true;};});
    await page.locator('#officialSummonsPrintBtn').click();
    await expect(page.locator('#printableSummonsSheet')).toContainText(form);
    await expect(page.locator('#printableSummonsSheet .kp-header-seal')).toHaveCount(2);
    const downloadPromise=page.waitForEvent('download');await page.locator('#officialSummonsDownloadPdfBtn').click();
    const download=await downloadPromise;const pdf=readFileSync(await download.path(),'latin1');
    expect(pdf).toContain(form);expect(pdf).toContain('Elena Reyes');expect(pdf).toContain('Pedro Ramos');expect(pdf).toContain('Pangkat Secretary');
    expect((pdf.match(/\/Subtype \/Image/g)||[]).length).toBeGreaterThanOrEqual(2);
  });
}
