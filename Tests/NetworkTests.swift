import XCTest
@testable import OpenDots

final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class NetworkTests: XCTestCase {
    override func tearDown() { StubProtocol.handler = nil; super.tearDown() }
    private func client() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return APIClient(baseURL: URL(string: "https://dots.example.com")!, token: "test-owner-token", session: URLSession(configuration: config))
    }
    func testAuthenticatedMessageHistoryUsesExistingServerRoute() async throws {
        StubProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/conversations/thread/messages")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-owner-token")
            return (200, Data(#"[{"id":"m","role":"assistant","content":"Saved answer"}]"#.utf8))
        }
        let messages = try await client().messages("thread")
        XCTAssertEqual(messages.first?.content, "Saved answer")
    }
    func testRevisionConflictKeepsServerErrorForEditor() async throws {
        StubProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            return (409, Data(#"{"error":"Page changed. Read the latest revision first."}"#.utf8))
        }
        do {
            _ = try await client().updatePage(Page(id: "page", spaceId: "space", title: "Draft", content: "Keep me", revision: 1), title: "Draft", content: "Keep me")
            XCTFail("Expected revision conflict")
        } catch { XCTAssertTrue(error.localizedDescription.contains("latest revision")) }
    }
    func testFailedAuthenticationIsNotDecodedAsMessageHistory() async throws {
        StubProtocol.handler = { _ in (401, Data(#"{"error":"Enter your owner access token."}"#.utf8)) }
        do { _ = try await client().messages("thread"); XCTFail("Expected authentication error") }
        catch { XCTAssertTrue(error.localizedDescription.contains("owner access token")) }
    }
}
