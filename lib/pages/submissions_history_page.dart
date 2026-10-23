import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../submission_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/esugid_page_header.dart';

class SubmissionsHistoryPage extends StatelessWidget {
  const SubmissionsHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ESugidPageHeader(
            sectionLabel: 'Account',
            title: 'My Submissions',
            subtitle: 'Track your reports and concerns.',
            icon: Icons.history_rounded,
            showBackButton: true,
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final user = AuthService.currentUser;
                if (user == null) {
                  return const Center(child: Text('Please sign in again.'));
                }
                return StreamBuilder<List<Submission>>(
                  stream: SubmissionService.submissionsForUser(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final submissions = snapshot.data ?? [];

                    if (submissions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 64,
                              color: context.colors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No submissions found',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: submissions.length,
                      itemBuilder: (context, index) {
                        final item = submissions[index];
                        return _buildSubmissionCard(context, item);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard(BuildContext context, Submission item) {
    Color statusColor;
    switch (normalizeSubmissionStatus(item.status)) {
      case 'resolved':
        statusColor = context.colors.primaryGreen;
        break;
      case 'being_handled':
        statusColor = context.colors.info;
        break;
      case 'needs_information':
        statusColor = context.colors.error;
        break;
      case 'rejected':
        statusColor = context.colors.error;
        break;
      default:
        statusColor = context.colors.warning;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (item.type == 'Complaint' ? context.colors.errorSolid
                        : context.colors.infoSolid)
                .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            item.type == 'Complaint'
                ? Icons.campaign_rounded
                : Icons.report_gmailerrorred_rounded,
            color: item.type == 'Complaint' ? context.colors.error
                : context.colors.info,
            size: 20,
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${item.id} • ${DateFormat('MMM dd, yyyy').format(item.date)}',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            item.statusLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Category', item.category),
                if (item.department != null)
                  _buildDetailRow('Department', item.department!),
                if (item.location != null && item.location!.isNotEmpty)
                  _buildDetailRow('Location', item.location!),
                const SizedBox(height: 8),
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tracking Timeline',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...item.publicStatusHistory.map((entry) => _buildTimelineEntry(context, entry),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEntry(BuildContext context, Map<String, dynamic> entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawDate = entry['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: context.colors.primaryGreen, size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  submissionStatusLabel(
                    entry['status']?.toString() ?? 'Updated',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  entry['note']?.toString() ?? '',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (date != null)
                  Text(
                    DateFormat('MMM dd, yyyy h:mm a').format(date),
                    style: TextStyle(
                      color: isDark ? context.colors.textSecondary
                          : context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
