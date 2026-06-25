# Transport Data Collector

Flutter application for recording phone sensor data, reviewing sessions, and
uploading approved data to the TCCT API.

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

Run the platform-independent checks on any development machine:

```shell
flutter analyze
flutter test
```

On macOS, also verify that the native target compiles without signing:

```shell
flutter build ios --simulator --dart-define-from-file=config/dev.env
```
