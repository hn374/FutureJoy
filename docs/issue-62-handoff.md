# Issue #62: shared event draft preparation

**Merge hold: do not merge until [issue #60](https://github.com/hn374/FutureJoy/issues/60) lands.** Hoang approved implementing #62 first, with this explicit dependency.

The draft module prepares and validates fields without persistence or list side effects. Creation currently saves through `EventListViewModel.addEvent`; editing still applies prepared fields and saves through its existing owner. These are transitional integration points.

Before merging:

- Rebase onto the landed #60 change and route prepared edits through its lifecycle save/reschedule API.
- Reuse one calendar-day rule across draft preparation, lifecycle validation, and archive reconciliation. Avoid parallel helpers or persistence owners.
- Preserve untouched legacy emoji and explicit user-touch history, creation's blank emoji default, editing's blank rejection, validation precedence, and optional-field normalization.
- Rerun functional unit tests, focused creation/edit/cancel/date UI regressions, and the repository CI gate after that integration.

This refactor does not fix persistence rollback (#52), automatic day/import refresh (#53), or draft dismissal behavior (#58). No CloudKit cross-device or physical-device verification is claimed.

Implementation and verification results will be recorded below when complete.
