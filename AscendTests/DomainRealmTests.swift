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

    func testDomainXPProgressUsesDisplayedNextRealmTarget() {
        let domain = DomainProgressSnapshot(
            name: "嵌入式 Linux",
            historicalScore: 1,
            currentScore: 1,
            xp: 167,
            knowledgeCount: 14,
            realm: .apprentice,
            currentRealm: .apprentice
        )

        XCTAssertEqual(domain.xpProgress, 167.0 / 300.0, accuracy: 0.000_001)
        XCTAssertGreaterThan(domain.xpProgress, 0.5)
        XCTAssertEqual(domain.masteryProgress, 1.0 / 20.0, accuracy: 0.000_001)
        XCTAssertEqual(domain.advancementProgress, 1.0 / 20.0, accuracy: 0.000_001)
        XCTAssertEqual(domain.nextRealmGateSummary, "掌握 1 / 20 · XP 167 / 300")
    }

    func testRealmProgressExplainsWhenXPIsReadyButMasteryBlocksAdvancement() {
        let domain = DomainProgressSnapshot(
            name: "嵌入式 Linux",
            historicalScore: 17.8,
            currentScore: 17.8,
            xp: 503,
            knowledgeCount: 14,
            realm: .apprentice,
            currentRealm: .apprentice
        )

        XCTAssertEqual(domain.xpProgress, 1)
        XCTAssertEqual(domain.masteryProgress, 17.8 / 20, accuracy: 0.000_001)
        XCTAssertEqual(domain.advancementProgress, 17.8 / 20, accuracy: 0.000_001)
        XCTAssertEqual(domain.nextRealmGateSummary, "掌握 17 / 20 · XP 已达")
    }
}
