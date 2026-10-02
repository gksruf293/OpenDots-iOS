import Foundation

struct Dot: Codable, Identifiable, Hashable {
    let id: String
    let spaceId: String
    let name: String
    let instructions: String
}

struct Space: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
}

struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    let dotId: String
    let title: String
}

struct SetupStatus: Codable {
    let backend: String?
    let detail: String?
    let missing: [String]
}

struct Workspace: Codable {
    let dots: [Dot]
    let spaces: [Space]
    let conversations: [Conversation]
    let setup: SetupStatus
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: String
    let role: String
    var content: String
}

struct Page: Codable, Identifiable, Hashable {
    let id: String
    let spaceId: String
    var title: String
    var content: String
    let revision: Int
}

enum TurnEvent {
    case delta(String)
    case tool(String)
    case message(ChatMessage)
    case done
    case failure(String)

    static func decode(_ line: String) throws -> TurnEvent {
        struct Packet: Decodable {
            let type: String
            let text: String?
            let name: String?
            let message: Payload?
            enum Payload: Decodable {
                case text(String)
                case message(ChatMessage)
                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let text = try? container.decode(String.self) { self = .text(text) }
                    else { self = .message(try container.decode(ChatMessage.self)) }
                }
            }
        }
        let packet = try JSONDecoder().decode(Packet.self, from: Data(line.utf8))
        switch packet.type {
        case "delta": return .delta(packet.text ?? "")
        case "tool": return .tool(packet.name ?? "작업")
        case "message":
            guard case .message(let value)? = packet.message else { throw APIError.invalidResponse }
            return .message(value)
        case "done": return .done
        case "error":
            if case .text(let text)? = packet.message { return .failure(text) }
            return .failure("Codex 요청을 완료하지 못했습니다.")
        default: throw APIError.invalidResponse
        }
    }
}
