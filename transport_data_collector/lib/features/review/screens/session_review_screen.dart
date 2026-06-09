import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../../../core/invite_code_store.dart';
import '../../../core/time_format.dart';
import '../../../core/transport_modes.dart';
import '../../setup/screens/setup_screen.dart';
import '../../upload/bloc/upload_bloc.dart';

class SessionReviewScreen extends StatefulWidget {
  const SessionReviewScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionReviewScreen> createState() => _SessionReviewScreenState();
}

class _SessionReviewScreenState extends State<SessionReviewScreen> {
  late Future<_SessionDetail> _detailFuture;
  RangeValues? _trimValues;
  var _uploadRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detailFuture = _loadDetail();
  }

  Future<_SessionDetail> _loadDetail() async {
    final db = context.read<AppDatabase>();
    final session = await db.sessionDao.getSession(widget.sessionId);
    if (session == null) {
      throw StateError('Session not found.');
    }
    final samples = await db.sampleDao.getSamplesForSession(widget.sessionId);
    return _SessionDetail(session: session, samples: samples);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UploadBloc, UploadState>(
      listener: (context, state) {
        if (state is UploadSuccess && state.sessionId == widget.sessionId) {
          _showSnack('Upload complete');
          _refresh(uploadRequested: false);
        } else if (state is UploadConfirmPending &&
            state.sessionId == widget.sessionId) {
          _showSnack('Uploaded; confirmation will retry later');
          _refresh(uploadRequested: false);
        } else if (state is UploadFailure && _uploadRequested) {
          setState(() => _uploadRequested = false);
          _showSnack(state.message);
        }
      },
      builder: (context, uploadState) => Scaffold(
        appBar: AppBar(title: const Text('Session Review')),
        body: FutureBuilder<_SessionDetail>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final detail = snapshot.data!;
            final session = detail.session;
            final stoppedAtMs = session.stoppedAtMs;
            final uploadCompletedInState =
                (uploadState is UploadSuccess &&
                    uploadState.sessionId == session.id) ||
                (uploadState is UploadConfirmPending &&
                    uploadState.sessionId == session.id);
            final isUploaded =
                session.uploadedAtMs != null || uploadCompletedInState;
            final isUploading =
                _uploadRequested ||
                (uploadState is UploadInProgress &&
                    uploadState.sessionId == session.id);
            final canEdit = stoppedAtMs != null && !isUploaded && !isUploading;
            final canDelete = canEdit;
            final maxSeconds = detail.duration.inSeconds.toDouble().clamp(
              1,
              double.infinity,
            );
            final currentTrim =
                _trimValues ??
                RangeValues(
                  ((session.trimmedStartMs ?? session.startedAtMs) -
                          session.startedAtMs) /
                      1000,
                  ((session.trimmedEndMs ??
                              stoppedAtMs ??
                              session.startedAtMs) -
                          session.startedAtMs) /
                      1000,
                );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  height: 240,
                  child: _MagnitudeChart(
                    spots: detail.chartSpots,
                    trim: currentTrim,
                    maxSeconds: maxSeconds.toDouble(),
                  ),
                ),
                const SizedBox(height: 16),
                RangeSlider(
                  values: RangeValues(
                    currentTrim.start.clamp(0, maxSeconds.toDouble()),
                    currentTrim.end.clamp(0, maxSeconds.toDouble()),
                  ),
                  min: 0,
                  max: maxSeconds.toDouble(),
                  divisions: max(1, maxSeconds.round()),
                  labels: RangeLabels(
                    formatDuration(
                      Duration(seconds: currentTrim.start.round()),
                    ),
                    formatDuration(Duration(seconds: currentTrim.end.round())),
                  ),
                  onChanged: !canEdit
                      ? null
                      : (values) => setState(() => _trimValues = values),
                ),
                const SizedBox(height: 8),
                _StatsPanel(detail: detail),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: !canEdit
                      ? null
                      : () => _saveTrimAndUpload(detail, currentTrim),
                  icon: isUploading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          session.confirmPending
                              ? Icons.schedule
                              : isUploaded
                              ? Icons.cloud_done
                              : Icons.cloud_upload,
                        ),
                  label: Text(
                    isUploading
                        ? 'Uploading...'
                        : session.confirmPending
                        ? 'Awaiting Confirmation'
                        : isUploaded
                        ? 'Uploaded'
                        : 'Confirm & Upload',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: canDelete ? () => _confirmDelete(context) : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveTrimAndUpload(
    _SessionDetail detail,
    RangeValues trim,
  ) async {
    if (_uploadRequested) return;
    setState(() => _uploadRequested = true);

    final db = context.read<AppDatabase>();
    final uploadBloc = context.read<UploadBloc>();
    final inviteCodeStore = context.read<InviteCodeStore>();
    try {
      var inviteCode = inviteCodeStore.inviteCode;
      if (inviteCode == null) {
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => SetupScreen(inviteCodeStore: inviteCodeStore),
          ),
        );
        if (saved != true || !mounted) {
          if (mounted) setState(() => _uploadRequested = false);
          return;
        }
        inviteCode = inviteCodeStore.inviteCode;
        if (inviteCode == null) {
          setState(() => _uploadRequested = false);
          return;
        }
      }
      await db.sessionDao.updateTrim(
        id: detail.session.id,
        trimmedStartMs:
            detail.session.startedAtMs + (trim.start * 1000).round(),
        trimmedEndMs: detail.session.startedAtMs + (trim.end * 1000).round(),
      );
      if (!mounted) return;
      uploadBloc.add(
        UploadSessionRequested(
          sessionId: detail.session.id,
          inviteCode: inviteCode,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploadRequested = false);
      _showSnack('Could not prepare upload: $error');
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Delete this session and its local samples?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AppDatabase>().sessionDao.deleteSessionWithSamples(
      widget.sessionId,
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  void _refresh({bool? uploadRequested}) {
    setState(() {
      if (uploadRequested != null) {
        _uploadRequested = uploadRequested;
      }
      _trimValues = null;
      _detailFuture = _loadDetail();
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MagnitudeChart extends StatelessWidget {
  const _MagnitudeChart({
    required this.spots,
    required this.trim,
    required this.maxSeconds,
  });

  final List<FlSpot> spots;
  final RangeValues trim;
  final double maxSeconds;

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) {
      return const Center(child: Text('No samples recorded'));
    }
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxSeconds,
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            VerticalLine(
              x: trim.start,
              color: Theme.of(context).colorScheme.secondary,
              strokeWidth: 2,
            ),
            VerticalLine(
              x: trim.end,
              color: Theme.of(context).colorScheme.tertiary,
              strokeWidth: 2,
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.detail});

  final _SessionDetail detail;

  @override
  Widget build(BuildContext context) {
    final mode = transportModeFor(detail.session.vehicleType);
    final trimmedStart =
        detail.session.trimmedStartMs ?? detail.session.startedAtMs;
    final trimmedEnd =
        detail.session.trimmedEndMs ??
        detail.session.stoppedAtMs ??
        detail.session.startedAtMs;
    final trimmedDuration = Duration(milliseconds: trimmedEnd - trimmedStart);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _StatRow(label: 'Mode', value: mode.label),
          _StatRow(
            label: 'Started',
            value: formatDateTimeMs(detail.session.startedAtMs),
          ),
          _StatRow(label: 'Duration', value: formatDuration(detail.duration)),
          _StatRow(label: 'Trimmed', value: formatDuration(trimmedDuration)),
          _StatRow(label: 'Samples', value: '${detail.samples.length}'),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _SessionDetail {
  const _SessionDetail({required this.session, required this.samples});

  final Session session;
  final List<Sample> samples;

  Duration get duration {
    return sessionDuration(
      startedAtMs: session.startedAtMs,
      stoppedAtMs: session.stoppedAtMs,
    );
  }

  List<FlSpot> get chartSpots {
    if (samples.isEmpty) return const [];
    final stride = max(1, (samples.length / 500).ceil());
    final spots = <FlSpot>[];
    for (var i = 0; i < samples.length; i += stride) {
      final sample = samples[i];
      final seconds = (sample.timestampMs - session.startedAtMs) / 1000;
      final magnitude = sqrt(
        sample.accelX * sample.accelX +
            sample.accelY * sample.accelY +
            sample.accelZ * sample.accelZ,
      );
      spots.add(FlSpot(seconds, magnitude));
    }
    return spots;
  }
}
