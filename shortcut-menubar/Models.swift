import Foundation

// MARK: - User

struct MemberInfo: Decodable {
    let mentionName: String
}

// MARK: - Story

struct Story: Decodable, Identifiable {
    let id: Int
    let name: String
    let storyType: String?
    let appUrl: String
    let blocked: Bool?
    let workflowId: Int
    let workflowStateId: Int
    let groupId: String?
    let epicId: Int?
}

struct StorySearchResults: Decodable {
    let data: [Story]
}

// MARK: - Team

struct Team: Decodable, Identifiable {
    let id: String
    let name: String
}

// MARK: - Epic

struct Epic: Decodable, Identifiable {
    let id: Int
    let name: String
}

// MARK: - Workflow

struct WorkflowState: Decodable, Identifiable {
    let id: Int
    let name: String
    let type: String
    let position: Int
}

struct Workflow: Decodable, Identifiable {
    let id: Int
    let name: String
    let states: [WorkflowState]
}
