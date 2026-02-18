import SwiftUI
import SwiftData

struct ActivityLogView: View {
    @Query(sort: \ToolExecutionLog.executedAt, order: .reverse)
    private var logs: [ToolExecutionLog]

    var body: some View {
        Group {
            if logs.isEmpty {
                ActivityLogEmptyState()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(logs) { log in
                            ActivityLogCard(log: log)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 440, idealWidth: 440, minHeight: 520, idealHeight: 520)
    }
}

// MARK: - Empty State

private struct ActivityLogEmptyState: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Activity Yet", systemImage: "clock")
        } description: {
            Text("Tool executions will appear here after you use MacPilot through Shortcuts or Siri.")
        }
    }
}

// MARK: - Log Card

private struct ActivityLogCard: View {
    let log: ToolExecutionLog
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ActivityLogCardHeader(log: log, isExpanded: $isExpanded)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                ActivityLogCardDetail(log: log)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .glassEffect(
            .regular.tint(log.isError ? .red : .clear),
            in: .rect(cornerRadius: 12)
        )
        .animation(.snappy(duration: 0.25), value: isExpanded)
    }
}

// MARK: - Card Header

private struct ActivityLogCardHeader: View {
    let log: ToolExecutionLog
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: log.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(log.isError ? .red : .green)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(log.toolName)
                        .fontWeight(.semibold)

                    Text(log.executedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(log.durationMs)ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Detail

private struct ActivityLogCardDetail: View {
    let log: ToolExecutionLog

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !log.arguments.isEmpty {
                DetailBlock(title: "Arguments", content: log.arguments)
            }

            if !log.resultContent.isEmpty {
                DetailBlock(title: log.isError ? "Error" : "Result", content: log.resultContent)
            }

            Text(log.executedAt, format: .dateTime.month().day().hour().minute().second())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 10)
    }
}

// MARK: - Detail Block

private struct DetailBlock: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(content)
                .font(.callout)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5))
                .clipShape(.rect(cornerRadius: 8))
        }
    }
}
