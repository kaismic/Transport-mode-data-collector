# Transport Data Collector

Flutter application for recording phone sensor data, reviewing sessions, and
uploading approved data to the TCCT API.

## Current release

Version `1.0.4+5` (build 5) adds automatic retries for generic upload-URL HTTP
403 failures and actionable messages for invalid invite codes and API errors.
The companion backend fix uses strongly consistent invite-code reads.

`pubspec.yaml` is the source of the app version and build number. Android and
iOS inherit these values through Flutter's build settings, and session uploads
report the version from the installed app's package metadata.

## Sensor sampling rate

The accelerometer requests a 16,667 microsecond sampling period, which is
approximately 60 Hz. Gyroscope, magnetometer, and barometer streams retain the
slower platform `normalInterval` request.

Platform sampling periods are advisory and some devices may deliver events
faster than requested. The app therefore applies an independent 60 Hz maximum
to every sensor stream before updating cached readings, recording samples, or
calculating the manifest's `observed_hz`. Excess events are discarded rather
than buffered. Existing sessions and previously uploaded data are unaffected.

## Local configuration

Development builds read compile-time values from `config/dev.env`:

```text
API_BASE_URL=https://example.execute-api.ap-southeast-2.amazonaws.com/Prod
```

Copy `config/dev.env.example` to `config/dev.env` and set the local API URL.
The uploaded app version is read from the Flutter package metadata generated
from `pubspec.yaml`.

Run the app with:

```shell
flutter pub get
flutter run --dart-define-from-file=config/dev.env
```

The repository's **Flutter: Development** VS Code launch configuration supplies
the same environment file.

## iOS test environment

iOS builds require macOS; Windows can edit and test the shared Dart code but
cannot run Xcode, CocoaPods, the iOS simulator, or an iPhone build.

Install on the Mac:

- Xcode and its command-line tools
- Flutter stable
- CocoaPods
- An Apple ID added under Xcode **Settings > Accounts**

Then prepare the project:

```shell
cd transport_data_collector
flutter doctor -v
flutter pub get
cd ios
pod install --repo-update
open Runner.xcworkspace
```

Always open `Runner.xcworkspace`, not `Runner.xcodeproj`, because the app uses
native Flutter plugins installed by CocoaPods.

### Signing and physical iPhone setup

In Xcode:

1. Select **Runner** in the project navigator, then the **Runner** target.
2. Open **Signing & Capabilities**.
3. Leave **Automatically manage signing** enabled and choose your Apple
   development team.
4. If `com.kaismic.transportDataCollector` is unavailable to that team, assign
   a unique bundle identifier. Keep the `.RunnerTests` identifier aligned.
5. Connect and unlock the iPhone, trust the Mac, and enable Developer Mode when
   iOS requests it.
6. Select the iPhone as the run destination.

You can run from Xcode or from the app directory:

```shell
flutter devices
flutter run -d <iphone-device-id> --dart-define-from-file=config/dev.env
```

Builds launched directly from Xcode use the fallback values in
`ios/Flutter/DartDefines.xcconfig`. Keep its base64-encoded `KEY=VALUE` entries
in sync with `config/dev.env` when changing the API endpoint. Values supplied
by `flutter run` or `flutter build` take precedence over these fallbacks.

Use a physical iPhone for sensor validation. The simulator does not provide a
representative accelerometer, gyroscope, magnetometer, or barometer stream.

### iPhone smoke test

1. Launch the app and accept notification and motion access when prompted.
2. Start a recording and verify samples begin arriving within five seconds.
3. Lock the phone for at least 30 seconds, unlock it, then stop the session.
4. Confirm the review screen contains sensor samples and the session can be
   edited.
5. Upload the session and verify the API accepts it.
6. Repeat once with the app backgrounded.

The recording implementation uses `flutter_foreground_task`. iOS does not offer
Android-style indefinite foreground services: after the app is backgrounded,
execution time is controlled by iOS, and a force-quit stops the task. Treat
long locked-screen/background recordings as an explicit device test rather
than assuming Android behavior.

## Validation

### Upload failures

The app automatically retries generic HTTP 403 responses when requesting an
upload URL, with waits of 1, 2, and 4 seconds (four attempts total). It uploads
the file and confirms the session only after obtaining a URL. Explicit invalid
or inactive invite codes and incorrect API routes fail immediately with guidance
instead of Dio's lengthy diagnostic text. Change an invalid invite code using
the home screen's **Change invite code** action.

Other HTTP failures and timeouts are not automatically replayed: the server may
already have created the pending session. Error messages include the HTTP status
and the API's message when available. Deploy the server's strongly consistent
invite lookup as well as rebuilding the app to include the complete fix.

### Checks

Run the platform-independent checks on any development machine:

```shell
flutter analyze
flutter test
```

On macOS, also verify that the native target compiles without signing:

```shell
flutter build ios --simulator --dart-define-from-file=config/dev.env
```
