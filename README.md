# FutureJoy

## Simulator sample data

Use the **Forward** scheme with a **Debug** build on an iOS simulator. In Xcode,
open **Product → Scheme → Edit Scheme → Run → Arguments**, then add and enable:

```
--sample-data
```

This creates six fictional events for UI development: today, upcoming, and
archived events, including long text and composed emoji. Sample mode uses its
own local SwiftData store with CloudKit disabled. It never imports normal app
data. Edits, deletions, and events you create in sample mode persist across
launches; fixture dates also stay unchanged and age naturally.

To restore the fixtures with dates relative to today, also enable:

```
--reset-sample-data
```

Reset removes **all sample events**, including ones you created, and restores the
six fixtures. **Disable the reset argument after that launch** so subsequent
launches preserve your changes. The reset argument alone does nothing.

Disable both arguments to return to the normal app store and its existing data.
Release builds and physical-device builds ignore both arguments. Sample data
lives at `Application Support/SimulatorSampleData/Fixtures-v1.store` inside the
simulator app's sandbox; there is no production reset control.

Run the sample tests on a disposable simulator signed out of personal iCloud.
Unit tests are app-hosted, so the host can initialize normal persistence before
the tests run. Replace `<SIMULATOR_ID>` below with that simulator's identifier:

```sh
xcodebuild test -project Forward.xcodeproj -scheme Forward \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' \
  -only-testing:ForwardTests/SampleDataLaunchModeTests \
  -only-testing:ForwardTests/SimulatorSampleStoreTests \
  -only-testing:ForwardUITests/SimulatorSampleDataUITests
```

Keep the simulator's default code signing enabled for normal-mode host startup;
CloudKit requires the app's entitlements even without a signed-in iCloud account.
