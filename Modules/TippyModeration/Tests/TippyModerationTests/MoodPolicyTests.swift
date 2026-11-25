import XCTest
@testable import TippyModeration

final class MoodPolicyTests: XCTestCase {
    func testPaceIsProRated() {
        // 14 a week, 4 days in: 8 allowed so far; 6 is 0.75 of that.
        XCTAssertEqual(MoodPolicy.pace(drinksSoFar: 6, weeklyGoal: 14, daysElapsed: 4), 0.75, accuracy: 0.0001)
    }

    func testDaysAreClamped() {
        XCTAssertEqual(MoodPolicy.pace(drinksSoFar: 2, weeklyGoal: 14, daysElapsed: 0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(MoodPolicy.pace(drinksSoFar: 14, weeklyGoal: 14, daysElapsed: 9), 1.0, accuracy: 0.0001)
    }

    func testZeroGoal() {
        XCTAssertEqual(MoodPolicy.pace(drinksSoFar: 0, weeklyGoal: 0, daysElapsed: 3), 0)
        XCTAssertEqual(MoodPolicy.pace(drinksSoFar: 1, weeklyGoal: 0, daysElapsed: 3), .infinity)
    }

    func testMoodBands() {
        func mood(_ drinks: Double) -> PetMood {
            MoodPolicy.mood(drinksSoFar: drinks, weeklyGoal: 14, daysElapsed: 7, checkedInToday: true)
        }
        XCTAssertEqual(mood(0), .thriving)
        XCTAssertEqual(mood(11), .thriving)
        XCTAssertEqual(mood(14), .happy)
        XCTAssertEqual(mood(18), .okay)
        XCTAssertEqual(mood(19), .concerned)
    }

    func testWaitingOnlyAfterReminderWithoutCheckIn() {
        XCTAssertEqual(
            MoodPolicy.mood(drinksSoFar: 0, weeklyGoal: 14, daysElapsed: 2, checkedInToday: false, reminderTimePassed: true),
            .waiting
        )
        XCTAssertEqual(
            MoodPolicy.mood(drinksSoFar: 0, weeklyGoal: 14, daysElapsed: 2, checkedInToday: false, reminderTimePassed: false),
            .thriving
        )
        XCTAssertEqual(
            MoodPolicy.mood(drinksSoFar: 0, weeklyGoal: 14, daysElapsed: 2, checkedInToday: true, reminderTimePassed: true),
            .thriving
        )
    }
}
