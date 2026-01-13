import SwiftUI

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    var stories: [Story] = []
    var currentUser: MemberInfo?
    var workflows: [Int: Workflow] = [:]
    var teams: [String: Team] = [:]
    var epics: [Int: Epic] = [:]
    var isLoading = false
    var error: String?
    var isAuthenticated = false

    private init() {
        isAuthenticated = TokenStorage.shared.hasAPIToken
    }

    func refreshStories() async {
        guard isAuthenticated else {
            error = "Please configure your API token"
            return
        }

        isLoading = true
        error = nil

        do {
            if currentUser == nil {
                currentUser = try await ShortcutAPI.shared.getCurrentMember()
            }
            if workflows.isEmpty {
                let workflowList = try await ShortcutAPI.shared.getWorkflows()
                workflows = Dictionary(uniqueKeysWithValues: workflowList.map { ($0.id, $0) })
            }
            if teams.isEmpty {
                let teamList = try await ShortcutAPI.shared.getTeams()
                teams = Dictionary(uniqueKeysWithValues: teamList.map { ($0.id, $0) })
            }
            guard let user = currentUser else { return }
            let fetchedStories = try await ShortcutAPI.shared.getMyStories(mentionName: user.mentionName)
            
            // Fetch only the epics we need
            let epicIds = Set(fetchedStories.compactMap { $0.epicId })
            let missingEpicIds = epicIds.filter { epics[$0] == nil }
            await withTaskGroup(of: Epic?.self) { group in
                for epicId in missingEpicIds {
                    group.addTask {
                        try? await ShortcutAPI.shared.getEpic(id: epicId)
                    }
                }
                for await epic in group {
                    if let epic = epic {
                        epics[epic.id] = epic
                    }
                }
            }
            
            stories = sortStoriesByWorkflowState(fetchedStories)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func workflowState(for story: Story) -> WorkflowState? {
        workflows[story.workflowId]?.states.first { $0.id == story.workflowStateId }
    }

    func workflow(for story: Story) -> Workflow? {
        workflows[story.workflowId]
    }

    func team(for story: Story) -> Team? {
        guard let groupId = story.groupId else { return nil }
        return teams[groupId]
    }

    func epic(for story: Story) -> Epic? {
        guard let epicId = story.epicId else { return nil }
        return epics[epicId]
    }

    func saveToken(_ token: String) async -> Bool {
        guard TokenStorage.shared.saveAPIToken(token) else {
            error = "Failed to save token"
            return false
        }

        isAuthenticated = true

        guard await ShortcutAPI.shared.validateToken() else {
            // Delete token from storage and clear from memory on validation failure
            TokenStorage.shared.deleteAPIToken()
            isAuthenticated = false
            error = "Invalid API token"
            return false
        }

        await refreshStories()
        return true
    }

    func logout() {
        // Delete token from storage (this also clears cached token from memory)
        TokenStorage.shared.deleteAPIToken()
        isAuthenticated = false
        currentUser = nil
        stories = []
        workflows = [:]
        teams = [:]
        epics = [:]
        error = nil
    }

    private func sortStoriesByWorkflowState(_ stories: [Story]) -> [Story] {
        stories.sorted { story1, story2 in
            let state1 = workflowState(for: story1)
            let state2 = workflowState(for: story2)
            let priority1 = statePriority(state1?.type)
            let priority2 = statePriority(state2?.type)
            
            if priority1 != priority2 {
                return priority1 < priority2
            }
            // Within the same state type, sort by position (higher position first)
            return (state1?.position ?? 0) > (state2?.position ?? 0)
        }
    }

    private func statePriority(_ type: String?) -> Int {
        switch type {
        case "started": 0
        case "unstarted": 1
        case "backlog": 2
        default: 3
        }
    }
}
