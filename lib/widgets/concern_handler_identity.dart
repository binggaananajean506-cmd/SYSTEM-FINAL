import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme/semantic_colors.dart';
import '../submission_service.dart';

class ConcernHandlerIdentity extends StatefulWidget {
  const ConcernHandlerIdentity({
    super.key,
    required this.concern,
    required this.progressNote,
    this.handlerLoader,
  });

  final Submission concern;
  final String progressNote;
  final Future<Map<String, dynamic>> Function(String caseId)? handlerLoader;

  @override
  State<ConcernHandlerIdentity> createState() => _ConcernHandlerIdentityState();
}

class _ConcernHandlerIdentityState extends State<ConcernHandlerIdentity> {
  String _name = '';
  String _role = '';
  int _request = 0;

  static const _roles = {
    'barangay_captain': 'Barangay Captain',
    'barangay_vice_captain': 'Barangay Vice Captain',
    'barangay_secretary': 'Barangay Secretary',
    'barangay_councilor': 'Barangay Councilor',
    'super_admin': 'Administrator',
    'lgu': 'LGU Department Staff',
    'mayor': 'Municipal Mayor',
    'organization': 'Organization Staff',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    var event = widget.concern.publicStatusHistory.reversed.firstWhere(
      (entry) => entry['action'] == 'handle',
      orElse: () => const {},
    );
    final currentId = widget.concern.handledBy?.trim() ?? '';
    final eventId = (event['actorId'] ?? event['performedBy'] ?? '').toString();
    if (currentId.isNotEmpty && currentId != eventId) event = const {};
    final id = currentId.isNotEmpty ? currentId : eventId;
    final storedName =
        (widget.concern.handledByName ??
                event['actorName'] ??
                event['performedByName'] ??
                '')
            .toString()
            .trim();
    _name = storedName == id || storedName.contains('@') ? '' : storedName;
    _role =
        _roles[(widget.concern.handledByRole ??
                event['actorRole'] ??
                event['role'] ??
                '')
            .toString()
            .toLowerCase()] ??
        '';
    if (currentId.isNotEmpty && event.isEmpty && _role.isEmpty) _name = '';
    if (_name.isNotEmpty && _role.isNotEmpty) return;
    try {
      final loader = widget.handlerLoader;
      final result = loader != null
          ? await loader(widget.concern.id)
          : Map<String, dynamic>.from(
              (await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
                      .httpsCallable(
                        'getConcernHandler',
                        options: HttpsCallableOptions(
                          timeout: const Duration(seconds: 10),
                        ),
                      )
                      .call<Map>({'submissionId': widget.concern.id}))
                  .data,
            );
      if (!mounted || request != _request) return;
      final name = result['name']?.toString().trim() ?? '';
      setState(() {
        if (name.isNotEmpty && name != id && !name.contains('@')) _name = name;
        _role = _roles[result['role']?.toString().toLowerCase()] ?? _role;
      });
    } catch (_) {
      // Keep the known history name without guessing a person or position.
    }
  }

  @override
  void didUpdateWidget(covariant ConcernHandlerIdentity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.concern != widget.concern) _load();
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.progressNote.trim();
    final defaultNote = RegExp(
      r' is (?:now |actively )?handling this concern\.?$',
      caseSensitive: false,
    ).hasMatch(note);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _name.isEmpty
              ? 'Handler not yet recorded'
              : 'Handled by: $_name${_role.isEmpty ? '' : ' · $_role'}',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        if (note.isNotEmpty && !defaultNote) ...[
          const SizedBox(height: 8),
          Text(
            note,
            style: GoogleFonts.outfit(
              fontSize: 14,
              height: 1.45,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }
}
