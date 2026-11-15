# Issue #62: shared event draft preparation

**Merge hold: do not merge until [issue #60](https://github.com/hn374/FutureJoy/issues/60) lands.** Hoang approved implementing #62 first, with this explicit dependency.

The draft module prepares and validates fields without persistence or list side effects. Creation currently saves through `EventListViewModel.addEvent`; editing still applies prepared fields and saves through its existing owner. These are transitional integration points.

Before merging:

- Rebase onto the landed #60 change and route prepared edits through its lifecycle save/reschedule API.
- Reuse one calendar-day rule across draft preparation, lifecycle validation, and archive reconciliation. Avoid parallel helpers or persistence owners.
- Preserve untouched legacy emoji and explicit user-touch history, creation's blank emoji default, editing's blank rejection, validation precedence, and optional-field normalization.
- Rerun functional unit tests, focused creation/edit/cancel/date UI regressions, and the repository CI gate after that integration.

This refactor does not fix persistence rollback (#52), automatic day/import refresh (#53), or draft dismissal behavior (#58). No CloudKit cross-device or physical-device verification is claimed.

## Implementation

`EventDraft` prepares fields and returns typed validation errors; `EventCalendarDay` shares the existing day-boundary rule. Both forms consume prepared values. Emoji input formatting and edit touch/reset tracking are preserved. Creation now also revalidates when Save is invoked, so a draft that became stale after midnight cannot bypass validation through old button state.

## Verification

Astra independently reviewed the complete implementation: no Critical, Important, or Minor findings. No corrective changes requested. The final combined run passed all 35 unit tests and 18 UI tests (53 total), with the exact selected inventory verified and opt-in benchmarks absent. Result: `/tmp/Forward62Final.xcresult`; log: `/tmp/Forward62Final.log`. The implementation diff is unchanged from Astra's reviewed snapshot. The repository local CI gate (`bash .github/scripts/ios-ci.sh`) also passed: 35 unit tests plus its 6 selected UI cases, 41 total. The script verified every required unit/selected UI case ran and benchmarks did not. Result: `/tmp/Forward62CI/ForwardTests.xcresult`; log: `/tmp/Forward62CI.log`.

Verification used Xcode 26.1.1 and a dedicated disposable iPhone 17 simulator on iOS 26.1, signed out of personal iCloud, with parallel testing disabled. `git diff --check` and CI shell syntax checks passed.

The work remains local on `codex/event-draft-62`; no push, PR, or merge was performed. Preserve this hold in any later PR description.
