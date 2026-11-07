# Forward Branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Present the app as Forward while preserving existing data and behavior.

**Architecture:** Targeted SwiftUI copy and main-target plist changes. Extend the
existing UI coverage and document retained legacy references and verification.

**Tech Stack:** SwiftUI, SwiftData, XCTest, Xcode 26.1.1 / iOS 26.1.

**Spec:** `docs/superpowers/specs/2026-11-07-forward-branding-design.md`

## Global Constraints

- Future/Past navigation stays unchanged.
- Preserve bundle IDs, signing, CloudKit identifiers, entitlements, Event schema,
  stored keys, migration logic, sample-store paths, and Documents/FutureJoy.store.
- Do not rename the repository, migrate data, redesign the icon or publish changes.
- Preserve the Forward Dev suffix and leave that unsupported target intact.
- Linux source checks cannot establish iOS runtime behavior or sync.

## Review Focus

- Both list states expose Forward at normal and accessibility XXXL sizes.
- Installed names come from the processed Debug/Release plist; Dev stays separate.
- Accessible title remains a heading; screenshots alone do not prove output.
- Normal-data upgrades retain events/defaults without a backend change or reset.
- CloudKit sync requires a working baseline and separate signed-in device checks.

### Task 1: Visible brand, regression coverage, and verification notes

**Files:** Modify `Forward/Views/HomeView.swift`, `Forward/Info.plist`,
`ForwardUITests/ListSwitchingUITests.swift`, and `README.md`. Create
`docs/verification/forward-branding.md` for the retained-reference audit and Mac
commands/checklist. No internal symbol or persistence changes.

**Interfaces:** Consumes the existing appTitle, main-target plist, and UI test
launch/screenshot helpers. Produces Forward branding with unchanged event APIs.

- [x] Update existing name assertions to Forward and add visible-title assertions
  before screenshots in Future and Past at normal and largest text sizes.
- [x] Attempt the focused UI tests before changing production copy. If Xcode is
  absent, record the blocker; do not describe source checks as a red/green run.
- [x] Change only the appTitle literal and add CFBundleDisplayName to the main
  plist. Audit strings/localizations/assets for other active brand references.
- [x] Replace transitional README copy, update the run instruction, and document
  every retained-reference category and explicit Mac verification commands.
- [x] Check plist syntax, inspect the diff and remaining references, and confirm
  compatibility-sensitive files are unchanged. Attempt relevant Xcode checks;
  record unavailable runtime checks as pending.
- [x] Obtain a fresh final review and address material findings. Keep the patch
  reviewable locally; do not publish or claim unexecuted tests passed.

## Execution record

- Approved design; user authorized implementation in this chat.
- Native execution in the existing cloud checkout on branch `work`.
- Ruling: use the supplied disposable checkout without another worktree; no
  shared main branch is being edited. Wrong isolation assumptions could cause
  conflicts, so inspect status and preserve pre-existing changes.
- Ruling: update UI tests first, but continue with the approved source change
  when Apple tooling is unavailable. Runtime regressions remain possible until
  the documented Mac checks run; no substitute source-text tests are added.
- Source implementation and documentation completed. Python plist parsing and
  `git diff --check` passed; ten compatibility/behavior/configuration files were
  confirmed byte-identical to HEAD. All three icon PNGs were visually inspected
  and contain no text; no localization resources were found.
- Focused UI test execution (before production changes), functional unit tests,
  and Release build attempts all stopped with `xcodebuild: command not found`
  (exit 127). No runtime red/green cycle or passing iOS suite is claimed.
- Fresh final Astra review: no actionable findings; ready for Mac verification.
  No deferred minor findings. Mac/device checks remain pending in
  `docs/verification/forward-branding.md`. Patch retained locally for review.
