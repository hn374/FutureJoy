# FutureJoy

## Simulator sample data

Use the **Forward** scheme with a **Debug** build on an iOS simulator. In Xcode,
open **Product → Scheme → Edit Scheme → Run → Arguments**, then add and enable:

```
--sample-data
```

Choose a dataset from the **Profile** menu above the app. The banner stays
available while viewing event details. Switching profiles saves changes already applied to the current dataset and
returns to a fresh home screen. Save an open editor before switching if you
want to keep its draft.

| Profile | Initial data |
| --- | --- |
| Empty | No events |
| Typical | Six varied events, including today, upcoming, and archived events |
| Busy | 300 events across dates and categories |
| Edge cases | Eight events with long text, composed emoji, optional fields, and shared dates |
| Archive-heavy | Twenty archived events and one upcoming event |

Sample mode uses separate local SwiftData stores with CloudKit disabled. It never
imports normal app data. Edits, deletions, and events you create stay with each
profile across switches and launches; fixture dates stay unchanged and age
naturally. Typical reuses the original sample store, preserving existing edits.

Typical is selected on each launch by default. To launch another profile directly,
add two argument entries in Xcode (the flag and its value):

```
--sample-profile
empty
```

Allowed values are `empty`, `typical`, `busy`, `edge-cases`, and `archive-heavy`.
An unknown or missing value shows a diagnostic instead of opening another store.
Profile selection alone does not activate sample mode; `--sample-data` is required.

Use **Reset profile** and confirm the named profile to replace only its events
with the original fixtures dated relative to today. Other profiles stay unchanged.
For automated runs, also enable:

```
--reset-sample-data
```

This resets only the launch-selected profile. Disable the reset argument after
that launch to preserve subsequent changes. The reset argument alone does nothing.

Remove `--sample-data` and relaunch to return to the normal app and its existing
data. Release builds and physical-device builds ignore all sample arguments and
have no profile controls. Stores live inside the simulator app's sandbox at:

- Typical: `Application Support/SimulatorSampleData/Fixtures-v1.store`
- Others: `Application Support/SimulatorSampleData/Fixtures-<profile>-v1.store`

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
