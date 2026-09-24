import Foundation

/// Одне повідомлення в чаті з асистентом.
struct ChatMessage {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

/// Тип рядка в `ChatViewController` — одна з 4 варіацій:
/// - `header` — велика картка з фото експерта (`AssistentTableViewCell`),
/// - `assistant(text)` — повідомлення від асистента (`AssistentMessageTableViewCell`),
/// - `user(text)` — повідомлення від користувача (`UserMessageTableViewCell`),
/// - `typing` — анімація Typing у `AssistentMessageTableViewCell`.
enum ChatItem {
    case header
    case assistant(String)
    case user(String)
    case typing
}
