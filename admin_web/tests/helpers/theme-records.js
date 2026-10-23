async function seedThemeRecords(page) {
  await page.evaluate(() => {
    const { state, auth } = window.__adminSession;
    const date = new Date().toISOString();
    Object.defineProperty(auth, 'currentUser', { configurable: true, value: { uid: 'theme-staff', email: 'staff@example.test' } });
    state.users = [{ id: 'theme-resident', name: 'Sample Resident', role: 'resident', barangay: 'Vito', barangayId: 'vito', status: 'approved', accountStatus: 'active', email: 'resident@example.test', createdAt: date }];
    state.concerns = ['new', 'being_handled', 'needs_information', 'resolved'].map((status, index) => ({
      id: `theme-concern-${index}`, title: 'Road maintenance request', category: 'Roads', status,
      residentId: 'theme-resident', residentName: 'Sample Resident', description: 'Please inspect the damaged road near the community hall.',
      barangay: 'Vito', barangayId: 'vito', date, createdAt: date, schemaVersion: 4,
      recipientType: 'barangay', recipientId: 'vito', targetBarangay: 'Vito',
      assignedDepartmentId: 'it-department', assignedOrganizationId: 'layout-org', leadOrganizationId: 'layout-org'
    }));
    state.complaints = ['filed', 'hearing_scheduled', 'closed'].map((status, index) => ({
      id: `theme-complaint-${index}`, kind: 'complaint', complaintTrackingVersion: 1, workflowVersion: index,
      residentName: 'Sample Resident', type: 'Noise', description: 'Loud music in the evening.',
      barangay: 'Vito', barangayId: 'vito', date, createdAt: date, status,
      complaint: { respondentName: 'Sample Respondent', respondentAddress: 'Vito, Barili' },
      hearings: index === 1 ? [{ id: 'theme-hearing', number: 1, status: 'scheduled', date: date.slice(0, 10), time: '09:00', venue: 'Barangay Hall' }] : [],
      closureOutcome: index === 2 ? 'unsettled' : undefined,
    }));
    state.posts = [{ id: 'theme-post', authorId: 'theme-staff', authorRole: state.currentProfile.role, title: 'Community update', content: 'Local services are available this week.', status: 'approved', visibility: 'public', targetBarangay: 'All Barangays', targetBarangays: [], departmentId: 'it-department', organizationId: 'layout-org', barangayId: 'vito', authorBarangay: 'Vito', publishedAt: date, timestamp: date, announcementType: 'general', priority: 'regular' }];
    state.emergencies = [{ id: 'theme-emergency', type: 'Medical', title: 'Medical assistance', status: 'pending', residentName: 'Sample Resident', barangay: 'Vito', barangayId: 'vito', createdAt: date, description: 'Assistance is requested at the community hall.' }];
    state.alerts = [{ id: 'theme-alert', title: 'Weather advisory', content: 'Monitor local weather updates.', status: 'active', type: 'Weather', severity: 'warning', publishedAt: date, createdAt: date, visibility: 'public', targetBarangays: [] }];
    state.documentRequests = [{ id: 'theme-request', applicantName: 'Sample Resident', userId: 'theme-resident', type: 'Barangay Certificate', status: 'pending', paymentStatus: 'unpaid', dateSubmitted: date, barangay: 'Vito' }];
    state.accountRequests = [{ id: 'theme-account', name: 'Sample Staff', email: 'staff@example.test', role: 'barangay_secretary', barangay: 'Vito', barangayId: 'vito', status: 'pending', createdAt: date }];
    state.auditLogs = [{ id: 'theme-log', action: 'settings_updated', actorName: 'Sample Staff', createdAt: date, entityType: 'system', entityId: 'settings' }];
    state.barangayAnalyticsPosts = state.posts;
    state.barangayAnalyticsAlerts = state.alerts;
  });
}

module.exports = { seedThemeRecords };
