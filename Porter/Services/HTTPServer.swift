//
//  HTTPServer.swift
//  Porter
//
//  Created by Porter Generator
//

import Foundation
import Network
import OSLog
import UniformTypeIdentifiers

/// HTTP 服务器 Actor
actor HTTPServer {
    // MARK: - Properties

    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private(set) var currentPort: UInt16 = 0
    private var startContinuation: CheckedContinuation<UInt16, Error>?

    private let logger = Logger(subsystem: "com.porter.httpserver", category: "server")

    var isRunning: Bool {
        listener?.state == .ready
    }

    // MARK: - Lifecycle

    func start(port: UInt16 = 0, lanAccess: Bool = false) async throws -> UInt16 {
        if isRunning { return currentPort }
        if startContinuation != nil {
            throw CancellationError()
        }

        let parameters = createNetworkParameters(lanAccess: lanAccess)
        let nwPort = NWEndpoint.Port(integerLiteral: port)

        let newListener = try NWListener(using: parameters, on: nwPort)

        return try await withCheckedThrowingContinuation { continuation in
            Task {
                self.setupListenerHandlers(newListener, continuation: continuation)
            }
        }
    }

    func stop() {
        logger.info("Stopping server...")
        listener?.cancel()
        listener = nil

        for connection in connections.values {
            connection.cancel()
        }
        connections.removeAll()
        currentPort = 0

        if let continuation = startContinuation {
            startContinuation = nil
            continuation.resume(throwing: CancellationError())
        }
    }

    // MARK: - Internal Logic

    private func setupListenerHandlers(
        _ newListener: NWListener,
        continuation: CheckedContinuation<UInt16, Error>)
    {
        startContinuation = continuation

        newListener.stateUpdateHandler = { [weak self, weak newListener] state in
            Task {
                await self?.handleListenerStateChange(state, port: newListener?.port)
            }
        }

        newListener.newConnectionHandler = { [weak self] connection in
            Task { await self?.handleConnection(connection) }
        }

        newListener.start(queue: .global(qos: .userInitiated))
        listener = newListener
    }

    private func handleListenerStateChange(_ state: NWListener.State, port: NWEndpoint.Port?) {
        switch state {
        case .ready:
            if let port {
                updatePort(port.rawValue)
                if let continuation = startContinuation {
                    startContinuation = nil
                    continuation.resume(returning: port.rawValue)
                }
            }
        case let .failed(error):
            if let continuation = startContinuation {
                startContinuation = nil
                continuation
                    .resume(throwing: ServerError.networkFailure(error.localizedDescription))
            }
        default:
            break
        }
    }

    private func updatePort(_ port: UInt16) {
        currentPort = port
    }

    private func createNetworkParameters(lanAccess: Bool = false) -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        if !lanAccess {
            parameters.requiredInterfaceType = .loopback
        }
        return parameters
    }

    private func handleConnection(_ connection: NWConnection) {
        let id = UUID()
        connections[id] = connection

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                Task { await self?.removeConnection(id: id) }
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
        receiveRequest(on: connection, id: id)
    }

    private func removeConnection(id: UUID) {
        connections.removeValue(forKey: id)
    }

    private func receiveRequest(on connection: NWConnection, id: UUID) {
        connection
            .receive(
                minimumIncompleteLength: 1,
                maximumLength: 65536)
            { [weak self] data, _, isComplete, error in
                guard let self else { return }

                if error != nil {
                    connection.cancel()
                    return
                }

                if
                    let data, !data.isEmpty, let requestString = String(
                        data: data,
                        encoding: .utf8)
                {
                    Task {
                        await self.handleHTTPRequest(requestString, on: connection)
                    }
                }

                if isComplete {
                    Task { await self.removeConnection(id: id) }
                }
            }
    }

    private func handleHTTPRequest(_ request: String, on connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }

        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 2 else { return }

        let path = normalizePath(components[1])

        guard !path.contains("..") else {
            sendResponse(connection: connection, statusCode: 403, body: "Forbidden")
            return
        }

        if let fileURL = findResource(for: path) {
            serveFile(at: fileURL, on: connection)
        } else {
            sendResponse(connection: connection, statusCode: 404, body: "404 Not Found")
        }
    }

    private func normalizePath(_ rawPath: String) -> String {
        guard let url = URL(string: rawPath) else { return "/index.html" }
        let path = url.path
        return (path == "/" || path.isEmpty) ? "/index.html" : path
    }

    private func findResource(for path: String) -> URL? {
        let relativePath = String(path.dropFirst())

        if let resourceURL = Bundle.main.resourceURL {
            let staticURL = resourceURL.appendingPathComponent("StaticResources")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: staticURL.path) {
                return staticURL
            }

            let directURL = resourceURL.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: directURL.path) {
                return directURL
            }
        }

        let fileName = URL(fileURLWithPath: relativePath).lastPathComponent

        if
            let resourcePath = Bundle.main.path(
                forResource: fileName,
                ofType: nil,
                inDirectory: "StaticResources")
        {
            return URL(fileURLWithPath: resourcePath)
        }

        if let resourcePath = Bundle.main.path(forResource: fileName, ofType: nil) {
            return URL(fileURLWithPath: resourcePath)
        }

        return nil
    }

    private func serveFile(at url: URL, on connection: NWConnection) {
        do {
            let data = try Data(contentsOf: url)
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            sendResponse(connection: connection, statusCode: 200, mimeType: mime, data: data)
        } catch {
            sendResponse(connection: connection, statusCode: 500, body: "Internal Error")
        }
    }

    private func sendResponse(
        connection: NWConnection,
        statusCode: Int,
        mimeType: String = "text/plain",
        body: String)
    {
        let data = body.data(using: .utf8) ?? Data()
        sendResponse(connection: connection, statusCode: statusCode, mimeType: mimeType, data: data)
    }

    private func sendResponse(
        connection: NWConnection,
        statusCode: Int,
        mimeType: String,
        data: Data)
    {
        let header = """
        HTTP/1.1 \(statusCode) OK\r
        Content-Type: \(mimeType)\r
        Content-Length: \(data.count)\r
        Connection: close\r
        Server: Porter\r
        \r

        """

        var responseData = header.data(using: .utf8) ?? Data()
        responseData.append(data)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
