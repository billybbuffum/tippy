import XCTest
@testable import TippyModeration

final class DrinkServingTests: XCTestCase {
    func testPresetsAreAboutOneStandardDrink() {
        XCTAssertEqual(DrinkServing.beer.standardDrinks, 1.0, accuracy: 0.02)
        XCTAssertEqual(DrinkServing.wine.standardDrinks, 1.0, accuracy: 0.02)
        XCTAssertEqual(DrinkServing.spirit.standardDrinks, 1.0, accuracy: 0.02)
    }

    func testStrongPintIsMoreThanOneDrink() {
        let pint = DrinkServing(volumeMilliliters: 473, abvPercent: 7)!
        XCTAssertEqual(pint.standardDrinks, 1.87, accuracy: 0.01)
    }

    func testUKUnits() {
        XCTAssertEqual(DrinkServing.beer.ukUnits, 1.75, accuracy: 0.01)
    }

    func testRejectsImpossibleServings() {
        XCTAssertNil(DrinkServing(volumeMilliliters: 0, abvPercent: 5))
        XCTAssertNil(DrinkServing(volumeMilliliters: -10, abvPercent: 5))
        XCTAssertNil(DrinkServing(volumeMilliliters: 355, abvPercent: -1))
        XCTAssertNil(DrinkServing(volumeMilliliters: 355, abvPercent: 101))
        XCTAssertNil(DrinkServing(volumeMilliliters: .nan, abvPercent: 5))
    }

    func testAlcoholFreeIsZero() {
        XCTAssertEqual(DrinkServing(volumeMilliliters: 355, abvPercent: 0)!.standardDrinks, 0)
    }
}
