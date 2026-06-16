const recordingTaskMessageTypeKey = 'type';
const recordingTaskSessionIdKey = 'session_id';
const recordingTaskReadyMessage = 'recording_ready';

Map<String, Object> recordingReadyTaskMessage(String sessionId) {
  return {
    recordingTaskMessageTypeKey: recordingTaskReadyMessage,
    recordingTaskSessionIdKey: sessionId,
  };
}

bool isRecordingReadyTaskMessage(Object data, String sessionId) {
  if (data is! Map) return false;
  return data[recordingTaskMessageTypeKey] == recordingTaskReadyMessage &&
      data[recordingTaskSessionIdKey] == sessionId;
}
