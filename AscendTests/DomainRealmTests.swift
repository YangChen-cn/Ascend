import XCTest
@testable import Ascend

final class DomainRealmTests: XCTestCase {
    func testEmptyDomainHasNoRealm() {
        XCTAssertEqual(DomainRealm.resolve(score: 0, xp: 0), .unstarted)
    }

    func testRealmRequiresBothScoreAndXP() {
        XCTAssertEqual(DomainRealm.resolve(score: 75, xp: 299), .apprentice)
        XCTAssertEqual(DomainRealm.resolve(score: 19, xp: 5_000), .apprentice)
        XCTAssertEqual(DomainRealm.resolve(score: 20, xp: 300), .entry)
        XCTAssertEqual(DomainRealm.resolve(score: 60, xp: 3_000), .refining)
    }

    func testDomainsResolveIndependently() {
        let english = DomainRealm.resolve(score: 42, xp: 1_200)
        let embeddedLinux = DomainRealm.resolve(score: 18, xp: 90)

        XCTAssertEqual(english, .advancing)
        XCTAssertEqual(embeddedLinux, .apprentice)
    }
}
