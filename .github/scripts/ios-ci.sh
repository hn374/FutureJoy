#!/bin/bash
set -euo pipefail

# Use a disposable simulator signed out of iCloud, with default simulator signing.
: "${SIMULATOR_ID:?Set SIMULATOR_ID to a disposable iOS 26.1 simulator}"
: "${RUNNER_TEMP:?Set RUNNER_TEMP to a directory for CI output}"
mkdir -p "$RUNNER_TEMP"

test_filters=(
  -only-testing:ForwardTests
  -skip-testing:ForwardTests/EventListBenchmarkTests
  -only-testing:ForwardUITests/EventCreationEmojiUITests/testCreateEventWithCustomEmojiPersistsAndCanBeEdited
  -only-testing:ForwardUITests/SimulatorSampleDataUITests/testProfilesSwitchPersistAndResetIndependently
  -only-testing:ForwardUITests/SimulatorSampleDataUITests/testSampleEditsAndDeletionPersistUntilExplicitReset
  -only-testing:ForwardUITests/SimulatorSampleDataUITests/testSwitchingModesAndResetPreserveNormalEvents
  -only-testing:ForwardUITests/SimulatorSampleDataUITests/testArchivedEventRescheduledToFutureMovesListsAndPersists
  -only-testing:ForwardUITests/SimulatorSampleDataUITests/testArchivedEventRescheduledToTodayMovesListsAndPersists
)
build_args=(
  -project Forward.xcodeproj
  -scheme Forward
  -configuration Debug
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID"
  -derivedDataPath "$RUNNER_TEMP/ForwardDerivedData"
)

# The caller starts simulator boot; compile while it finishes starting.
xcodebuild build-for-testing "${build_args[@]}" \
  2>&1 | tee "$RUNNER_TEMP/forward-build.log"
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcodebuild test-without-building "${build_args[@]}" "${test_filters[@]}" \
  -parallel-testing-enabled NO \
  -resultBundlePath "$RUNNER_TEMP/ForwardTests.xcresult" \
  2>&1 | tee "$RUNNER_TEMP/forward-tests.log"

# Xcode can ignore an unmatched test filter. Require every selected test to run.
xcrun xcresulttool get test-results tests \
  --path "$RUNNER_TEMP/ForwardTests.xcresult" > "$RUNNER_TEMP/forward-test-tree.json"
python3 - "$RUNNER_TEMP/forward-test-tree.json" "${test_filters[@]}" <<'PYTHON'
import json
import sys


def passed_tests(nodes):
    for node in nodes:
        if node.get("nodeType") == "Test Case" and node.get("result") == "Passed":
            yield node["nodeIdentifierURL"].split("/Forward/", 1)[1]
        yield from passed_tests(node.get("children", []))


with open(sys.argv[1]) as report:
    passed = set(passed_tests(json.load(report)["testNodes"]))
# Required functional coverage; update this inventory when renaming/removing a test.
required_unit_tests = {
    "ForwardTests/EventListBehaviorTests/testEventCardsTruncateLongTitlesAndKeepMetadataReadable",
    "ForwardTests/EventListBehaviorTests/testTenThousandEventsRemainCompleteThroughMutationAndFilterChanges",
    "ForwardTests/EventListBehaviorTests/testBulkSelectionSurvivesRefreshAndDeletesOnlySelectedEvents",
    "ForwardTests/EventListBehaviorTests/testArchiveUsesCalendarDayBoundary",
    "ForwardTests/EventListBehaviorTests/testTenThousandEventScrollTraversalRendersFinalCard",
    "ForwardTests/SampleDataLaunchModeTests/testNamedProfilesRequireOptInAndRejectMalformedValues",
    "ForwardTests/SampleDataLaunchModeTests/testSampleModeRequiresExplicitOptIn",
    "ForwardTests/SampleDataLaunchModeTests/testOptInAndResetAreRestrictedToDebugSimulator",
    "ForwardTests/SimulatorSampleStoreTests/testProfilesPersistIndependentlyAndResetOnlyActiveStore",
    "ForwardTests/SimulatorSampleStoreTests/testProfileFixturesHaveDistinctScenarios",
    "ForwardTests/SimulatorSampleStoreTests/testSessionSavesPendingChangesAndClearsOldContextOnSwitchAndReset",
    "ForwardTests/SimulatorSampleStoreTests/testFailedProfileSwitchKeepsActiveSessionAndSavedData",
    "ForwardTests/SimulatorSampleStoreTests/testFirstLaunchPersistsRepresentativeFixtures",
    "ForwardTests/SimulatorSampleStoreTests/testRelaunchPreservesEditsDeletionsAndOriginalDates",
    "ForwardTests/SimulatorSampleStoreTests/testDeletingEveryEventDoesNotReseedOnRelaunch",
    "ForwardTests/SimulatorSampleStoreTests/testResetRestoresFixturesAndRemovesDeveloperEvents",
    "ForwardTests/SimulatorSampleStoreTests/testCalendarDaysAcrossDSTLeapDayAndYearBoundary",
    "ForwardTests/SimulatorSampleStoreTests/testSeedAndResetLeaveNormalStoreAndMigrationPreferenceUnchanged",
    "ForwardTests/SimulatorSampleStoreTests/testInvalidSampleDirectoryThrowsWithoutChangingSiblingData",
}
missing = required_unit_tests - passed
if missing:
    raise SystemExit("Required unit tests did not pass or were not found: " + ", ".join(sorted(missing)))
for test_filter in sys.argv[2:]:
    flag, selection = test_filter.split(":", 1)
    matches = any(test == selection or test.startswith(selection + "/") for test in passed)
    if flag == "-only-testing" and not matches:
        raise SystemExit("Selected tests did not pass or were not found: " + selection)
    if flag == "-skip-testing" and matches:
        raise SystemExit("Excluded tests unexpectedly ran: " + selection)
print("Verified every selected test ran and passed; benchmarks were excluded.")
PYTHON
