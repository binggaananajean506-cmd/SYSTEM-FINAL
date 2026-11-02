const test = require('node:test');
const assert = require('node:assert/strict');
const { cfaOptions, cfaDocument } = require('./cfa_forms');
const { planTrackingUpdate } = require('./complaint_tracking');
const actor={id:'official',name:'Captain',role:'barangay_captain'};
const ready=(lastAttendance='present')=>({kind:'complaint',status:'awaiting_cfa',complaintTrackingVersion:1,workflowVersion:10,
  hearings:Array.from({length:6},(_,i)=>({id:`h${i+1}`,number:i+1,status:'completed',outcome:'no_agreement',complainantAttendance:'present',respondentAttendance:i===5?lastAttendance:'present'}))});
const issue=(data,extra={})=>planTrackingUpdate(data,{action:'issue_cfa',operationId:'cfa-operation',expectedVersion:10,confirmEligibility:true,reason:'Checked the complete office case records.',...extra},new Date('2026-10-30T08:00:00Z'),actor);
test('20-A and 20-B remain distinct and require attendance supporting the selected form',()=>{
  const a=ready(),b=ready('absent');
  assert.deepEqual(cfaOptions(a).filter(o=>o.available).map(o=>o.form),['20-A']);
  assert.deepEqual(cfaOptions(b).filter(o=>o.available).map(o=>o.form),['20-B']);
  assert.throws(()=>issue(a,{cfaForm:'20-B',confirmUnjustifiedAbsence:true}),/attendance/);
  assert.throws(()=>issue(b,{cfaForm:'20-A'}),/attendance/);
  assert.throws(()=>issue(a),/Choose KP/);
  const result=issue(a,{cfaForm:'20-A',pangkatSecretaryName:'Maria Santos',pangkatChairName:'Juan Cruz'});
  assert.equal(result.update.cfaForm,'20-A');assert.equal(result.update.cfaGround,'failed_settlement');assert.equal(result.update.closureOutcome,'cfa_issued');
  assert.equal(result.update.cfaOfficials.secretaryName,'Maria Santos');assert.equal(result.event.details.cfaForm,'20-A');
});
test('absence alone never establishes proper notice or willful unjustified failure to attend',()=>{
  assert.throws(()=>issue(ready('absent'),{cfaForm:'20-B'}),/proper notice/);
  const result=issue(ready('absent'),{cfaForm:'20-B',confirmUnjustifiedAbsence:true});
  assert.equal(result.update.cfaGround,'respondent_nonappearance');assert.equal(result.update.cfaEligibility.unjustifiedAbsenceConfirmed,true);
  for(const attendance of ['absent','unknown']) {
    const data=ready('absent');data.hearings[5].complainantAttendance=attendance;
    assert.equal(cfaOptions(data).some(o=>o.available),false);
    assert.throws(()=>issue(data,{cfaForm:'20-B',confirmUnjustifiedAbsence:true}),/attendance/);
  }
});
test('six rounds and office confirmation remain mandatory for either form',()=>{
  for(const form of ['20-A','20-B']) {
    const data=ready(form==='20-B'?'absent':'present');data.hearings.pop();
    assert.throws(()=>issue(data,{cfaForm:form,confirmUnjustifiedAbsence:true}),/all 6/);
    assert.throws(()=>issue(ready(form==='20-B'?'absent':'present'),{cfaForm:form,confirmEligibility:false,confirmUnjustifiedAbsence:true}),/Confirm/);
  }
});
test('legacy missing attendance requires an explicit check of paper records and cannot override contrary attendance',()=>{
  const old={kind:'complaint',status:'awaiting_cfa',complaintTrackingVersion:1,workflowVersion:10,legacyCompletedHearings:6,hearings:[]};
  assert.throws(()=>issue(old,{cfaForm:'20-A'}),/paper records/);
  assert.equal(issue(old,{cfaForm:'20-A',confirmOfficeRecords:true}).update.cfaForm,'20-A');
  assert.throws(()=>issue(old,{cfaForm:'20-B',confirmOfficeRecords:true}),/proper notice/);
  const contrary=ready('absent');contrary.legacyCompletedHearings=1;contrary.hearings[5].complainantAttendance='absent';
  assert.throws(()=>issue(contrary,{cfaForm:'20-B',confirmOfficeRecords:true,confirmUnjustifiedAbsence:true}),/attendance/);
});
test('documents preserve their stored form, grounds and Pangkat signers while legacy certificates remain unchanged',()=>{
  const a=cfaDocument({cfaForm:'20-A',cfaReason:'No agreement',cfaOfficials:{secretaryName:'Maria',chairName:'Juan'}});
  const b=cfaDocument({cfaForm:'20-B',cfaReason:'Absence confirmed'});
  assert.equal(a.form,'20-A');assert.equal(b.form,'20-B');assert.equal(a.secretaryRole,'Pangkat Secretary');assert.equal(a.chairName,'Juan');
  assert.ok(!a.statements.join(' ').includes('without a valid reason'));assert.ok(b.statements.join(' ').includes('without a valid reason'));
  assert.equal(cfaDocument({cfaReason:'Previously recorded reason'}).form,'20');
});
