import Testing
@testable import MacPilot

@Suite("TransformTextIntent")
struct TransformTextIntentTests {

    // MARK: - Metadata

    @Test("Title is Transform Text")
    func title() {
        #expect(TransformTextIntent.title == "Transform Text")
    }

    @Test("Does not open app when run")
    func openAppWhenRun() {
        #expect(TransformTextIntent.openAppWhenRun == false)
    }

    // MARK: - Prompt construction

    @Test("Prompt includes instruction before text")
    func promptIncludesInstructionAndText() {
        let prompt = TransformTextIntent.buildPrompt(
            text: "Hello world",
            instruction: "Translate to Spanish"
        )

        #expect(prompt.contains("Instruction: Translate to Spanish"))
        #expect(prompt.contains("Text:\nHello world"))

        let instructionRange = prompt.range(of: "Instruction:")!
        let textRange = prompt.range(of: "Text:")!
        #expect(instructionRange.lowerBound < textRange.lowerBound)
    }

    @Test("Prompt preserves multiline text")
    func promptPreservesMultilineText() {
        let multiline = "Line 1\nLine 2\nLine 3"
        let prompt = TransformTextIntent.buildPrompt(
            text: multiline,
            instruction: "Number each line"
        )

        #expect(prompt.contains("Line 1\nLine 2\nLine 3"))
    }

    @Test("Prompt handles empty instruction")
    func promptWithEmptyInstruction() {
        let prompt = TransformTextIntent.buildPrompt(
            text: "Some text",
            instruction: ""
        )

        #expect(prompt.contains("Instruction: \n"))
        #expect(prompt.contains("Some text"))
    }
}
