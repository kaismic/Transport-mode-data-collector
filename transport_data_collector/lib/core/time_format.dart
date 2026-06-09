import 'package:intl/intl.dart';

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String formatDateTimeMs(int timestampMs) {
  return DateFormat(
    'EEE d MMM, h:mm a',
  ).format(DateTime.fromMillisecondsSinceEpoch(timestampMs));
}

Duration sessionDuration({
  required int startedAtMs,
  required int? stoppedAtMs,
}) {
  final end = stoppedAtMs ?? DateTime.now().millisecondsSinceEpoch;
  return Duration(milliseconds: end - startedAtMs);
}
