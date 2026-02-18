import Testing
@testable import MacPilot

@Suite("PromptBuilder")
struct PromptBuilderTests {

    // MARK: - Single-turn arguments

    @Test("Single-turn arguments include prompt and defaults")
    func singleTurnDefaults() {
        let args = PromptBuilder.arguments(for: "Hello")

        #expect(args.contains("-p"))
        #expect(args.contains("Hello"))
        #expect(args.contains("--output-format"))
        #expect(args.contains("json"))
        #expect(args.contains("--model"))
        #expect(args.contains("sonnet"))
        #expect(args.contains("--max-turns"))
        #expect(args.contains("1"))
        #expect(args.contains("--no-session-persistence"))
        #expect(args.contains("--append-system-prompt"))
    }

    @Test("Single-turn arguments respect custom model and maxTurns")
    func singleTurnCustom() {
        let args = PromptBuilder.arguments(for: "Hi", model: "opus", maxTurns: 5)

        #expect(args.contains("opus"))
        #expect(args.contains("5"))
    }

    // MARK: - Session arguments

    @Test("Session arguments omit --no-session-persistence")
    func sessionOmitsNoSessionPersistence() {
        let args = PromptBuilder.sessionArguments(for: "Start chat")

        #expect(!args.contains("--no-session-persistence"))
        #expect(args.contains("-p"))
        #expect(args.contains("Start chat"))
    }

    @Test("Session arguments default to 3 max turns")
    func sessionDefaultMaxTurns() {
        let args = PromptBuilder.sessionArguments(for: "Hello")

        if let index = args.firstIndex(of: "--max-turns") {
            #expect(args[index + 1] == "3")
        } else {
            Issue.record("--max-turns not found in session arguments")
        }
    }

    // MARK: - Resume arguments

    @Test("Resume arguments include --resume with session ID")
    func resumeIncludesSessionID() {
        let args = PromptBuilder.resumeArguments(
            for: "Follow up",
            sessionID: "abc-123"
        )

        #expect(args.contains("--resume"))
        #expect(args.contains("abc-123"))
        #expect(args.contains("Follow up"))
        #expect(!args.contains("--no-session-persistence"))
    }

    @Test("Resume arguments respect custom model")
    func resumeCustomModel() {
        let args = PromptBuilder.resumeArguments(
            for: "Hi",
            sessionID: "xyz",
            model: "opus"
        )

        #expect(args.contains("opus"))
    }

    // MARK: - Common properties

    @Test("All argument builders include empty tools flag")
    func allIncludeEmptyTools() {
        let single = PromptBuilder.arguments(for: "a")
        let session = PromptBuilder.sessionArguments(for: "b")
        let resume = PromptBuilder.resumeArguments(for: "c", sessionID: "d")

        for args in [single, session, resume] {
            if let index = args.firstIndex(of: "--tools") {
                #expect(args[index + 1] == "")
            } else {
                Issue.record("--tools not found")
            }
        }
    }

    @Test("All argument builders include system prompt")
    func allIncludeSystemPrompt() {
        let single = PromptBuilder.arguments(for: "a")
        let session = PromptBuilder.sessionArguments(for: "b")
        let resume = PromptBuilder.resumeArguments(for: "c", sessionID: "d")

        for args in [single, session, resume] {
            #expect(args.contains("--append-system-prompt"))
            #expect(args.contains(PromptBuilder.systemPrompt))
        }
    }
}
