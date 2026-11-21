# Issue #62: shared event draft preparation

## Lifecycle integration complete

[Issue #60](https://github.com/hn374/FutureJoy/issues/60) landed in [PR #64](https://github.com/hn374/FutureJoy/pull/64). The #62 branch is rebased onto main at `baeb363b`, integrated, and freshly verified. The historical wait-for-#60 condition is resolved.

`EventDraft` remains a Foundation-only module for validation and field preparation. Creation passes prepared values through `EventListViewModel.addEvent`. Editing maps all five prepared values to `EventEdit` and calls the injected `saveEdit` callback provided by Home's shared view model. The editor no longer mutates/saves records or resets archive flags itself.

`EventCalendarDay` is shared by draft validation, the edit DatePicker boundary, and the lifecycle's save validation and archive reconciliation. The lifecycle's injectable clock/calendar remain intact. The integration retains #60's per-record rollback on failed edit saves, unrelated pending changes, and post-save list-read fallback. Main's newer delete-confirmation, header behavior, and hardened emoji UI helpers are preserved.

Creation still defaults a blank emoji to 🎉; editing rejects a blank emoji and preserves untouched legacy values exactly. Title/location/notes normalization, validation precedence, explicit emoji-touch tracking, selected dates, category/createdAt, and cancellation behavior are preserved. Lifecycle date rejection maps to the existing date alert if a prepared draft becomes stale before saving.

## Verification — November 21

- Repository local CI gate passed: **54 unit tests + 6 selected UI flows**, with the exact inventory and required identifiers verified; benchmarks absent. Result: `/tmp/Forward62IntegrationCI/ForwardTests.xcresult`; log: `/tmp/Forward62IntegrationCI.log`.
- Supplementary creation, editing, legacy-emoji, cancellation, normalization/persistence and date UI coverage passed: **10 additional UI cases**, with exact inventory verified. Result: `/tmp/Forward62IntegrationUI.xcresult`; log: `/tmp/Forward62IntegrationUI.log`.
- Total current coverage: **54 unit tests and 16 focused UI flows**. New composition tests reopen saved prepared fields/legacy emoji and verify lifecycle rejection after an injected local-day change. Existing #60 rollback/read-failure/list tests remain green.
- Fresh Astra review (`gpt-6.2-astra`) found no Critical or Important defect. The final source matches the reviewed snapshot. One minor test-selector ambiguity is deferred below.
- Xcode 26.1.1, iOS 26.1, dedicated disposable iPhone 17 simulator signed out of personal iCloud; signing enabled; tests serial. `git diff --check` and CI shell syntax checks passed.

New SwiftData composition tests use the repository's async XCTest convention. An initial synchronous fixture run crashed in actor-isolated model deinitialization; the async correction passed both cases and the full unit suite without a production workaround.

## Deferred minor and scope

The inherited `EventCreationEmojiUITests.card(_:)` selector uses a title substring and `.firstMatch`. A future accessibility ordering change could select the matching Delete button. The sample-data helper already excludes labels beginning with `Delete `; applying that exclusion is a focused test-cleanup follow-up. Current selected cases passed; product behavior is unaffected.

No schema/storage migration, automatic day/import refresh (#53), or dismissal redesign (#58) is included. Broader creation/standalone-archive recovery in #52 is not expanded; #60's edit-save rollback is preserved. No CloudKit cross-device or physical-device verification is claimed.

Work remains local on `codex/event-draft-62`. The pre-rebase state is preserved as `codex/event-draft-62-before-lifecycle`. No push, PR, or merge was performed for this integration request.
