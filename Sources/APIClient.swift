import Foundation

enum APIError: LocalizedError {
    case invalidURL, insecureURL, invalidResponse, server(String), incompleteStream
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "올바른 서버 주소를 입력해주세요. 예: https://dots.example.com"
        case .insecureURL: return "아이폰 연결에는 HTTPS 서버 주소를 사용해주세요."
        case .invalidResponse: return "서버 응답을 읽지 못했습니다. OpenDots 서버인지 확인해주세요."
        case .server(let message): return message
        case .incompleteStream: return "응답이 끝나기 전에 연결이 끊겼습니다. 대화 기록을 새로 불러옵니다."
        }
    }
}

final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct APIClient {
    let baseURL: URL
    let token: String
    private let session: URLSession

    static func validateURL(_ text: String) throws -> URL {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/" else { throw APIError.invalidURL }
        let loopback = ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host.lowercased())
        guard url.scheme?.lowercased() == "https" || (url.scheme?.lowercased() == "http" && loopback) else { throw APIError.insecureURL }
        return url
    }

    init(baseURL: URL, token: String, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.token = token
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 360
        self.session = session ?? URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
    }

    private func request(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        let url = baseURL.appendingPathComponent("api").appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func check(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            struct Failure: Decodable { let error: String }
            let text = (try? JSONDecoder().decode(Failure.self, from: data).error) ?? "서버 요청 실패 (\(http.statusCode))"
            throw APIError.server(text)
        }
    }

    private func load<T: Decodable>(_ path: String, method: String = "GET", body: [String: String]? = nil) async throws -> T {
        let requestBody = try body.map { try JSONEncoder().encode($0) }
        let (data, response) = try await session.data(for: request(path, method: method, body: requestBody))
        try check(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func workspace() async throws -> Workspace { try await load("workspace") }
    func messages(_ id: String) async throws -> [ChatMessage] { try await load("conversations/\(id)/messages") }
    func conversation(dotId: String, title: String) async throws -> Conversation {
        try await load("conversations", method: "POST", body: ["dotId": dotId, "title": title])
    }
    func pages(_ spaceId: String) async throws -> [Page] { try await load("spaces/\(spaceId)/pages") }
    func page(_ spaceId: String, _ id: String) async throws -> Page { try await load("spaces/\(spaceId)/pages/\(id)") }
    func saveConversation(_ id: String, title: String) async throws -> Page {
        try await load("conversations/\(id)/page", method: "POST", body: ["title": title])
    }
    func updatePage(_ page: Page, title: String, content: String) async throws -> Page {
        struct Patch: Encodable { let title: String; let content: String; let expectedRevision: Int }
        let body = try JSONEncoder().encode(Patch(title: title, content: content, expectedRevision: page.revision))
        let (data, response) = try await session.data(for: request("spaces/\(page.spaceId)/pages/\(page.id)", method: "PATCH", body: body))
        try check(response, data: data)
        return try JSONDecoder().decode(Page.self, from: data)
    }
    func stop(_ id: String) async throws {
        let (data, response) = try await session.data(for: request("conversations/\(id)/stop", method: "POST", body: Data("{}".utf8)))
        try check(response, data: data)
    }
    func turn(_ id: String, prompt: String, receive: @escaping @MainActor (TurnEvent) -> Void) async throws {
        var outbound = request("conversations/\(id)/turn", method: "POST", body: try JSONEncoder().encode(["prompt": prompt]))
        outbound.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: outbound)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if !(200..<300).contains(http.statusCode) {
            var data = Data()
            for try await byte in bytes { data.append(byte); if data.count > 65536 { break } }
            try check(response, data: data)
        }
        var completed = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let event = try TurnEvent.decode(line)
            if case .failure(let text) = event { throw APIError.server(text) }
            if case .done = event { completed = true }
            await receive(event)
        }
        if !completed { throw APIError.incompleteStream }
    }
}
