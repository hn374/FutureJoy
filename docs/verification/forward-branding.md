# Forward branding audit and verification

Issue: [#37](https://github.com/hn374/FutureJoy/issues/37).

The home heading uses **Forward** and retains SwiftUI's accessibility header
trait. `Forward/Info.plist` explicitly sets `CFBundleDisplayName` to Forward;
the supported target uses this plist for Debug and Release. Forward Dev uses a
separate plist and keeps its target-derived name. It remains unsupported as
described in the README.

## Retained FutureJoy references

Run from the repository root, including hidden tracked files:

```sh
git grep -n -i futurejoy
```

| Location | Reason to retain |
| --- | --- |
| README and documentation links/clone commands | The GitHub repository is still `hn374/FutureJoy`; renaming it is outside this issue. |
| `Forward/FutureJoyApp.swift`, its `FutureJoyApp` symbol, and `Forward.xcodeproj/project.pbxproj` membership | Internal entry point and references; renaming adds no visible branding improvement. |
| `Forward/FutureJoyApp.swift` and `Forward/Utils/DataMigration.swift`: `FutureJoy.store` | Existing local fallback store path; changing it could hide existing events. |
| Swift source header comments | Historical project name; not runtime copy. |
| `Forward/tech_design.md` | Historical design note, already identified as outdated in README; it is not current app/setup guidance. |
| Branding design, implementation plan, and this audit | Describe the rename, compatibility boundaries, and historical references. |

The audit found no checked-in string catalogs, `.strings` or `.stringsdict`
resources. The icon assets have no visible brand text. The only active old-brand
screen text was the home heading; its existing UI test expectations are updated.
Future/Past labels and event behavior are unchanged. Future icon, widget, and
App Store work remains under #9, #10, and #12.

Bundle identifiers, CloudKit identifiers, entitlements, signing, Event schema,
stored keys, migration logic, and all normal/sample persistence paths are
unchanged. This source audit supports compatibility; it does not prove an
installed app name, successful upgrade, or cross-device sync.

## Mac build and UI verification (pending)

Use Xcode 26.1.1 and a disposable iPhone 17 / iOS 26.1 simulator signed out of
personal iCloud. Set `SIMULATOR_ID` to its identifier. Keep simulator signing
enabled. Use fictional data. These commands have **not** run in the Linux
implementation environment, which has no `xcodebuild` or iOS simulator.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export SIMULATOR_ID='<DISPOSABLE_SIMULATOR_ID>'
export RUNNER_TEMP=$(mktemp -d)

# Existing functional gate (Debug); start only your disposable simulator.
xcrun simctl boot "$SIMULATOR_ID"
bash .github/scripts/ios-ci.sh

# The existing gate does not include these list/name/layout tests.
xcodebuild test -project Forward.xcodeproj -scheme Forward \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -parallel-testing-enabled NO \
  -only-testing:ForwardUITests/ListSwitchingUITests \
  -resultBundlePath "$RUNNER_TEMP/ForwardBranding.xcresult"
xcrun xcresulttool get test-results tests \
  --path "$RUNNER_TEMP/ForwardBranding.xcresult" \
  > "$RUNNER_TEMP/forward-branding-test-tree.json"

# Build and inspect the processed plist independently in each configuration.
for configuration in Debug Release; do
  derived="$RUNNER_TEMP/ForwardBranding-$configuration"
  xcodebuild build -project Forward.xcodeproj -scheme Forward \
    -configuration "$configuration" \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath "$derived" || break
  built_app="$derived/Build/Products/$configuration-iphonesimulator/Forward.app"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$built_app/Info.plist"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$built_app/Info.plist"
  xcrun simctl install "$SIMULATOR_ID" "$built_app"
  xcrun simctl launch "$SIMULATOR_ID" Hoang.Forward
  # Inspect SpringBoard display name and the app before continuing.
done
```

- [ ] Existing functional gate passes. A green existing CI gate alone covers
  neither ListSwitchingUITests nor Release.
- [ ] Confirm all five `ListSwitchingUITests` cases actually ran and passed in
  the result tree; unmatched test filters can otherwise hide missing coverage.
- [ ] Inspect retained screenshot attachments: Future/Past at normal text size
  and Empty/Archive-heavy Future/Past at accessibility XXXL. Forward and list
  controls must remain visible without clipping.
- [ ] Debug and Release processed plists report Forward and Hoang.Forward;
  SpringBoard displays Forward after each installation. Preserve Dev's separate
  settings/suffix; building or repairing that unsupported target is not required.
- [ ] With Accessibility Inspector or VoiceOver, confirm Forward is exposed as
  a heading in both list states. Screenshots do not establish spoken output.

## Normal-data in-place upgrade and sync (pending)

1. Record the baseline and candidate commit IDs. Install the pre-change app with
   the same bundle identifier and signing as the candidate. In **normal mode**
   (no sample arguments), create fictional Future/Past events and record all
   fields plus existing UserDefaults, including `CloudKitMigrationCompleted` if
   present. Do not treat the transient Future/Past selection as a stored setting.
2. Record the active backend: CloudKit-backed and local fallback stores are
   separate; startup does not migrate between them. Keep the backend consistent
   across the update. Check local fallback retention separately where available.
3. Install the candidate over the baseline **without uninstalling, resetting,
   or erasing data**. Relaunch and compare event fields and stored defaults.
   Confirm both lists, event editing, and a second relaunch still work.
4. On authorized signed-in test devices with matching signing/entitlements,
   establish that sync works before updating. After updating, edit a fictional
   event and confirm propagation. Record devices, revisions, and results without
   publishing personal account data. A simulator signed out of iCloud cannot
   establish sync.

Sample UI tests reset isolated stores with CloudKit disabled. They establish
layout and behavior for fixtures, not an upgrade of normal data or working sync.
Leave these acceptance checks pending until actual runtime evidence exists.
