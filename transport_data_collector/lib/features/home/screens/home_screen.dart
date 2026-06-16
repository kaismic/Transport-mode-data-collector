import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../../../core/invite_code_store.dart';
import '../../../core/time_format.dart';
import '../../../core/transport_modes.dart';
import '../../recording/bloc/recording_bloc.dart';
import '../../review/screens/review_list_screen.dart';
import '../../setup/screens/setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.deviceUuid});

  final String deviceUuid;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<RecordingBloc>().add(const RestoreRecordingRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Data Collector'),
        actions: [
          IconButton(
            onPressed: _editInviteCode,
            tooltip: 'Change invite code',
            icon: const Icon(Icons.key),
          ),
        ],
      ),
      body: BlocConsumer<RecordingBloc, RecordingState>(
        listener: (context, state) {
          if (state is RecordingError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, recordingState) {
          final isRecording = recordingState is RecordingActive;
          final isRestoring = recordingState is RecordingRestoring;
          return StreamBuilder<List<Session>>(
            stream: db.sessionDao.watchAllSessions(),
            builder: (context, snapshot) {
              final sessions = snapshot.data ?? const <Session>[];
              final pending = sessions
                  .where((s) => s.stoppedAtMs != null && s.uploadedAtMs == null)
                  .length;
              final uploaded = sessions
                  .where((s) => s.uploadedAtMs != null)
                  .length;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (isRestoring) const LinearProgressIndicator(),
                  if (isRestoring) const SizedBox(height: 16),
                  if (isRecording) _RecordingBanner(state: recordingState),
                  _DevicePanel(deviceUuid: widget.deviceUuid),
                  const SizedBox(height: 16),
                  _SummaryRow(
                    total: sessions.length,
                    pending: pending,
                    uploaded: uploaded,
                  ),
                  const SizedBox(height: 24),
                  RecordingActionButton(
                    recordingState: recordingState,
                    onStartRecording: () => _showVehicleSheet(context),
                    onStopRecording: () {
                      context.read<RecordingBloc>().add(
                        const StopRecordingRequested(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ReviewListScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.fact_check),
                    label: const Text('Review & Upload'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editInviteCode() async {
    final store = context.read<InviteCodeStore>();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SetupScreen(inviteCodeStore: store),
      ),
    );
  }

  void _showVehicleSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: transportModes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final mode = transportModes[index];
              return FilledButton.tonal(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.read<RecordingBloc>().add(
                    StartRecordingRequested(mode.id),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(mode.icon, size: 32),
                    const SizedBox(height: 8),
                    Text(mode.label),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class RecordingActionButton extends StatelessWidget {
  const RecordingActionButton({
    super.key,
    required this.recordingState,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  final RecordingState recordingState;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  @override
  Widget build(BuildContext context) {
    final isRecording = recordingState is RecordingActive;
    final isStarting = recordingState is RecordingStarting;
    final isRestoring = recordingState is RecordingRestoring;

    return FilledButton.icon(
      style: isRecording
          ? FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            )
          : null,
      onPressed: isStarting || isRestoring
          ? null
          : isRecording
          ? onStopRecording
          : onStartRecording,
      icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
      label: Text(
        isRecording
            ? 'Stop Recording'
            : isStarting
            ? 'Starting Recording...'
            : 'Start Recording',
      ),
    );
  }
}

class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner({required this.state});

  final RecordingActive state;

  @override
  Widget build(BuildContext context) {
    final mode = transportModeFor(state.vehicleType);
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(mode.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${mode.label} recording ${formatDuration(state.elapsed)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicePanel extends StatelessWidget {
  const _DevicePanel({required this.deviceUuid});

  final String deviceUuid;

  @override
  Widget build(BuildContext context) {
    final shortId = deviceUuid.length > 8
        ? deviceUuid.substring(0, 8)
        : deviceUuid;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.badge_outlined),
      title: const Text('Device UUID'),
      subtitle: Text('$shortId...'),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.total,
    required this.pending,
    required this.uploaded,
  });

  final int total;
  final int pending;
  final int uploaded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Metric(label: 'Recorded', value: total),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(label: 'Pending', value: pending),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(label: 'Uploaded', value: uploaded),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text('$value', style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}
