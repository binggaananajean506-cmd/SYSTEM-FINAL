import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../app/theme/app_colors.dart';
import '../auth_service.dart';
import '../community_service.dart';
import '../emergency_alarm_service.dart';
import '../emergency_alert_service.dart';

class EmergencyDetailsPage extends StatefulWidget {
  final String emergencyId;

  const EmergencyDetailsPage({super.key, required this.emergencyId});

  @override
  State<EmergencyDetailsPage> createState() => _EmergencyDetailsPageState();
}

class _EmergencyDetailsPageState extends State<EmergencyDetailsPage> {
  CommunityAlert? _cachedAlert;
  bool _acknowledging = false;
  bool _acknowledgementQueued = false;
  String _effectiveEmergencyId = '';

  @override
  void initState() {
    super.initState();
    _effectiveEmergencyId = widget.emergencyId.trim();
    if (_effectiveEmergencyId.isNotEmpty) {
      _stopAlarms(_effectiveEmergencyId);
      unawaited(_loadAndMarkOpened(_effectiveEmergencyId));
    } else {
      unawaited(_resolveEmergencyId());
    }
  }

  void _stopAlarms(String id) {
    if (id.isEmpty) return;
    unawaited(EmergencyAlarmService.stopAlarm(emergencyId: id));
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        const MethodChannel('com.esugid.barili/notifications')
            .invokeMethod<void>('stopEmergencyAlarm', {'referenceId': id})
            .catchError((_) {}),
      );
    }
  }

  Future<void> _resolveEmergencyId() async {
    try {
      final active =
          await EmergencyAlertService.getActiveEmergenciesForResident();
      if (active.isNotEmpty && mounted) {
        final first = active.first;
        setState(() {
          _effectiveEmergencyId = first.id;
          _cachedAlert = first;
        });
        _stopAlarms(_effectiveEmergencyId);
        unawaited(_loadAndMarkOpened(_effectiveEmergencyId));
      }
    } catch (_) {}
  }

  Future<void> _loadAndMarkOpened(String id) async {
    if (id.isEmpty) return;
    final cached = await EmergencyAlertService.loadCachedAlert(id);
    if (mounted && cached != null) setState(() => _cachedAlert = cached);
    try {
      await EmergencyAlertService.markOpened(id);
    } catch (_) {
      // The details remain readable from Firestore cache while offline.
    }
  }

  Future<void> _refresh() async {
    if (_effectiveEmergencyId.isEmpty) {
      await _resolveEmergencyId();
      return;
    }
    final alert = await EmergencyAlertService.fetchAlert(
      _effectiveEmergencyId,
      serverOnly: true,
    );
    if (mounted && alert != null) setState(() => _cachedAlert = alert);
    await EmergencyAlertService.retryPendingAcknowledgements();
  }

  Future<void> _acknowledge() async {
    if (_acknowledging || _effectiveEmergencyId.isEmpty) return;
    setState(() => _acknowledging = true);
    await EmergencyAlarmService.stopAlarm(emergencyId: _effectiveEmergencyId);
    try {
      final result = await EmergencyAlertService.acknowledge(
        _effectiveEmergencyId,
      );
      if (!mounted) return;
      setState(() {
        _acknowledgementQueued =
            result == EmergencyAcknowledgementResult.queuedOffline;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showAppSnackBar(
          AppSnackBar(
            content: Text(
                    result == EmergencyAcknowledgementResult.synchronized
                        ? 'Your acknowledgement was recorded. Reminders stopped.'
                        : 'Acknowledgement saved on device. It will sync online.',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
            kind: FeedbackKind.success,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text(
            'Unable to acknowledge this alert right now. Please try again.',
          ),
          kind: FeedbackKind.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  Future<void> _doNotRemindAgain() async {
    if (_effectiveEmergencyId.isEmpty) return;
    await EmergencyAlarmService.stopAlarm(emergencyId: _effectiveEmergencyId);
    try {
      await EmergencyAlertService.markDoNotRemind(_effectiveEmergencyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
                    'Reminders stopped for this emergency alert.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                ),
            kind: FeedbackKind.success,
          ),
        );
      }
    } catch (_) {
      await EmergencyAlertService.markSilenced(_effectiveEmergencyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    return Scaffold(
      appBar: AppBar(
        titleTextStyle: Theme.of(
          context,
        ).appBarTheme.titleTextStyle?.copyWith(color: context.colors.onAccent),

        backgroundColor: context.colors.brandStrong, // Deep civic green theme
        foregroundColor: context.colors.onAccent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: context.colors.onAccent,
            size: 22,
          ),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: context.colors.errorSolid,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.highlight,
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'BARILI CIVIC NETWORK • EMERGENCY',
                  style: GoogleFonts.outfit(
                    color: context.colors.onBrandMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Emergency Details',
              style: GoogleFonts.outfit(
                color: context.colors.onAccent,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      body: _effectiveEmergencyId.isEmpty
          ? FutureBuilder<List<CommunityAlert>>(
              future: EmergencyAlertService.getActiveEmergenciesForResident(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: context.colors.error,
                    ),
                  );
                }
                final active = snapshot.data ?? [];
                if (active.isEmpty) {
                  return const _EmergencyUnavailable();
                }
                final alert = active.first;
                return _buildAlertView(alert, user);
              },
            )
          : StreamBuilder<CommunityAlert?>(
              stream: EmergencyAlertService.watchAlert(_effectiveEmergencyId),
              initialData: _cachedAlert,
              builder: (context, alertSnapshot) {
                final alert = alertSnapshot.data ?? _cachedAlert;
                if (alert == null &&
                    alertSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: context.colors.error,
                    ),
                  );
                }
                if (alert == null) {
                  return const _EmergencyUnavailable();
                }
                return _buildAlertView(alert, user);
              },
            ),
    );
  }

  Widget _buildAlertView(CommunityAlert alert, User? user) {
    if (user == null) return const _EmergencyUnavailable();
    final effectiveId = alert.id.isNotEmpty ? alert.id : _effectiveEmergencyId;
    return StreamBuilder<ResidentEmergencyStatus?>(
      stream: EmergencyAlertService.watchResidentStatus(
        effectiveId,
        user.uid),
      builder: (context, statusSnapshot) => RefreshIndicator(
        onRefresh: _refresh,
        color: context.colors.error,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _EmergencyHeader(alert: alert),
            const SizedBox(height: 14),
            _EmergencyFacts(alert: alert),
            const SizedBox(height: 14),
            _InstructionCard(alert: alert),
            if (alert.evacuationInfo.isNotEmpty) ...[
              const SizedBox(height: 12),
              _OptionalInformationCard(
                icon: Icons.directions_walk_rounded,
                title: 'EVACUATION INFORMATION',
                value: alert.evacuationInfo,
              ),
            ],
            if (alert.emergencyContacts.isNotEmpty) ...[
              const SizedBox(height: 12),
              _OptionalInformationCard(
                icon: Icons.phone_in_talk_rounded,
                title: 'EMERGENCY CONTACT',
                value: alert.emergencyContacts,
              ),
            ],
            const SizedBox(height: 18),
            _buildResidentAction(alert, statusSnapshot.data),
          ],
        ),
      ),
    );
  }

  Widget _buildResidentAction(
    CommunityAlert alert,
    ResidentEmergencyStatus? status,
  ) {
    final state = alert.status.toLowerCase();
    if (!alert.isCurrentlyActive) {
      final message = switch (state) {
        'cancelled' => 'This emergency was cancelled.',
        'expired' => 'This emergency alert has expired.',
        _ => 'This emergency has ended.',
      };
      return _StateMessage(icon: Icons.history_rounded, message: message);
    }
    if (status?.isAcknowledged == true) {
      return const _StateMessage(
        icon: Icons.verified_rounded,
        message: 'You acknowledged this alert. Reminders are turned off.',
        success: true,
      );
    }
    if (_acknowledgementQueued) {
      return const _StateMessage(
        icon: Icons.cloud_upload_outlined,
        message: 'Acknowledgement saved on device. Waiting to sync online.',
      );
    }

    return Column(
      children: [
        // Primary Acknowledge Button
        Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [context.colors.errorSolid, context.colors.errorSolid],
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.errorSolid.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('acknowledge-emergency-button'),
              onTap: _acknowledging ? null : _acknowledge,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: _acknowledging
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: context.colors.surface,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'RECORDING…',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              color: context.colors.onAccent,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: context.colors.onAccent,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'I HAVE SEEN THIS ALERT',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              color: context.colors.onAccent,
                              fontSize: 13.5,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary "Don't Remind Again" Button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _acknowledging ? null : _doNotRemindAgain,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.error,
              side: BorderSide(color: context.colors.error, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: context.colors.surface,
            ),
            icon: Icon(
              Icons.notifications_off_outlined,
              size: 17,
              color: context.colors.error,
            ),
            label: Text(
              "Don't Remind Me Again",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: context.colors.error,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmergencyHeader extends StatelessWidget {
  final CommunityAlert alert;

  const _EmergencyHeader({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.errorSolid, context.colors.errorSolid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.errorSolid.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emergency Beacon Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: context.colors.onAccent,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'E-SUGID EMERGENCY ALERT',
                  style: GoogleFonts.outfit(
                    color: context.colors.onAccent,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            alert.title,
            style: GoogleFonts.outfit(
              color: context.colors.onAccent,
              fontSize: 23,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          if (alert.message.isNotEmpty && alert.message != alert.title) ...[
            const SizedBox(height: 8),
            Text(
              alert.message,
              style: GoogleFonts.outfit(
                color: context.colors.onAccent.withValues(alpha: 0.95),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmergencyFacts extends StatelessWidget {
  final CommunityAlert alert;

  const _EmergencyFacts({required this.alert});

  @override
  Widget build(BuildContext context) {
    final area = alert.visibility == 'public'
        ? 'All residents'
        : (alert.targetBarangays.isNotEmpty
            ? alert.targetBarangays.join(', ')
            : 'Barili community');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final issued = alert.publishedAt ?? alert.createdAt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? context.colors.border.withValues(alpha: 0.5)
              : context.colors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.25 : 0.03,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _FactRow(
            Icons.emergency_rounded,
            'Severity',
            alert.severity,
            isSeverity: true,
          ),
          Divider(
            color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                : context.colors.border,
            height: 16,
          ),
          _FactRow(
            Icons.account_balance_rounded,
            'Issued by',
            alert.sourceName,
          ),
          Divider(
            color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                : context.colors.border,
            height: 16,
          ),
          _FactRow(
            Icons.schedule_rounded,
            'Issued',
            DateFormat('MMM d, y • h:mm a').format(issued),
          ),
          Divider(
            color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                : context.colors.border,
            height: 16,
          ),
          _FactRow(Icons.location_on_rounded, 'Affected area', area),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isSeverity;

  const _FactRow(
    this.icon,
    this.label,
    this.value, {
    this.isSeverity = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 19,
          color: context.colors.error),
        const SizedBox(width: 10),
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: context.colors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: isSeverity
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.errorSolid, // Emergency red badge
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      value.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: context.colors.onAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                )
              : Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
        ),
      ],
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final CommunityAlert alert;

  const _InstructionCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return _OptionalInformationCard(
      icon: Icons.shield_rounded,
      title: 'WHAT TO DO',
      value: alert.instructions.isEmpty
          ? 'Follow instructions from local authorities and proceed to safety zones if directed.'
          : alert.instructions,
      urgent: true,
    );
  }
}

class _OptionalInformationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool urgent;

  const _OptionalInformationCard({
    required this.icon,
    required this.title,
    required this.value,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: urgent
            ? (context.colors.errorSurface)
            : (context.colors.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: urgent
              ? (context.colors.error)
              : (isDark ? context.colors.border.withValues(alpha: 0.1216)
                    : context.colors.border),
          width: urgent ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.25 : 0.03,
            ),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              color: urgent
                  ? context.colors.error
                  : (isDark ? context.colors.primaryGreen
                        : context.colors.textPrimary),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: urgent
                        ? (context.colors.error)
                        : (isDark ? context.colors.primaryGreen
                              : context.colors.textPrimary),
                    fontSize: 12,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    height: 1.45,
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool success;

  const _StateMessage({
    required this.icon,
    required this.message,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = success
        ? (context.colors.primaryGreen) : (context.colors.warning);
    final bgColor = success
        ? (context.colors.surfaceAlt) : (context.colors.warningSurface);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyUnavailable extends StatelessWidget {
  const _EmergencyUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_outlined,
                color: context.colors.primaryGreen,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Active Emergency',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no active emergency alerts currently broadcasted for your area.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                color: context.colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.maybePop(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
