import XCTest
@testable import OrcaNotesCore
@testable import OrcaShared

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
    func testStripTags() {
        XCTAssertEqual(CaptionLogic.stripTags("Ship on Friday. [silence]"), "Ship on Friday.")
        XCTAssertEqual(CaptionLogic.stripTags("[BLANK_AUDIO] hello (music) there"), "hello there")
        XCTAssertEqual(CaptionLogic.stripTags("call (555) now"), "call (555) now")
        XCTAssertEqual(CaptionLogic.stripTags("Wednesday. (laughs)"), "Wednesday.")
        XCTAssertEqual(CaptionLogic.stripTags("(muffled speaking) Hello."), "Hello.")
    }
    func testNoiseFloorAdapts() {
        var floor: Float = 0.001
        for _ in 0..<50 { floor = CaptionLogic.updateNoiseFloor(floor, blockRMS: 0.0005) }
        XCTAssertEqual(floor, 0.0005, accuracy: 0.0001)
        // quiet mic: speech at 0.003 passes
        XCTAssertGreaterThan(Float(0.003), CaptionLogic.speechThreshold(noiseFloor: floor))
        // speech must not drag the floor up quickly
        for _ in 0..<20 { floor = CaptionLogic.updateNoiseFloor(floor, blockRMS: 0.05) }
        XCTAssertLessThan(floor, 0.01)
        // noisy room: threshold rises
        XCTAssertEqual(CaptionLogic.speechThreshold(noiseFloor: 0.02), 0.06, accuracy: 0.0001)
        XCTAssertEqual(CaptionLogic.speechThreshold(noiseFloor: 0), CaptionLogic.absoluteSpeechFloor)
    }
    func testMarkdown() {
        let one = [CaptionLine(speaker: "You", text: "Hi", offset: 65)]
        XCTAssertEqual(CaptionLogic.markdown(one), "[01:05] Hi")
        let two = [CaptionLine(speaker: "You", text: "Hi", offset: 65), CaptionLine(speaker: "Them", text: "Hey", offset: 70)]
        XCTAssertEqual(CaptionLogic.markdown(two), "**You** [01:05]: Hi\n\n**Them** [01:10]: Hey")
    }
}
