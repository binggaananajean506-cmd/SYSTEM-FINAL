const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const { canDeleteConcernRecord } = require('./concern_cleanup');
const { BARILI_BARANGAYS, barangayIdFor } = require('./verification_helpers');
const { HttpsError } = require('firebase-functions/v2/https');
const source = fs.readFileSync(require.resolve('./index.js'), 'utf8');

test('cleanup is restricted to administrators and leaders in their own barangay across all 42', () => {
  for (const barangay of BARILI_BARANGAYS) {
    const id = barangayIdFor(barangay);
    for (const role of ['barangay_captain','barangay_vice_captain','barangay_secretary']) {
      assert.equal(canDeleteConcernRecord({role,actorBarangayId:id,concernBarangayId:id,kind:'concern'}),true);
      assert.equal(canDeleteConcernRecord({role,actorBarangayId:id.replace(/^barili_/,''),concernBarangayId:id,kind:'concern'}),true);
      assert.equal(canDeleteConcernRecord({role,actorBarangayId:id,concernBarangayId:'other-barangay',kind:'concern'}),false);
      assert.equal(canDeleteConcernRecord({role,actorBarangayId:id,concernBarangayId:'',kind:'concern'}),false);
    }
  }
  for (const role of ['resident','organization','mayor','lgu','barangay_councilor']) assert.equal(canDeleteConcernRecord({role,actorBarangayId:'barili_vito',concernBarangayId:'barili_vito',kind:'concern'}),false);
  assert.equal(canDeleteConcernRecord({role:'super_admin',kind:'concern'}),true);
  assert.equal(canDeleteConcernRecord({role:'super_admin',kind:'complaint'}),false);
  assert.equal(canDeleteConcernRecord({role:'super_admin',kind:'document_request'}),false);
});

function callable({role='barangay_captain',barangayId='barili_vito',kind='concern',allowed=true,exists=true,receipt}={}) {
  const writes=[];
  const ref = path => ({path});
  const context = {
    exports:{}, REGION:'asia-southeast1',onCall:(_,fn)=>fn,HttpsError,
    approvedCaller:async()=>({id:'official',role,barangayId:'barili_vito'}),actorCan:async()=>allowed,
    validConcernReference:id=>id,canonicalRole:role=>role,effectiveBarangayId:item=>item.barangayId||'',canDeleteConcernRecord,
    FieldValue:{serverTimestamp:()=> 'server-time'},
    db:{collection:name=>({doc:id=>ref(`${name}/${id}`)}),runTransaction:async run=>run({
      get:async target=>target.path.startsWith('audit_logs/')?{exists:!!receipt,data:()=>receipt}:{exists,data:()=>({kind,barangayId,title:'Nonsense report',status:'new'})},
      set:(target,data)=>writes.push({op:'set',path:target.path,data}),delete:target=>writes.push({op:'delete',path:target.path}),
    })},
  };
  const start=source.indexOf('exports.deleteConcern =');const end=source.indexOf('exports.reviewConcern =',start);
  vm.runInNewContext(source.slice(start,end),context);
  return {run:context.exports.deleteConcern,writes};
}
test('actual delete callable removes record and public summary with an audit entry',async()=>{
  const h=callable(); const result=await h.run({data:{submissionId:'CON-2026-123456',confirmDelete:true}});
  assert.equal(result.success,true);
  assert.deepEqual(h.writes.filter(w=>w.op==='delete').map(w=>w.path),['submissions/CON-2026-123456','public_concern_summaries/CON-2026-123456']);
  assert.equal(h.writes.find(w=>w.op==='set').data.action,'concern_deleted');
});
test('actual callable rejects unconfirmed, revoked, cross-barangay, unauthorized and complaint deletions before writes',async()=>{
  for(const config of [{role:'resident'},{role:'organization'},{barangayId:'barili_poblacion'},{kind:'complaint'},{allowed:false}]) {
    const h=callable(config); await assert.rejects(h.run({data:{submissionId:'CON-2026-123456',confirmDelete:true}}),{code:'permission-denied'});
    assert.equal(h.writes.length,0);
  }
  const h=callable();await assert.rejects(h.run({data:{submissionId:'CON-2026-123456'}}),{code:'invalid-argument'});assert.equal(h.writes.length,0);
});
test('a retry after committed deletion is safe for the original actor',async()=>{
  const h=callable({exists:false,receipt:{actorId:'official'}});
  assert.equal((await h.run({data:{submissionId:'CON-2026-123456',confirmDelete:true}})).success,true);assert.equal(h.writes.length,0);
  await assert.rejects(callable({exists:false,receipt:{actorId:'different-official'}}).run({data:{submissionId:'CON-2026-123456',confirmDelete:true}}),{code:'not-found'});
});
