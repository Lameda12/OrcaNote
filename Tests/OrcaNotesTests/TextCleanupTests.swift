import XCTest
@testable import OrcaNotesCore

final class TextCleanupTests: XCTestCase {
    func testRemovesFillersAndRepeats() {
        XCTAssertEqual(TextCleanup.clean("um so the the meeting is uh tomorrow", style: .clean), "So the meeting is tomorrow.")
    }
    func testVerbatimUntouched() {
        XCTAssertEqual(TextCleanup.clean("um git status", style: .verbatim), "um git status")
    }
    func testCasualDropsTrailingPeriod() {
        XCTAssertEqual(TextCleanup.clean("sounds good see you at five.", style: .casual), "Sounds good see you at five")
    }
    func testProfessionalAddsPeriod() {
        XCTAssertEqual(TextCleanup.clean("i will send the report", style: .professional), "I will send the report.")
    }
    func testSpokenNewLine() {
        XCTAssertEqual(TextCleanup.clean("hello new line world", style: .clean), "Hello\nWorld.")
    }
    func testKeepsLegitimateRepeat() {
        XCTAssertEqual(TextCleanup.clean("he had had enough", style: .clean), "He had had enough.")
    }
    func testStyleRules() {
        let r = StyleRules(overrides: ["com.foo": .casual], fallback: .clean)
        XCTAssertEqual(r.style(forBundleID: "com.apple.mail"), .professional)
        XCTAssertEqual(r.style(forBundleID: "com.foo"), .casual)
        XCTAssertEqual(r.style(forBundleID: nil), .clean)
        XCTAssertEqual(r.style(forBundleID: "x.y"), .clean)
    }
}

final class CaptionLogicTests: XCTestCase {
    func testNoiseFilter() {
        XCTAssertTrue(CaptionLogic.isNoise("Thank you."))
        XCTAssertTrue(CaptionLogic.isNoise("[BLANK_AUDIO]"))
        XCTAssertTrue(CaptionLogic.isNoise("  "))
        XCTAssertFalse(CaptionLogic.isNoise("Let's ship on Friday"))
    }
    func testEchoDetection() {
        XCTAssertTrue(CaptionLogic.isEcho("we should ship on friday", of: "I think we should ship on Friday morning"))
        XCTAssertFalse(CaptionLogic.isEcho("sounds good to me", of: "we should ship on friday"))
    }
    func testRMS() {
        XCTAssertEqual(CaptionLogic.rms([0, 0, 0][...]), 0)
        XCTAssertEqual(CaptionLogic.rms([0.5, -0.5][...]), 0.5, accuracy: 0.0001)
    }
    func testMarkdown() {
        let l = [CaptionLine(speaker: "You", text: "Hi", offset: 65)]
        XCTAssertEqual(CaptionLogic.markdown(l), "**You** [01:05]: Hi")
    }
}
