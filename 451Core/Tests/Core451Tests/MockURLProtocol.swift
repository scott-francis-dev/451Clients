import XCTest
@testable import Core451

/// Intercepts URLSession traffic so request construction can be asserted
/// without a live server. Install it via `MockURLProtocol.makeSession()`.
final class MockURLProtocol: URLProtocol {

    /// Returns the response for a request. Set this in each test.
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Every request that reached the transport, in order.
    nonisolated(unsafe) private(set) static var recorded: [URLRequest] = []

    static func reset() {
        handler = nil
        recorded = []
    }

    /// A session whose traffic is served entirely by this protocol.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Convenience: respond with a JSON body and status code for any request.
    static func respond(status: Int = 200, json: String = "{}") {
        handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(json.utf8))
        }
    }

    /// URLProtocol strips `httpBody` when handing a request to the loader,
    /// so read it back through the body stream instead.
    static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.recorded.append(request)

        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// Proves the harness itself works, so a failure in a request-contract test
/// points at the code under test rather than at the mock.
final class MockURLProtocolTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testInterceptsRequestAndReturnsStubbedResponse() async throws {
        MockURLProtocol.respond(status: 201, json: #"{"ok":true}"#)
        let session = MockURLProtocol.makeSession()

        let url = URL(string: "https://api.451.info/api/thing")!
        let (data, response) = try await session.data(from: url)

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 201)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"ok":true}"#)
        XCTAssertEqual(MockURLProtocol.recorded.count, 1)
        XCTAssertEqual(MockURLProtocol.recorded.first?.url, url)
    }

    func testCapturesRequestBody() async throws {
        MockURLProtocol.respond()
        let session = MockURLProtocol.makeSession()

        var request = URLRequest(url: URL(string: "https://api.451.info/api/thing")!)
        request.httpMethod = "POST"
        request.httpBody = Data(#"{"hello":"world"}"#.utf8)
        _ = try await session.data(for: request)

        let captured = try XCTUnwrap(MockURLProtocol.recorded.first)
        let body = try XCTUnwrap(MockURLProtocol.body(of: captured))
        XCTAssertEqual(String(decoding: body, as: UTF8.self), #"{"hello":"world"}"#)
    }
}
