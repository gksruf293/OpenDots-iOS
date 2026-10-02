import XCTest
@testable import OpenDots

final class ProtocolTests: XCTestCase {
    func testDecodesSavedMessageAndStreamErrors() throws {
        let line = #"{"type":"message","message":{"id":"a","role":"assistant","content":"안녕하세요"}}"#
        guard case .message(let message) = try TurnEvent.decode(line) else { return XCTFail("Expected saved message") }
        XCTAssertEqual(message.content, "안녕하세요")
        guard case .failure(let text) = try TurnEvent.decode(#"{"type":"error","message":"Codex limit reached"}"#) else { return XCTFail("Expected error") }
        XCTAssertEqual(text, "Codex limit reached")
        XCTAssertThrowsError(try TurnEvent.decode(#"{"type":"message","message":"wrong shape"}"#))
    }

    func testRejectsUnsafeAndAmbiguousServerAddresses() throws {
        XCTAssertEqual(try APIClient.validateURL("https://dots.example.com").host, "dots.example.com")
        XCTAssertEqual(try APIClient.validateURL("http://127.0.0.1:4310").port, 4310)
        XCTAssertThrowsError(try APIClient.validateURL("http://public.example.com"))
        XCTAssertThrowsError(try APIClient.validateURL("https://user:password@example.com"))
        XCTAssertThrowsError(try APIClient.validateURL("https://example.com/?token=secret"))
        XCTAssertThrowsError(try APIClient.validateURL("https://example.com/another-app"))
        XCTAssertThrowsError(try APIClient.validateURL("not a URL"))
    }

    func testWorkspaceMatchesCurrentCodexServerContract() throws {
        let data = Data(#"{"dots":[{"id":"d","name":"Dot","instructions":"Help","spaceId":"s"}],"spaces":[{"id":"s","name":"Everyday","description":""}],"conversations":[{"id":"t","dotId":"d","title":"Chat"}],"setup":{"backend":"codex","detail":"Ready","missing":[]}}"#.utf8)
        let workspace = try JSONDecoder().decode(Workspace.self, from: data)
        XCTAssertEqual(workspace.setup.backend, "codex")
        XCTAssertEqual(workspace.conversations.first?.dotId, workspace.dots.first?.id)
    }
}
