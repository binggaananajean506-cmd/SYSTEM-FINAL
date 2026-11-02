// DILG KP forms 20-A/20-B. Eligibility here is an application guard;
// legal findings, notice/service and Pangkat constitution must be checked by the office.
function cfaOptions(data) {
  const hearings = (data.hearings || []).filter(h => h.status === 'completed');
  const final = hearings.find(h => Number(h.number) === 6);
  const legacy = Number(data.legacyCompletedHearings || 0) > 0;
  const attended = h => h.complainantAttendance === 'present' && h.respondentAttendance === 'present' && h.outcome === 'no_agreement';
  const barangayMeeting = hearings.some(h => Number(h.number) <= 3 && attended(h));
  const missingFinal = !final && legacy;
  const failedSettlement = !!final && attended(final);
  const respondentAbsent = !!final && final.outcome === 'no_agreement' && final.complainantAttendance === 'present' && final.respondentAttendance === 'absent';
  return [
    { form: '20-A', ground: 'failed_settlement', label: 'No settlement',
      available: failedSettlement && (barangayMeeting || legacy) || missingFinal,
      needsOfficeRecords: missingFinal || failedSettlement && !barangayMeeting && legacy },
    { form: '20-B', ground: 'respondent_nonappearance', label: 'Respondent did not appear',
      available: respondentAbsent || missingFinal, needsOfficeRecords: missingFinal },
  ];
}
function cfaDocument(data) {
  const form = ['20-A', '20-B'].includes(data.cfaForm) ? data.cfaForm : '20';
  const reason = data.cfaReason || data.resolutionSummary || 'See the issuing office’s case records.';
  const statements = form === '20-A' ? [
    'The parties met before the Punong Barangay, but mediation did not settle the dispute.',
    'A Pangkat was formed. The parties also met before the Pangkat, but no settlement was reached.',
    'The complaint may now be filed with the appropriate court or government office.',
  ] : form === '20-B' ? [
    'The parties were called for mediation, but the dispute was not settled.',
    'The Punong Barangay arranged the meeting to form the Pangkat.',
    'The issuing office found that the respondent, despite proper notice, willfully failed or refused to attend the Pangkat proceedings without a valid reason.',
    'The complaint may now be filed with the appropriate court or government office.',
  ] : [
    'The barangay and lupon proceedings are recorded in the case file.',
    'The issuing office recorded the grounds shown below for this certificate.',
  ];
  return { form, reason, statements, label: form === '20-B' ? 'Respondent did not appear' : form === '20-A' ? 'No settlement' : 'Previously issued certificate',
    secretaryRole: form === '20' ? 'Lupon Secretary' : 'Pangkat Secretary',
    chairRole: form === '20' ? 'Punong Barangay / Lupon Chairman' : 'Pangkat Chairperson',
    secretaryName: data.cfaOfficials?.secretaryName || '', chairName: data.cfaOfficials?.chairName || '' };
}
module.exports = { cfaOptions, cfaDocument };
