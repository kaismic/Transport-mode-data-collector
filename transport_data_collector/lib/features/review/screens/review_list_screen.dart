import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../../../core/time_format.dart';
import '../../../core/transport_modes.dart';
import 'session_review_screen.dart';

class ReviewListScreen extends StatelessWidget {
  const ReviewListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('Review Sessions')),
      body: StreamBuilder<List<Session>>(
        stream: db.sessionDao.watchAllSessions(),
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? const <Session>[];
          if (sessions.isEmpty) {
            return const Center(child: Text('No sessions yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final mode = transportModeFor(session.vehicleType);
              final duration = sessionDuration(
                startedAtMs: session.startedAtMs,
                stoppedAtMs: session.stoppedAtMs,
              );
              return ListTile(
                leading: Icon(mode.icon),
                title: Text(mode.label),
                subtitle: Text(
                  '${formatDateTimeMs(session.startedAtMs)} · '
                  '${formatDuration(duration)}',
                ),
                trailing: _StatusChip(session: session),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          SessionReviewScreen(sessionId: session.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final label = session.stoppedAtMs == null
        ? 'Active'
        : session.confirmPending
        ? 'Confirm'
        : session.uploadedAtMs != null
        ? 'Uploaded'
        : 'Pending';
    final color = session.stoppedAtMs == null
        ? Theme.of(context).colorScheme.tertiaryContainer
        : session.confirmPending
        ? Theme.of(context).colorScheme.secondaryContainer
        : session.uploadedAtMs != null
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label),
      ),
    );
  }
}
