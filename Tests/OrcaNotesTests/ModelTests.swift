import XCTest
@testable import OrcaNotesCore
@testable import OrcaShared

final class ModelTests: XCTestCase {
    func testIsInstalledMatchesTags() {
        let installed = ["gemma2:2b", "llama3.2:3b", "mymodel:latest"]
        XCTAssertTrue(ModelCatalog.isInstalled("llama3.2:3b", in: installed))
        XCTAssertTrue(ModelCatalog.isInstalled("mymodel", in: installed))
        XCTAssertFalse(ModelCatalog.isInstalled("qwen2.5:7b", in: installed))
        XCTAssertFalse(ModelCatalog.isInstalled("gemma2:9b", in: installed))
    }
    func testChoicesIncludeInstalledExtrasButNotEmbeddings() {
        let c = ModelCatalog.llmChoices(installed: ["gemma2:2b", "nomic-embed-text:latest", "llama3.2:3b"])
        XCTAssertEqual(c.first, ModelCatalog.defaultLLM)
        XCTAssertTrue(c.contains("gemma2:2b"))
        XCTAssertFalse(c.contains("nomic-embed-text:latest"))
        XCTAssertEqual(c.filter { $0 == "llama3.2:3b" }.count, 1)
    }
    func testDefaultSpeechModelInCatalog() {
        XCTAssertNotNil(ModelCatalog.speechModel(ModelCatalog.defaultSpeechModel))
    }
    func testChunkKeepsShortTextWhole() {
        XCTAssertEqual(LLMClient.chunk("short text", limit: 100), ["short text"])
    }
    func testChunkSplitsLongTextWithinLimit() {
        let text = Array(repeating: "This is one sentence about the roadmap.", count: 200).joined(separator: " ")
        let parts = LLMClient.chunk(text, limit: 1000)
        XCTAssertGreaterThan(parts.count, 1)
        XCTAssertTrue(parts.allSatisfy { $0.count <= 1000 })
        XCTAssertTrue(parts.joined().contains("roadmap"))
    }
    func testStripThinking() {
        XCTAssertEqual(OnDeviceLLM.stripThinking("<think>\nplan it\n</think>\n\n## Summary\n- A"), "## Summary\n- A")
        XCTAssertEqual(OnDeviceLLM.stripThinking("No thinking here."), "No thinking here.")
        XCTAssertEqual(OnDeviceLLM.stripThinking("Answer <think>ran out of tokens"), "Answer")
    }
    func testPhoneCatalog() {
        XCTAssertNotNil(ModelCatalog.phoneLLM(ModelCatalog.defaultPhoneLLM))
        XCTAssertTrue(ModelCatalog.phoneLLMs.allSatisfy { $0.sizeGB < 2 })
        #if os(macOS)
        XCTAssertFalse(AIProvider.supported.contains(.openModel))
        #endif
    }
    func testAcceptPolish() {
        XCTAssertTrue(LLMClient.acceptPolish(original: "see you at five", output: "See you at five."))
        XCTAssertFalse(LLMClient.acceptPolish(original: "see you", output: "Here is the edited text: See you."))
        XCTAssertFalse(LLMClient.acceptPolish(original: "hi", output: String(repeating: "x", count: 200)))
        XCTAssertFalse(LLMClient.acceptPolish(original: "hi", output: "  "))
    }
}
