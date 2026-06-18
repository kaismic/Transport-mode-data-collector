import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/sample_dao.dart';
import '../../../core/invite_code_store.dart';
import '../../../core/phone_positions.dart';
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
  late Future<Session> _sessionFuture;
  late Stream<_SessionSampleSummary> _samplesStream;
  final _trimStartController = TextEditingController();
  final _trimEndController = TextEditingController();
  RangeValues? _trimValues;
  String? _trimStartError;
  String? _trimEndError;
  String? _phonePosition;
  var _trimInputsInitialized = false;
  var _phonePositionInitialized = false;
  var _uploadRequested = false;
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _sessionFuture = _loadSession();
  }

  Future<Session> _loadSession() async {
    final db = context.read<AppDatabase>();
    final session = await db.sessionDao.getSession(widget.sessionId);
    if (session == null) {
      throw StateError('Session not found.');
    }
    _samplesStream = db.sampleDao
        .watchReviewSampleOverview(widget.sessionId)
        .map(
          (overview) => _SessionSampleSummary.fromOverview(
            overview,
            startedAtMs: session.startedAtMs,
          ),
        );
    return session;
  }

  @override
  void dispose() {
    _trimStartController.dispose();
    _trimEndController.dispose();
    super.dispose();
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
        body: FutureBuilder<Session>(
          future: _sessionFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final session = snapshot.data!;
            return StreamBuilder<_SessionSampleSummary>(
              stream: _samplesStream,
              builder: (context, samplesSnapshot) {
                return _buildDetail(
                  uploadState,
                  _SessionDetail(
                    session: session,
                    sampleSummary: samplesSnapshot.data,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetail(UploadState uploadState, _SessionDetail detail) {
    final session = detail.session;
    final stoppedAtMs = session.stoppedAtMs;
    final uploadCompletedInState =
        (uploadState is UploadSuccess && uploadState.sessionId == session.id) ||
        (uploadState is UploadConfirmPending &&
            uploadState.sessionId == session.id);
    final isUploaded = session.uploadedAtMs != null || uploadCompletedInState;
    final isUploading =
        _uploadRequested ||
        (uploadState is UploadInProgress &&
            uploadState.sessionId == session.id);
    final canEdit = stoppedAtMs != null && !isUploaded && !isUploading;
    final canSubmit =
        canEdit && _trimStartError == null && _trimEndError == null;
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
          ((session.trimmedEndMs ?? stoppedAtMs ?? session.startedAtMs) -
                  session.startedAtMs) /
              1000,
        );
    _initializeTrimInputs(currentTrim);
    _initializePhonePosition(session.phonePosition);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Phone position', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        PhonePositionSelector(
          selectedPosition: _phonePosition ?? session.phonePosition,
          enabled: canEdit,
          onSelected: _updatePhonePosition,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 240,
          child: _MagnitudeChart(
            spots: detail.sampleSummary?.spots,
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
          divisions: min(1000, max(1, maxSeconds.round())),
          labels: RangeLabels(
            formatDuration(Duration(seconds: currentTrim.start.round())),
            formatDuration(Duration(seconds: currentTrim.end.round())),
          ),
          onChanged: !canEdit ? null : (values) => _setTrimFromSlider(values),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TrimTimeField(
                fieldKey: const Key('trim-start-field'),
                label: 'Start',
                controller: _trimStartController,
                enabled: canEdit,
                errorText: _trimStartError,
                onChanged: (_) => _setTrimFromText(
                  isStart: true,
                  maxSeconds: maxSeconds.toDouble(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TrimTimeField(
                fieldKey: const Key('trim-end-field'),
                label: 'End',
                controller: _trimEndController,
                enabled: canEdit,
                errorText: _trimEndError,
                onChanged: (_) => _setTrimFromText(
                  isStart: false,
                  maxSeconds: maxSeconds.toDouble(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _StatsPanel(detail: detail),
        const SizedBox(height: 20),
        KeyedSubtree(
          key: const Key('confirm-upload-action'),
          child: FilledButton.icon(
            onPressed: !canSubmit
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
  }

  void _initializePhonePosition(String phonePosition) {
    if (_phonePositionInitialized) return;
    _phonePositionInitialized = true;
    _phonePosition = phonePosition;
  }

  Future<void> _updatePhonePosition(String phonePosition) async {
    if (_phonePosition == phonePosition) return;
    final previous = _phonePosition;
    setState(() => _phonePosition = phonePosition);
    try {
      await context.read<AppDatabase>().sessionDao.updatePhonePosition(
        id: widget.sessionId,
        phonePosition: phonePosition,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _phonePosition = previous);
      _showSnack('Could not update phone position: $error');
    }
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

  void _initializeTrimInputs(RangeValues trim) {
    if (_trimInputsInitialized) return;
    _trimInputsInitialized = true;
    _trimStartController.text = _formatTrimTime(trim.start);
    _trimEndController.text = _formatTrimTime(trim.end);
  }

  void _setTrimFromSlider(RangeValues values) {
    setState(() {
      _trimValues = values;
      _trimStartError = null;
      _trimEndError = null;
      _trimStartController.text = _formatTrimTime(values.start);
      _trimEndController.text = _formatTrimTime(values.end);
    });
  }

  void _setTrimFromText({required bool isStart, required double maxSeconds}) {
    final start = _parseTrimTime(_trimStartController.text);
    final end = _parseTrimTime(_trimEndController.text);
    var startError = start == null ? 'Use MM:SS' : null;
    var endError = end == null ? 'Use MM:SS' : null;
    final maxMessage = 'Max ${_formatTrimTime(maxSeconds)}';
    if (start != null && start > maxSeconds) startError = maxMessage;
    if (end != null && end > maxSeconds) endError = maxMessage;
    if (startError == null && endError == null && start! > end!) {
      if (isStart) {
        startError = 'After end';
      } else {
        endError = 'Before start';
      }
    }
    setState(() {
      _trimStartError = startError;
      _trimEndError = endError;
      if (startError == null && endError == null) {
        _trimValues = RangeValues(start!, end!);
      }
    });
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
      _trimStartError = null;
      _trimEndError = null;
      _trimInputsInitialized = false;
      _phonePosition = null;
      _phonePositionInitialized = false;
      _sessionFuture = _loadSession();
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class PhonePositionSelector extends StatelessWidget {
  const PhonePositionSelector({
    super.key,
    required this.selectedPosition,
    required this.enabled,
    required this.onSelected,
  });

  final String selectedPosition;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final position in phonePositions)
          ChoiceChip(
            key: Key('review-phone-position-${position.id}'),
            label: Text(position.label),
            selected: selectedPosition == position.id,
            showCheckmark: false,
            onSelected: enabled
                ? (selected) {
                    if (selected) onSelected(position.id);
                  }
                : null,
          ),
      ],
    );
  }
}

class _TrimTimeField extends StatelessWidget {
  const _TrimTimeField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.datetime,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))],
      decoration: InputDecoration(
        labelText: label,
        hintText: 'MM:SS',
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

String _formatTrimTime(double seconds) {
  return formatDuration(Duration(seconds: seconds.round()));
}

double? _parseTrimTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2 && parts.length != 3) return null;
  final values = parts.map(int.tryParse).toList();
  if (values.any((part) => part == null)) return null;

  final hours = parts.length == 3 ? values[0]! : 0;
  final minutes = parts.length == 3 ? values[1]! : values[0]!;
  final seconds = parts.length == 3 ? values[2]! : values[1]!;
  if (hours < 0 || minutes < 0 || seconds < 0) return null;
  if ((parts.length == 3 && minutes >= 60) || seconds >= 60) return null;
  return (hours * 3600 + minutes * 60 + seconds).toDouble();
}

class _MagnitudeChart extends StatelessWidget {
  const _MagnitudeChart({
    required this.spots,
    required this.trim,
    required this.maxSeconds,
  });

  final List<FlSpot>? spots;
  final RangeValues trim;
  final double maxSeconds;

  @override
  Widget build(BuildContext context) {
    final chartSpots = spots;
    if (chartSpots == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (chartSpots.isEmpty) {
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
            spots: chartSpots,
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
          _StatRow(
            key: const Key('sample-count-stat'),
            label: 'Samples',
            value: detail.sampleSummary == null
                ? 'Loading...'
                : '${detail.sampleSummary!.sampleCount}',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({super.key, required this.label, required this.value});

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
  const _SessionDetail({required this.session, required this.sampleSummary});

  final Session session;
  final _SessionSampleSummary? sampleSummary;

  Duration get duration {
    return sessionDuration(
      startedAtMs: session.startedAtMs,
      stoppedAtMs: session.stoppedAtMs,
    );
  }
}

class _SessionSampleSummary {
  const _SessionSampleSummary({required this.sampleCount, required this.spots});

  factory _SessionSampleSummary.fromOverview(
    ReviewSampleOverview overview, {
    required int startedAtMs,
  }) {
    final spots = <FlSpot>[
      for (final sample in overview.points)
        FlSpot(
          (sample.timestampMs - startedAtMs) / 1000,
          sqrt(
            sample.accelX * sample.accelX +
                sample.accelY * sample.accelY +
                sample.accelZ * sample.accelZ,
          ),
        ),
    ];
    return _SessionSampleSummary(
      sampleCount: overview.sampleCount,
      spots: spots,
    );
  }

  final int sampleCount;
  final List<FlSpot> spots;
}
