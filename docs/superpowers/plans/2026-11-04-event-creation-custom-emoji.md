# Custom Emoji During Event Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for inline execution, or superpowers:subagent-driven-development if the user chooses delegation. Steps use checkbox (`- [ ]`) syntax for tracking. Do not commit unless explicitly requested.

**Goal:** Let users enter a custom emoji when creating an event, while retaining presets and using 🎉 when no emoji is chosen.

**Architecture:** Extend the existing `CreateEventView` state and save flow. Bind a custom text field and the preset grid to the same `selectedEmoji` value, then normalize that value at the creation boundary. Keep the existing `Event` model, SwiftData persistence, and edit screen behavior.

**Tech Stack:** SwiftUI, SwiftData, XCTest/XCUITest, XcodeBuildMCP; existing iOS 26.1 project configuration.

**Spec:** [GitHub issue #6](https://github.com/hn374/FutureJoy/issues/6), with the proposed small-change design below. Approved and executed; verification results are recorded below.

## Proposed design and current evidence

- `Forward/Views/CreateEventView.swift` already initializes `selectedEmoji` to 🎉, displays a preset grid below the notes field, and passes the selection to `EventListViewModel.addEvent`.
- The creation form currently marks emoji selection as required and rejects an empty selection.
- `Forward/Views/EventDetailView.swift` already allows custom input through `TextField("Emoji", text: $editedEmoji)`, capped at two Swift `Character` values with `prefix(2)`.
- `Event.emoji` is already persisted, rendered on cards, and loaded into edit state. No schema migration or new persistence API is needed.
- Add a labeled custom emoji text field above the existing grid. Keep this section in its current position to avoid a broader form redesign.
- Label the section **Emoji (Optional)** and explain **Defaults to 🎉 if left blank**. Start with 🎉 selected, preserving current behavior.
- Match the edit page's two-character limit, using Swift `Character` boundaries so joined emoji, flags, and skin tones are not split into Unicode scalars. Matching this limit is a proposed compatibility decision, not a new requirement from the issue.
- Accept keyboard input and pasted emoji. Do not introduce an emoji-only keyboard bridge, a third-party picker, or stricter Unicode validation than the edit page currently uses.
- Trim whitespace before saving; if the result is empty, save 🎉. Emoji input must not independently prevent creation when the title and date are valid.
- Choosing a preset replaces custom input; entering custom input replaces the preset selection. The displayed field, grid selection, saved card, and edit page must agree.

## Global constraints

- Preserve the existing preset choices, title/date validation, save error handling, and create success behavior.
- Preserve existing events and the edit page's validation behavior, including its current requirement for a nonblank emoji when editing.
- No new dependencies, model changes, project configuration changes, or unrelated scrolling refactors.
- Test observable creation, persistence, and editing behavior through real app wiring. Do not mock `EventListViewModel`, `ModelContext`, or storage to force UI state.
- Use unique test event titles and clean up only records created by the tests; never erase the user's store.

## Review focus

1. Untouched selection: creation saves 🎉 without any interaction with the emoji controls.
2. Empty or whitespace input: creation still succeeds and saves 🎉.
3. Compound emoji: custom input such as 🧑🏽‍🚀 survives creation and reopening without corruption.
4. Preset/custom replacement: the latest choice is the value actually saved, without stale selection state.
5. Persistence and editing: relaunching preserves the selected emoji, and a later edit updates the same event card.

## Files and responsibilities

| File | Planned changes |
| --- | --- |
| `Forward/Views/CreateEventView.swift` | Add optional custom input, keep it synchronized with presets, and apply the default when saving. |
| `ForwardUITests/ForwardUITests.swift` | Add creation-to-card regression tests using the actual app and persistence. |
| `Forward/Views/EventDetailView.swift` | Add descriptive accessibility labels to edit/save/back controls only if needed for reliable user-facing navigation in tests; preserve behavior. |

## Task 1: Add custom emoji creation with persistence regression coverage

**Interfaces:**
- Consumes `EventListViewModel.addEvent(title:emoji:date:location:category:notes:) throws -> Event`, the existing `Event.emoji: String`, and the edit page's existing `TextField("Emoji", ...)`.
- Retains `@State private var selectedEmoji: String = "🎉"` as the creation screen's single source of truth.
- Produces a private computed `emojiForSaving: String` in `CreateEventView`: trim whitespace/newlines, limit to two `Character` values, return 🎉 if empty. This is view-specific input handling, not a new model/service abstraction.

- [x] **Step 1: Establish the baseline and test entry points.** Use XcodeBuildMCP `session_show_defaults`, then set `Forward.xcodeproj`, scheme `Forward`, Debug, and iPhone 17 if needed. Inspect the create overlay and event detail controls. Add meaningful accessibility labels only where existing text cannot identify the controls; avoid coordinate-based UI test navigation.
- [x] **Step 2: Write behavior tests in `ForwardUITests.swift`.** Use `XCUIApplication()` with unique event names, the real create screen, and actual persistence. Give the emoji field the accessible label `Emoji`, and scope saved emoji assertions to the uniquely named card/detail rather than matching any emoji in the app. Add these test cases:
  - `testCreateEventWithCustomEmojiPersistsAndCanBeEdited`: enter 🧑🏽‍🚀 through the create field, save, assert the named card contains 🧑🏽‍🚀; terminate/relaunch and assert it remains; open details, enter edit mode, assert the Emoji field value is 🧑🏽‍🚀; replace with 🦦, save, return, and assert the card contains 🦦.
  - `testCreateEventWithoutChoosingEmojiUsesDefault`: fill only the required title/date, save, assert the named card contains 🎉, then reopen and verify the stored value is 🎉.
  - `testCreateEventWithBlankEmojiUsesDefault`: create separate events with the Emoji field cleared and with whitespace-only input; assert each saves successfully with 🎉.
  - `testCreateEventSavesLatestEmojiChoice`: cover custom → preset and preset → custom, saving a separate event for each order and asserting the latest value on its card. Include a pasted two-emoji value such as 🦦🌙 and verify it survives reopening, matching edit behavior.
  - `testCreateEventLimitsCustomEmojiWithoutSplittingCharacters`: enter 🧑🏽‍🚀🌙🎈, save, reopen, and assert the stored/displayed value is 🧑🏽‍🚀🌙.
  Tests should find or scroll to the emoji controls with bounded gestures, dismiss the keyboard before saving when necessary, wait for transitions, and delete only their own uniquely named events afterward.
- [x] **Step 3: Run the new tests before implementation.** Use XcodeBuildMCP `test_sim` with `extraArgs: ["-only-testing:ForwardUITests/ForwardUITests/testCreateEventWithCustomEmojiPersistsAndCanBeEdited"]` first, then the other new test selectors. Expect custom/blank input cases to fail because creation has no editable Emoji field. The untouched-default case may already pass; keep it as a regression baseline. Resolve runner/navigation failures before treating a failure as evidence of missing behavior.
- [x] **Step 4: Extend the creation form.** Add the `Emoji` text field above the preset grid, bind it to `selectedEmoji`, cap user input with `.onChange` using `String(value.prefix(2))` as the edit screen does, and disable autocorrection/capitalization for this field. Use the optional label/helper copy above and existing field styling. Keep presets bound to the same state. Use `emojiForSaving` in `saveEvent()` and remove the nonempty emoji requirement from `isFormValid`; preserve title/date checks.
- [x] **Step 5: Run the focused regression suite.** Call XcodeBuildMCP `test_sim` with the five new `-only-testing:ForwardUITests/ForwardUITests/<testName>` selectors. Expected: all new tests pass, with no skipped cases or persistence assertions omitted. If the scheme does not expose the UI test target, investigate the existing scheme before making any configuration change.
- [x] **Step 6: Verify on the simulator.** Build/run with XcodeBuildMCP and inspect the UI. Confirm the native emoji keyboard can enter a compound emoji, presets still work, cleared input saves 🎉, and controls remain reachable with the keyboard open on iPhone 17 and iPhone 16e. Check larger Dynamic Type text manually. If showing proof to the user, use the plugin's `ios-simulator-browser` workflow and verify a live frame inside Codex, rather than stopping at the standalone Simulator window.
- [x] **Step 7: Review the diff and report evidence.** Confirm only the intended creation behavior, tests, and necessary accessibility labels changed. Report executed tests, simulator checks, and any remaining limitations. Do not commit, close issue #6, or mark it complete before verification and explicit authorization for those GitHub/git actions.

## Execution recommendation

Use inline execution for this small change: one UI state value and the existing save path carry the feature. Review the proposed two-character compatibility behavior and retained preset grid before implementation. Implementation and verification are complete.

## Execution results

- Implemented the existing form extension without changing the model or storage interfaces.
- Kept feature tests in `ForwardUITests/EventCreationEmojiUITests.swift` to avoid expanding the template suite. Added accessible labels for edit/save/back/delete actions used by real UI tests.
- Observed the custom-input test fail before implementation because the creation field was missing.
- Full iPhone 17 suite: zero failures; all five feature cases passed. Corrected test scrolling to target the form and locate lazy home-list records.
- iPhone 16e: custom creation, relaunch persistence, and editing test passed; exported creation/card screenshots from its result bundle.
- Browser mirror visually verified on iPhone 17. Largest accessibility text exposes existing horizontal overflow in the form/date picker; left outside this scoped change and restored the original text size. Compound emoji was verified via system paste; native emoji-keyboard search was not separately exercised.
- Fresh review found no production correctness issues; the identified offscreen-card test lookup gap was corrected before the passing full suite.
