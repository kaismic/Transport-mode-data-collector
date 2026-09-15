typedef MonotonicMicroseconds = int Function();

class SensorRateGate<T> {
  SensorRateGate({
    required Duration minimumInterval,
    required this.nowMicroseconds,
  }) : _minimumIntervalUs = minimumInterval.inMicroseconds;

  final int _minimumIntervalUs;
  final MonotonicMicroseconds nowMicroseconds;
  final _lastAcceptedAtUs = <T, int>{};

  bool shouldAccept(T sensor) {
    final nowUs = nowMicroseconds();
    final lastAcceptedAtUs = _lastAcceptedAtUs[sensor];
    if (lastAcceptedAtUs != null &&
        nowUs - lastAcceptedAtUs < _minimumIntervalUs) {
      return false;
    }

    _lastAcceptedAtUs[sensor] = nowUs;
    return true;
  }
}

class SensorRateWindow<T> {
  SensorRateWindow({
    required this.nowMicroseconds,
    this.window = const Duration(seconds: 2),
  });

  final Duration window;
  final MonotonicMicroseconds nowMicroseconds;
  final _events = <T, List<int>>{};

  void mark(T sensor) {
    final nowUs = nowMicroseconds();
    final events = _events.putIfAbsent(sensor, () => <int>[]);
    events.add(nowUs);
    events.removeWhere(
      (timestampUs) => nowUs - timestampUs > window.inMicroseconds,
    );
  }

  double? hzFor(T sensor) {
    final events = _events[sensor];
    if (events == null || events.length < 2) return null;
    final durationUs = events.last - events.first;
    if (durationUs <= 0) return null;
    return (events.length - 1) * Duration.microsecondsPerSecond / durationUs;
  }
}
