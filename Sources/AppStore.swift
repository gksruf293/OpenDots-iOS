import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var workspace: Workspace?
    @Published var error: String?
    @Published var connecting = false
    @Published var server: String = UserDefaults.standard.string(forKey: "OpenDots.server") ?? ""
    var client: APIClient? {
        guard let url = try? APIClient.validateURL(server), !server.isEmpty else { return nil }
        return APIClient(baseURL: url, token: TokenStore.read(server: url.absoluteString))
    }

    func connect(address: String, token: String) async -> Bool {
        connecting = true; error = nil
        defer { connecting = false }
        do {
            let url = try APIClient.validateURL(address)
            let client = APIClient(baseURL: url, token: token.trimmingCharacters(in: .whitespacesAndNewlines))
            let snapshot = try await client.workspace()
            guard snapshot.setup.backend == "codex" else { throw APIError.server("현재 앱은 Codex 로컬 모드의 OpenDots 서버에 연결됩니다.") }
            if !snapshot.setup.missing.isEmpty { throw APIError.server(snapshot.setup.detail ?? "PC의 Codex 로그인을 먼저 확인해주세요.") }
            try TokenStore.write(client.token, server: url.absoluteString)
            server = url.absoluteString
            UserDefaults.standard.set(server, forKey: "OpenDots.server")
            workspace = snapshot
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func reload() async {
        guard let client else { return }
        do { workspace = try await client.workspace(); error = nil }
        catch { self.error = error.localizedDescription }
    }
}

@MainActor
final class ChatStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var running = false
    @Published var loaded = false
    @Published var activity = ""
    @Published var error: String?
    private var work: Task<Void, Never>?
    @Published var unsentPrompt: String?
    private var generation = UUID()

    func load(client: APIClient, thread: Conversation) async {
        loaded = false; error = nil
        do { messages = try await client.messages(thread.id); loaded = true }
        catch { self.error = error.localizedDescription }
    }

    func send(client: APIClient, thread: Conversation, prompt: String) {
        guard !running, loaded else { return }
        running = true; activity = "Codex에 연결 중…"; error = nil; unsentPrompt = nil
        let transientId = UUID().uuidString
        let runId = UUID(); generation = runId
        let countBeforeSending = messages.count
        work = Task {
            defer { if generation == runId { running = false; activity = ""; work = nil } }
            do {
                try await client.turn(thread.id, prompt: prompt) { [weak self] event in
                    guard let self, self.generation == runId else { return }
                    switch event {
                    case .delta(let text):
                        self.activity = "답변 중…"
                        if let index = self.messages.firstIndex(where: { $0.id == transientId }) { self.messages[index].content += text }
                        else { self.messages.append(ChatMessage(id: transientId, role: "assistant", content: text)) }
                    case .message(let message):
                        self.messages.removeAll { $0.id == message.id || (message.role == "assistant" && $0.id == transientId) }
                        self.messages.append(message)
                    case .tool(let name): self.activity = name.replacingOccurrences(of: "_", with: " ")
                    case .done, .failure: break
                    }
                }
            } catch {
                guard generation == runId else { return }
                self.error = Task.isCancelled ? "응답을 중지했습니다." : error.localizedDescription
                // Recover only persisted messages; never present a partial draft as a saved answer.
                if !Task.isCancelled, let saved = try? await client.messages(thread.id) { messages = saved }
                if messages.count == countBeforeSending { unsentPrompt = prompt }
            }
        }
    }

    func stop(client: APIClient, thread: Conversation) async {
        do { try await client.stop(thread.id) }
        catch { self.error = error.localizedDescription }
        work?.cancel()
        generation = UUID(); running = false; activity = ""; work = nil
        if let saved = try? await client.messages(thread.id) { messages = saved }
    }
}
