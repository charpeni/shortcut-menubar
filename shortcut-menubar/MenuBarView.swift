import SwiftUI

struct MenuBarView: View {
    @State private var appState = AppState.shared

    var body: some View {
        if appState.isAuthenticated {
            StoryListView(appState: appState)
                .frame(width: 360, height: 480)
        } else {
            SettingsView(appState: appState)
                .frame(width: 360)
        }
    }
}

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var apiToken = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Connect to Shortcut")
                .font(.headline)

            SecureField("API Token", text: $apiToken)
                .textFieldStyle(.roundedBorder)

            if let error = appState.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                isSaving = true
                Task {
                    _ = await appState.saveToken(apiToken)
                    // Clear the token from the text field after saving
                    apiToken = ""
                    isSaving = false
                }
            } label: {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Connect")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiToken.isEmpty || isSaving)

            HStack {
                Link("Get token", destination: URL(string: "https://app.shortcut.com/settings/account/api-tokens")!)
                    .font(.caption)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

struct StoryListView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }

    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("My Stories")
                    .font(.headline)
                if let user = appState.currentUser {
                    Text("@\(user.mentionName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task { await appState.refreshStories() }
            } label: {
                if appState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.plain)
            .disabled(appState.isLoading)
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if appState.isLoading {
            Spacer()
            ProgressView("Loading stories...")
            Spacer()
        } else if let error = appState.error {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await appState.refreshStories() }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            Spacer()
        } else if appState.stories.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("No active stories")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.stories) { story in
                        StoryRow(
                            story: story,
                            workflowState: appState.workflowState(for: story),
                            workflow: appState.workflow(for: story),
                            team: appState.team(for: story),
                            epic: appState.epic(for: story),
                            userMentionName: appState.currentUser?.mentionName
                        )
                        Divider()
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button { appState.logout() } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Logout")

            Spacer()

            Text("\(appState.stories.count) stories")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Menu {
                Toggle("Launch at Login", isOn: Binding(
                    get: { AppDelegate.launchAtLogin },
                    set: { AppDelegate.launchAtLogin = $0 }
                ))
                Divider()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct StoryRow: View {
    let story: Story
    let workflowState: WorkflowState?
    let workflow: Workflow?
    let team: Team?
    let epic: Epic?
    let userMentionName: String?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Button { openStory() } label: {
                HStack(spacing: 12) {
                    storyTypeIcon
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("#\(story.id, format: .number.grouping(.never))")
                            if let team = team {
                                Text("•")
                                Text(team.name)
                            }
                            if let workflow = workflow {
                                Text("•")
                                Text(workflow.name)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let epic = epic {
                            Text(epic.name)
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }

                        if let state = workflowState {
                            Text(state.name)
                                .font(.caption)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(stateColor(for: state.type).opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        Text(story.name)
                            .font(.subheadline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    if story.blocked == true {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.red)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                storyMenuContent
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 16)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.leading)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .contextMenu {
            storyMenuContent
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    @ViewBuilder
    private var storyMenuContent: some View {
        Button { copyBranchName() } label: {
            Label("Copy Branch Name", systemImage: "arrow.branch")
        }
        Button { copyGitCheckoutCommand() } label: {
            Label("Copy Git Checkout Command", systemImage: "terminal")
        }
        Divider()
        Button { copyStoryLink() } label: {
            Label("Copy Story Link", systemImage: "link")
        }
        Button { openStory() } label: {
            Label("Open in Browser", systemImage: "safari")
        }
    }

    private func stateColor(for type: String) -> Color {
        switch type {
        case "started": .blue
        case "done": .green
        default: .secondary
        }
    }

    @ViewBuilder
    private var storyTypeIcon: some View {
        switch story.storyType ?? "feature" {
        case "bug":
            Image(systemName: "ladybug.fill").foregroundStyle(.red)
        case "chore":
            Image(systemName: "wrench.fill").foregroundStyle(.gray)
        default:
            Image(systemName: "star.fill").foregroundStyle(.yellow)
        }
    }

    private func openStory() {
        guard let url = URL(string: story.appUrl) else { return }
        NSWorkspace.shared.open(url)
    }

    private var branchName: String {
        let slug = String(story.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
            .prefix(50))
        let prefix = userMentionName ?? "user"
        return "\(prefix)/sc-\(story.id)/\(slug)"
    }

    private func copyBranchName() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(branchName, forType: .string)
    }

    private func copyGitCheckoutCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("git checkout -b \(branchName)", forType: .string)
    }

    private func copyStoryLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(story.appUrl, forType: .string)
    }
}

#Preview {
    MenuBarView()
}
