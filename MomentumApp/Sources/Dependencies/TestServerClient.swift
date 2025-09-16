import ComposableArchitecture
import Foundation
import Network

#if DEBUG

    @DependencyClient
    struct TestServerClient {
        var start: @Sendable (UInt16) async throws -> Void
        var stop: @Sendable () async -> Void
    }

    extension TestServerClient: DependencyKey {
        static let liveValue = Self(
            start: { port in
                try await TestServer.shared.start(port: port)
            },
            stop: {
                await TestServer.shared.stop()
            }
        )
    }

    extension DependencyValues {
        var testServer: TestServerClient {
            get { self[TestServerClient.self] }
            set { self[TestServerClient.self] = newValue }
        }
    }

    // MARK: - Test Server Implementation

    actor TestServer {
        static let shared = TestServer()

        private var listener: NWListener?
        private var connections: Set<Connection> = []
        private var logBuffer: [String] = []
        private let maxLogBufferSize = 1000

        func start(port: UInt16) async throws {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            self.listener = listener

            listener.newConnectionHandler = { [weak self] connection in
                Task {
                    await self?.handleNewConnection(connection)
                }
            }

            listener.start(queue: .main)

            TestLogger.log("Test server started on port \(port)")
        }

        func stop() async {
            listener?.cancel()
            listener = nil
            for connection in connections {
                connection.cancel()
            }
            connections.removeAll()
            TestLogger.log("Test server stopped")
        }

        func log(_ message: String) {
            logBuffer.append("\(Date().ISO8601Format()): \(message)")
            if logBuffer.count > maxLogBufferSize {
                logBuffer.removeFirst()
            }
        }

        func getLogs() -> [String] {
            logBuffer
        }

        private func handleNewConnection(_ connection: NWConnection) {
            let conn = Connection(connection: connection) { [weak self] request in
                await self?.handleRequest(request) ?? HTTPResponse(status: 500, body: "Server error")
            }
            connections.insert(conn)
            conn.start()
        }

        private func handleRequest(_ request: HTTPRequest) async -> HTTPResponse {
            TestLogger.log("Handling request: \(request.method) \(request.path)")

            switch (request.method, request.path) {
            case ("POST", "/momentum"):
                return await handleMomentumCommand(request)
            case ("POST", "/show"):
                return await handleShow()
            case ("POST", "/refresh"):
                return await handleRefresh()
            case ("GET", "/logs"):
                return handleGetLogs()
            case ("GET", "/state"):
                return await handleGetState()
            default:
                return HTTPResponse(status: 404, body: "Not Found")
            }
        }

        private func handleMomentumCommand(_ request: HTTPRequest) async -> HTTPResponse {
            guard let body = request.body,
                let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                let command = json["command"] as? String,
                let args = json["args"] as? [String]
            else {
                return HTTPResponse(status: 400, body: "Invalid request body")
            }

            do {
                let result = try await executeCommand(command, arguments: args)
                let response =
                    [
                        "output": result.output ?? "",
                        "error": result.error ?? "",
                        "exitCode": result.exitCode,
                    ] as [String: Any]

                let responseData = try JSONSerialization.data(withJSONObject: response)
                return HTTPResponse(status: 200, body: String(data: responseData, encoding: .utf8) ?? "{}")
            } catch {
                TestLogger.log("Command failed: \(error)")
                return HTTPResponse(status: 500, body: "Command failed: \(error)")
            }
        }

        private func handleShow() async -> HTTPResponse {
            await MainActor.run {
                NotificationCenter.default.post(name: .testServerShowMenu, object: nil)
            }
            return HTTPResponse(status: 200, body: "Menu shown")
        }

        private func handleRefresh() async -> HTTPResponse {
            await MainActor.run {
                NotificationCenter.default.post(name: .testServerRefreshState, object: nil)
            }
            return HTTPResponse(status: 200, body: "State refreshed")
        }

        private func handleGetLogs() -> HTTPResponse {
            let logs = getLogs().joined(separator: "\n")
            return HTTPResponse(status: 200, body: logs)
        }

        private func handleGetState() async -> HTTPResponse {
            let state = await MainActor.run {
                TestStateCapture.shared.captureState()
            }
            return HTTPResponse(status: 200, body: state)
        }
    }

    // MARK: - HTTP Types

    struct HTTPRequest {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data?
    }

    struct HTTPResponse {
        let status: Int
        let body: String

        var data: Data {
            let statusText = status == 200 ? "OK" : "Error"
            let response = """
                HTTP/1.1 \(status) \(statusText)\r
                Content-Type: text/plain; charset=utf-8\r
                Content-Length: \(body.utf8.count)\r
                Connection: close\r
                \r
                \(body)
                """
            return response.data(using: .utf8)!
        }
    }

    // MARK: - Connection Handler

    final class Connection: Hashable, @unchecked Sendable {
        private let connection: NWConnection
        private let handler: (HTTPRequest) async -> HTTPResponse

        init(connection: NWConnection, handler: @escaping (HTTPRequest) async -> HTTPResponse) {
            self.connection = connection
            self.handler = handler
        }

        func start() {
            connection.start(queue: .main)
            receive()
        }

        func cancel() {
            connection.cancel()
        }

        private func receive() {
            connection
                .receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                    guard let self = self else { return }

                    if let data = data, !data.isEmpty {
                        Task {
                            await self.handleData(data)
                        }
                    }

                    if isComplete || error != nil {
                        self.connection.cancel()
                    }
                }
        }

        private func handleData(_ data: Data) async {
            guard let request = parseHTTPRequest(data) else {
                let errorResponse = HTTPResponse(status: 400, body: "Bad Request")
                connection.send(
                    content: errorResponse.data,
                    completion: .contentProcessed { _ in
                        self.connection.cancel()
                    })
                return
            }

            let response = await handler(request)
            connection.send(
                content: response.data,
                completion: .contentProcessed { _ in
                    self.connection.cancel()
                })
        }

        private func parseHTTPRequest(_ data: Data) -> HTTPRequest? {
            guard let string = String(data: data, encoding: .utf8) else { return nil }
            let lines = string.components(separatedBy: "\r\n")
            guard !lines.isEmpty else { return nil }

            let requestLine = lines[0].components(separatedBy: " ")
            guard requestLine.count >= 2 else { return nil }

            let method = requestLine[0]
            let path = requestLine[1]

            var headers: [String: String] = [:]
            var bodyStartIndex = 0

            for (index, line) in lines.enumerated() {
                if line.isEmpty {
                    bodyStartIndex = index + 1
                    break
                }
                if index > 0 {
                    let parts = line.split(separator: ":", maxSplits: 1)
                    if parts.count == 2 {
                        headers[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                            String(parts[1]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }

            var body: Data? = nil
            if bodyStartIndex < lines.count {
                let bodyString = lines[bodyStartIndex...].joined(separator: "\r\n")
                body = bodyString.data(using: .utf8)
            }

            return HTTPRequest(method: method, path: path, headers: headers, body: body)
        }

        static func == (lhs: Connection, rhs: Connection) -> Bool {
            ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(self))
        }
    }

    // MARK: - Notifications

    extension Notification.Name {
        static let testServerShowMenu = Notification.Name("testServerShowMenu")
        static let testServerRefreshState = Notification.Name("testServerRefreshState")
        static let menuBarSetApproachIcon = Notification.Name("menuBarSetApproachIcon")
        static let menuBarSetTimeoutIcon = Notification.Name("menuBarSetTimeoutIcon")
        static let menuBarSetNormalIcon = Notification.Name("menuBarSetNormalIcon")
        static let showApproachMicroPopover = Notification.Name("showApproachMicroPopover")
        static let showTimeoutMicroPopover = Notification.Name("showTimeoutMicroPopover")
    }

    // MARK: - Test Logger

    enum TestLogger {
        static func log(_ message: String) {
            Task {
                await TestServer.shared.log(message)
            }
            #if DEBUG
                print("[TestServer] \(message)")
            #endif
        }
    }

    // MARK: - State Capture

    @MainActor
    class TestStateCapture {
        static let shared = TestStateCapture()
        private var stateProvider: (() -> String)?

        func setStateProvider(_ provider: @escaping () -> String) {
            self.stateProvider = provider
        }

        func captureState() -> String {
            stateProvider?() ?? "{\"error\": \"No state provider registered\"}"
        }
    }

#endif
