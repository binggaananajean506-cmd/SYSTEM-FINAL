const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const {HttpsError}=require('firebase-functions/v2/https');
const {createHash}=require('node:crypto');
const {planTrackingUpdate,checkTrackingOperation}=require('./complaint_tracking');
const {isComplaint,validComplaintReference}=require('./complaint_helpers');
const {summonsBarangay}=require('./summons_officials');
const source=fs.readFileSync(require.resolve('./index.js'),'utf8');
const now=new Date('2026-10-30T08:00:00Z');
const base=()=>({kind:'complaint',status:'closed',closureOutcome:'cfa_issued',cfaForm:'20-A',cfaIssuedAt:'2026-10-30T07:00:00Z',
  workflowVersion:10,complaintTrackingVersion:1,barangayId:'barili_vito',barangay:'Vito',userId:'resident',reporterIds:['resident'],hearings:[],resolutionSummary:'No agreement.'});
const input=()=>({submissionId:'BC-2026-112159',action:'notify_cfa',message:'Your CFA has been issued. Please contact the barangay office.',expectedVersion:10,operationId:'cfa-notice-operation-123456'});
function callable({record=base(),role='barangay_captain',barangay='Vito',allowed=true}={}) {
  const docs=new Map([['submissions/BC-2026-112159',record]]);const writes=[];let sequence=0;
  const ref=path=>({path,collection:name=>({doc:id=>ref(`${path}/${name}/${id||++sequence}`)})});
  const scope={exports:{},REGION:'asia-southeast1',onCall:(_,fn)=>fn,HttpsError,createHash,isComplaint,validComplaintReference,
    canonicalRole:value=>value,summonsBarangay,planTrackingUpdate,checkTrackingOperation,
    BARANGAY_CONCERN_ROLES:new Set(['barangay_captain','barangay_vice_captain','barangay_secretary','barangay_councilor']),
    approvedCaller:async()=>({id:'official',role,barangay,name:'Test Official'}),actorCan:async()=>allowed,
    Timestamp:{now:()=>({toDate:()=>now})},FieldValue:{arrayUnion:event=>({event}),serverTimestamp:()=> 'server-time'},
    console:{info:()=>{}},
    db:{collection:name=>({doc:id=>ref(`${name}/${id||++sequence}`)}),runTransaction:async run=>{
      const staged=[];const result=await run({get:async ref=>({exists:docs.has(ref.path),data:()=>docs.get(ref.path)}),
        set:(ref,value)=>staged.push({path:ref.path,value}),update:(ref,value)=>staged.push({path:ref.path,value,merge:true})});
      for(const write of staged) {docs.set(write.path,write.merge?{...docs.get(write.path),...write.value}:write.value);writes.push(write);}return result;
    }},
  };
  vm.runInNewContext(source.match(/^function queueWebNotification\([^]*?^}/m)[0]+'\n'+source.slice(source.indexOf('exports.advanceComplaintWorkflow =')),scope);
  return {run:data=>scope.exports.advanceComplaintWorkflow({data}),writes,docs};
}
test('only an issued CFA can be notified and it never reopens or reschedules the case',()=>{
  for(const form of ['20-A','20-B']) {
    const data={...base(),cfaForm:form};const plan=planTrackingUpdate(data,input(),now,{id:'official',name:'Captain',role:'barangay_captain'});
    assert.equal(plan.update.status,undefined);assert.equal(plan.update.hearings,undefined);assert.equal(plan.update.closureOutcome,undefined);
    assert.equal(plan.update.cfaLastNotifiedBy,'official');assert.equal(plan.title,'Certificate to File Action ready');assert.equal(plan.event.details.cfaForm,form);
  }
  for(const record of [{...base(),status:'filed',closureOutcome:undefined},{...base(),closureOutcome:'settled'}]) assert.throws(()=>planTrackingUpdate(record,input(),now,{id:'official'}),/Issue a CFA/);
  assert.throws(()=>planTrackingUpdate(base(),{...input(),message:'x'.repeat(1001)},now,{id:'official'}),/CFA notice/);
  assert.throws(()=>planTrackingUpdate(base(),{...input(),action:'schedule_hearing'},now,{id:'official'}),/finished/);
});
test('actual callable commits an in-app notice, audit and durable phone alert once for retryable delivery',async()=>{
  const h=callable();const request=input();assert.equal((await h.run(request)).success,true);
  const notices=h.writes.filter(w=>w.path.startsWith('notifications/'));assert.equal(notices.length,1);assert.equal(notices[0].value.userId,'resident');
  assert.equal(notices[0].value.referenceId,request.submissionId);assert.equal(notices[0].value.title,'Certificate to File Action ready');assert.equal(notices[0].value.message,request.message);
  assert.equal(h.writes.filter(w=>w.path.startsWith('web_notification_outbox/')).length,1);
  assert.ok(h.writes.some(w=>w.value.action==='complaint_tracking_notify_cfa'));
  assert.equal(h.docs.get('submissions/BC-2026-112159').status,'closed');
  const count=h.writes.length;assert.equal((await h.run(request)).success,true);assert.equal(h.writes.length,count);
  await assert.rejects(h.run({...request,message:'Changed message'}),{code:'already-exists'});
});
test('actual callable rejects unauthorized, wrong-barangay and unlinked cases without writes',async()=>{
  for(const config of [{role:'resident'},{role:'organization'},{barangay:'Poblacion'},{allowed:false}]) {
    const h=callable(config);await assert.rejects(h.run(input()),{code:'permission-denied'});assert.equal(h.writes.length,0);
  }
  const h=callable({record:{...base(),userId:undefined,reporterIds:[]}});
  await assert.rejects(h.run(input()),{code:'failed-precondition'});assert.equal(h.writes.length,0);
});
