const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const { HttpsError } = require('firebase-functions/v2/https');
const { canDeleteComplaintRecord } = require('./concern_cleanup');
const { validComplaintReference } = require('./complaint_helpers');
const { BARILI_BARANGAYS, barangayIdFor } = require('./verification_helpers');
const source = fs.readFileSync(require.resolve('./index.js'), 'utf8');
const input = {data:{submissionId:'BC-2026-123456',confirmDelete:true}};
function callable({role='barangay_captain',barangayId='barili_vito',kind='complaint',allowed=true,exists=true,receipt}={}) {
  const writes=[];
  const context={exports:{},REGION:'asia-southeast1',onCall:(_,fn)=>fn,HttpsError,
    approvedCaller:async()=>({id:'official',role,barangayId:'barili_vito'}),actorCan:async()=>allowed,
    canonicalRole:value=>value,effectiveBarangayId:item=>item.barangayId||'',validComplaintReference,canDeleteComplaintRecord,
    FieldValue:{serverTimestamp:()=> 'server-time'},
    db:{collection:name=>({doc:id=>({path:`${name}/${id}`})}),runTransaction:async run=>run({
      get:async target=>target.path.startsWith('audit_logs/')?{exists:!!receipt,data:()=>receipt}:{exists,data:()=>({kind,barangayId,status:'filed'})},
      set:(target,data)=>writes.push({op:'set',path:target.path,data}),delete:target=>writes.push({op:'delete',path:target.path}),
    })},
  };
  vm.runInNewContext(source.slice(source.indexOf('exports.deleteComplaint ='),source.indexOf('exports.deleteConcern =')),context);
  return {run:context.exports.deleteComplaint,writes};
}
test('complaint cleanup uses the same leader scope as concerns across all 42 barangays',()=>{
  for(const barangay of BARILI_BARANGAYS) {
    const id=barangayIdFor(barangay);
    for(const role of ['barangay_captain','barangay_vice_captain','barangay_secretary']) {
      assert.equal(canDeleteComplaintRecord({role,actorBarangayId:id.replace(/^barili_/,''),concernBarangayId:id,kind:'complaint'}),true);
      assert.equal(canDeleteComplaintRecord({role,actorBarangayId:'other',concernBarangayId:id,kind:'complaint'}),false);
    }
  }
  assert.equal(canDeleteComplaintRecord({role:'super_admin',kind:'complaint'}),true);
  for(const kind of ['concern','document_request','']) assert.equal(canDeleteComplaintRecord({role:'super_admin',kind}),false);
  for(const role of ['resident','organization','mayor','lgu','barangay_councilor']) assert.equal(canDeleteComplaintRecord({role,actorBarangayId:'vito',concernBarangayId:'vito',kind:'complaint'}),false);
});
test('actual callable atomically deletes only the selected case and records an audit receipt',async()=>{
  const h=callable();assert.equal((await h.run(input)).deleted,true);
  assert.deepEqual(h.writes.map(w=>w.path),['audit_logs/complaint_deleted_BC-2026-123456','submissions/BC-2026-123456']);
  assert.equal(h.writes[0].data.action,'complaint_deleted');assert.equal(h.writes[0].data.actorId,'official');
});
test('unconfirmed, malformed, revoked, unauthorized and cross-barangay requests never delete',async()=>{
  for(const config of [{role:'resident'},{role:'organization'},{role:'barangay_councilor'},{barangayId:'barili_poblacion'},{kind:'concern'},{allowed:false}]) {
    const h=callable(config);await assert.rejects(h.run(input),{code:'permission-denied'});assert.equal(h.writes.length,0);
  }
  for(const data of [{submissionId:'BC-2026-123456'},{submissionId:'../bad',confirmDelete:true}]) {
    const h=callable();await assert.rejects(h.run({data}),{code:'invalid-argument'});assert.equal(h.writes.length,0);
  }
});
test('a lost-response retry succeeds only for the original deletion actor',async()=>{
  const h=callable({exists:false,receipt:{actorId:'official'}});assert.equal((await h.run(input)).success,true);assert.equal(h.writes.length,0);
  await assert.rejects(callable({exists:false,receipt:{actorId:'other'}}).run(input),{code:'not-found'});
  await assert.rejects(callable({exists:false}).run(input),{code:'not-found'});
});
