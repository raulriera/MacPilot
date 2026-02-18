import SwiftUI

struct GettingStartedView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                GettingStartedHeader()
                HowItWorksSection()
                CapabilitiesSection()
                AvailableToolsSection()
                GetStartedSection()
            }
            .padding(40)
        }
        .frame(minWidth: 520, idealWidth: 520, minHeight: 620, idealHeight: 620)
    }
}

// MARK: - Header

private struct GettingStartedHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.tint)
                .padding(20)
                .glassEffect(.regular, in: .circle)

            Text("Welcome to MacPilot")
                .font(.largeTitle)
                .bold()

            Text("Your privacy-first AI assistant for macOS")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }
}

// MARK: - How It Works

private struct HowItWorksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "How it works", icon: "gearshape.2")

            Text("MacPilot lives in your menu bar and runs in the background. You interact with it through Siri, Apple Shortcuts, or Spotlight \u{2014} no app window needed.")
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .sectionStyle()
    }
}

// MARK: - Capabilities

private struct CapabilitiesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "What you can do", icon: "sparkles")

            VStack(spacing: 0) {
                CapabilityRow(
                    icon: "bubble.left.and.text.bubble.right",
                    title: "Ask questions",
                    description: "Get answers from Claude via Siri or Shortcuts"
                )
                CapabilityRow(
                    icon: "doc.on.clipboard",
                    title: "Summarize clipboard",
                    description: "Explain whatever you just copied"
                )
                CapabilityRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Transform text",
                    description: "Rewrite, refactor, or translate text with an instruction"
                )
                CapabilityRow(
                    icon: "terminal",
                    title: "Run shell commands",
                    description: "Execute whitelisted commands through the AI"
                )
                CapabilityRow(
                    icon: "text.bubble",
                    title: "Multi-turn conversations",
                    description: "Start and continue sessions for complex tasks"
                )
            }
        }
        .sectionStyle()
    }
}

private struct CapabilityRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)

                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

// MARK: - Available Tools

private struct AvailableToolsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Available tools", icon: "wrench.and.screwdriver")

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    ToolBadge(icon: "doc.on.clipboard", name: "Clipboard")
                    ToolBadge(icon: "globe", name: "Web")
                    ToolBadge(icon: "bell", name: "Notification")
                    ToolBadge(icon: "terminal", name: "Shell")
                }
            }
        }
        .sectionStyle()
    }
}

private struct ToolBadge: View {
    let icon: String
    let name: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)

            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 88, height: 68)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }
}

// MARK: - Get Started

private struct GetStartedSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Get started", icon: "arrow.right.circle")

            VStack(alignment: .leading, spacing: 6) {
                Text("Open the **Shortcuts** app and look for MacPilot actions. Compose them with Apple\u{2019}s built-in actions to build your own workflows.")
                    .foregroundStyle(.secondary)

                Text("Try saying **\u{201C}Hey Siri, ask MacPilot a question\u{201D}** to get started right away.")
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)
        }
        .sectionStyle()
    }
}

// MARK: - Shared Components

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
    }
}

private struct SectionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func sectionStyle() -> some View {
        modifier(SectionModifier())
    }
}
