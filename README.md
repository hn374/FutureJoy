# FutureJoy

## Continuous integration

**iOS CI / Build and test** runs for pull requests targeting `main`, pushes to
`main`, and manual dispatches. It uses the standard `macos-15` hosted runner,
Xcode 26.1.1, and a fresh iPhone 17 simulator running iOS 26.1. The shared
**Forward** scheme builds the app and both test targets without user-local schemes.

The gate runs all `ForwardTests` except the opt-in `EventListBenchmarkTests`.
The focused UI tests are:

- `EventCreationEmojiUITests/testCreateEventWithCustomEmojiPersistsAndCanBeEdited`
- `SimulatorSampleDataUITests/testProfilesSwitchPersistAndResetIndependently`
- `SimulatorSampleDataUITests/testSampleEditsAndDeletionPersistUntilExplicitReset`
- `SimulatorSampleDataUITests/testSwitchingModesAndResetPreserveNormalEvents`
- `SimulatorSampleDataUITests/testArchivedEventRescheduledToFutureMovesListsAndPersists`
- `SimulatorSampleDataUITests/testArchivedEventRescheduledToTodayMovesListsAndPersists`

Other UI cases and template UI launch/performance tests are outside this initial gate.
Simulator boot overlaps the build; the script waits for boot to finish before
starting tests. Tests run serially on one simulator. The script checks the results
to ensure that every selected UI test and the required functional unit inventory actually ran
and passed, and benchmarks did not run. Update that inventory in
`.github/scripts/ios-ci.sh` when intentionally renaming or removing unit tests.

No Apple credentials or repository secrets are required. Simulator signing stays
enabled for CloudKit initialization, but the runner has no personal iCloud account.
These checks do not verify cloud sync. The **forward-test-results** artifact
retains build logs and any test logs, screenshots in `.xcresult`, and result JSON
produced for seven days, including on failures. Logs and artifacts are public;
use fictional test data only. New PR commits cancel older runs for that PR; jobs
time out after 45 minutes.

To run the same build and test commands locally, from the repository root:

```sh
# Use Xcode 26.1.1 and a disposable simulator signed out of iCloud.
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export SIMULATOR_ID=$(xcrun simctl create "Forward CI Local" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17 \
  com.apple.CoreSimulator.SimRuntime.iOS-26-1)
export RUNNER_TEMP=$(mktemp -d)
xcrun simctl boot "$SIMULATOR_ID"
bash .github/scripts/ios-ci.sh
# After inspecting the results, remove only this disposable simulator.
xcrun simctl shutdown "$SIMULATOR_ID"
xcrun simctl delete "$SIMULATOR_ID"
```

Inspect the run in GitHub's Actions tab and download **forward-test-results** to
open `ForwardTests.xcresult` in Xcode. A missing toolchain/runtime fails during
simulator preparation; check the runner's installed software before updating the
pinned versions. Build failures are in `forward-build.log`; test failures are in
`forward-tests.log` and the result bundle when produced. For local clipboard UI
failures, avoid simultaneous simulator test runs with shared clipboard syncing.
The manual trigger appears after the workflow reaches the default branch.

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
