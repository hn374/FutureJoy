# Forward branding — issue #37

## Intent and scope

Finish the user-facing rename from FutureJoy to Forward. Keep event navigation,
existing events, preferences, and CloudKit behavior intact.

## Approach

Make targeted copy changes in the existing SwiftUI app. A global replacement
would touch compatibility paths and historical documentation; renaming internal
symbols adds reference churn without improving the visible app.

## Changes

- Change `HomeView.appTitle` to Forward. Its accessible text follows the same
  SwiftUI Text value and retains the header trait.
- Add `CFBundleDisplayName = Forward` to `Forward/Info.plist`, which is used by
  both Debug and Release on the supported Forward target. Keep `PRODUCT_NAME`
  unchanged. Forward Dev uses a separate plist; preserve its development suffix
  and do not repair that unsupported target as part of this change.
- Update existing list-switching UI assertions to Forward and assert the title
  in both Future and Past, including largest accessibility text. Retain screenshot
  attachments for both states.
- Update README introductory and run instructions. Record remaining FutureJoy
  references by purpose: repository URLs, app entry filename/symbol and project
  membership, historical source headers/design notes, and the compatible local
  store path. Future icon, widget and App Store work remains under #9, #10 and #12.
- Audit current screens, accessibility strings, localization resources and icon
  assets for additional old-brand copy before finalizing the patch.

## Compatibility boundaries

Preserve bundle IDs, signing, CloudKit identifiers, entitlements, Event schema,
stored keys, migration logic, sample-store paths, and Documents/FutureJoy.store.
Do not rename the repository, migrate data, redesign the icon or publish changes.

## Verification

- Inspect the complete diff and classify remaining case-insensitive FutureJoy
  search results. Check plist syntax and Debug/Release naming configuration.
- On a Mac with Xcode 26.1.1, build supported Debug and Release simulator
  configurations and inspect generated/installed bundle display names.
- Run the existing functional test gate and ListSwitchingUITests on a disposable
  simulator; inspect screenshots of Future/Past at normal and largest text sizes.
  The current CI gate runs Debug and excludes ListSwitchingUITests. Run that
  class separately in Debug with a retained result bundle, verify the tests
  actually ran, and build/inspect Release separately. Document the Mac commands
  with implementation; broadening CI is not required for this ticket.
- Check the accessibility hierarchy with Accessibility Inspector or VoiceOver:
  Forward must remain a heading in both list states. Screenshots establish
  layout but do not prove spoken output.
- For an in-place update, record baseline and candidate revisions. Install the
  pre-change build and create fictional Future/Past events in normal mode;
  record their fields and existing UserDefaults, including the current
  `CloudKitMigrationCompleted` key if present. Future/Past selection is transient,
  not a persisted preference. Install the candidate over the baseline with the
  same bundle ID/signing, without uninstalling/resetting, then verify fields and
  defaults after relaunch. Keep the active persistence backend consistent:
  CloudKit and local fallback are separate stores, with no startup migration.
- Verify sync separately on authorized signed-in test devices: establish it
  works before updating and confirm an edit propagates afterward. Sample UI
  tests reset isolated stores with CloudKit disabled and cannot prove normal
  data retention or sync. Static preservation of identifiers supports
  compatibility but does not establish either runtime result.

This Linux environment cannot run Xcode or an iOS simulator. Report those checks
as outstanding unless a Mac or CI supplies actual results; do not mark the full
issue verified based on source inspection alone.
