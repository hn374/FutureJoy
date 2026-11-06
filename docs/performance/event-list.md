# Event list performance

Issue #8 uses a disk-backed, CloudKit-disabled synthetic store with 10,000 events on an iPhone 17 Pro simulator running iOS 26.1 (Xcode 26.1.1).

Run the focused tests on a disposable simulator signed out of personal iCloud:

```sh
xcodebuild test -project Forward.xcodeproj -scheme Forward \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' \
  -parallel-testing-enabled NO \
  -only-testing:ForwardTests/EventListPerformanceTests
```

The tests exercise the actual view model and SwiftData store, including repeated event dates, refresh after edits, creation/deletion, filter changes, selection and calendar-day archiving. Hosted UI checks traverse the list and capture its final viewport.

## Bottleneck and change

The original startup performed four full list fetches across initialization and appearance. Archiving fetched every unarchived event and computed calendar differences on the main actor. Rows also created a date formatter on each evaluation, and the lazy event container sat under an eager stack.

The change removes redundant fetches, queries only unarchived dates before today's local midnight, saves only when archiving changed records, reuses date formatting, and exposes cards directly to one lazy scroll stack. Appearance still refreshes after returning from detail. Full-fetch semantics remain: these results do not justify pagination's mutation and selection complexity.

## Measurement limits

Startup measures a fresh model context with a reused container, not cold process launch. Hosted first layout includes a deliberate 100 ms run-loop wait. Its test retains four controllers (including warmup) through teardown to avoid a Swift runtime isolated-deinit crash on this simulator runtime. Memory metrics include retained screens and test-process overhead; they do not establish single-screen steady-state memory.

Scripted traversal uses large scroll jumps and intentional waits. It does not measure continuous-scroll frame rates or hitch counts. Results on one simulator with three measured repetitions do not establish physical-device performance. Use Instruments on a representative device before making frame-rate claims.

## Observed comparison

Six focused tests passed on both the original source at `a55ce829` and the candidate. Three measured iterations with the same scene-attached hosting harness:

| Metric | Before | After |
| --- | ---: | ---: |
| View-model startup mean | 428 ms | 89 ms |
| Hosted first-layout mean | 994 ms | 293 ms |
| Layout peak physical memory mean | 128.8 MB | 113.2 MB |
| Layout memory growth mean | 17.8 MB | 12.9 MB |
| Scripted traversal including waits | 785 ms | 783 ms |

Startup improved about 79% and hosted first layout about 71%. Scripted traversal was effectively unchanged. The final viewport was inspected and showed cards from the last date bucket, 1,000 days ahead, after traversing the 10,000-event list. Two existing sample UI tests also passed, covering detail editing, navigation, deletion, relaunch persistence and sample/normal-store isolation.

The result bundles for this run were `/tmp/forward-issue8-baseline5.xcresult`, `/tmp/forward-issue8-after2.xcresult`, and `/tmp/forward-issue8-ui.xcresult`. These are temporary local artifacts; rerun the commands for fresh evidence.
