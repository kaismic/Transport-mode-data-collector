import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../../../core/invite_code_store.dart';
import '../../../core/time_format.dart';
import '../../../core/transport_modes.dart';
import '../../setup/screens/setup_screen.dart';
import '../../upload/bloc/upload_bloc.dart';
import 'session_review_screen.dart';

class ReviewListScreen extends StatelessWidget {
  const ReviewListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return BlocConsumer<UploadBloc, UploadState>(
      listener: (context, state) {
        if (state is UploadBatchComplete) {
          final message = state.total == 0
              ? 'No pending sessions to upload'
              : 'Upload all complete: ${state.uploaded} uploaded, '
                    '${state.confirmPending} awaiting confirmation, '
                    '${state.failed} failed';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, uploadState) {
        return StreamBuilder<List<Session>>(
          stream: db.sessionDao.watchAllSessions(),
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? const <Session>[];
            final pendingCount = sessions
                .where(
                  (session) =>
                      session.stoppedAtMs != null &&
                      session.uploadedAtMs == null,
                )
                .length;
            final batchState = uploadState is UploadBatchInProgress
                ? uploadState
                : null;
            final uploadInProgress =
                uploadState is UploadInProgress || batchState != null;
            return Scaffold(
              appBar: AppBar(
                title: const Text('Review Sessions'),
                actions: [
                  TextButton.icon(
                    key: const Key('upload-all-button'),
                    onPressed: uploadInProgress || pendingCount == 0
                        ? null
                        : () => _uploadAll(context),
                    icon: batchState == null
                        ? const Icon(Icons.cloud_upload)
                        : const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                    label: Text(
                      batchState == null
                          ? 'Upload All'
                          : '${batchState.completed + 1}/${batchState.total}',
                    ),
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (batchState != null)
                    LinearProgressIndicator(
                      value: batchState.total == 0
                          ? null
                          : batchState.completed / batchState.total,
                    ),
                  Expanded(
                    child: sessions.isEmpty
                        ? const Center(child: Text('No sessions yet'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: sessions.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              final mode = transportModeFor(
                                session.vehicleType,
                              );
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
                                onTap: uploadInProgress
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => SessionReviewScreen(
                                              sessionId: session.id,
                                            ),
                                          ),
                                        );
                                      },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _uploadAll(BuildContext context) async {
    final inviteCodeStore = context.read<InviteCodeStore>();
    var inviteCode = inviteCodeStore.inviteCode;
    if (inviteCode == null) {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => SetupScreen(inviteCodeStore: inviteCodeStore),
        ),
      );
      if (saved != true || !context.mounted) return;
      inviteCode = inviteCodeStore.inviteCode;
    }
    if (inviteCode == null || !context.mounted) return;
    context.read<UploadBloc>().add(UploadAllRequested(inviteCode: inviteCode));
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
