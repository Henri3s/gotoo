import Foundation

struct AIMessage: Identifiable {
    let id: UUID
    let role: Role
    let content: String
    
    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
    }
    
    enum Role { case user, assistant, system, error }
}
