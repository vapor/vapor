//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTPTypes
import ServiceLifecycle
import HTTPServerNew

/// Protocol for HTTP channels
public protocol HTTPChannelHandler: ServerChildChannel {
    typealias Responder = @Sendable (Request, Channel) async throws -> Void
    /// HTTP Request responder
    var responder: Responder { get }
}

/// Internal error thrown when an unexpected HTTP part is received eg we didn't receive
/// a head part when we expected one
@usableFromInline
package enum HTTPChannelError: Error {
    case unexpectedHTTPPart(HTTPRequestPart)
}

extension HTTPChannelHandler {
    public func handleHTTP(asyncChannel: NIOAsyncChannel<HTTPRequestPart, HTTPResponsePart>, logger: Logger) async {
        do {
            try await withTaskCancellationHandler {
                try await asyncChannel.executeThenClose { inbound, outbound in
                    var iterator = inbound.makeAsyncIterator()

                    // read first part, verify it is a head
                    guard let part = try await iterator.next() else { return }
                    guard case .head(var head) = part else {
                        throw HTTPChannelError.unexpectedHTTPPart(part)
                    }

                    while true {
                        let request = try await Request(application: Application(), on: asyncChannel.channel.eventLoop)
//                        let request = Request(
//                            head: head,
//                            bodyIterator: iterator
//                        )
//                        let responseWriter = ResponseWriter(outbound: outbound)
//                        do {
//                            try await self.responder(request, responseWriter, asyncChannel.channel)
//                        } catch {
//                            throw error
//                        }
                        if request.headers.first(name: .connection) == "close" {
                            return
                        }

                        // Flush current request
                        // read until we don't have a body part
                        var part: HTTPRequestPart?
                        while true {
                            part = try await iterator.next()
                            guard case .body = part else { break }
                        }
                        // if we have an end then read the next part
                        if case .end = part {
                            part = try await iterator.next()
                        }

                        // if part is nil break out of loop
                        guard let part else {
                            break
                        }

                        // part should be a head, if not throw error
                        guard case .head(let newHead) = part else { throw HTTPChannelError.unexpectedHTTPPart(part) }
                        head = newHead
                    }
                }
            } onCancel: {
                asyncChannel.channel.close(mode: .input, promise: nil)
            }
        } catch {
            // we got here because we failed to either read or write to the channel
            logger.trace("Failed to read/write to Channel. Error: \(error)")
        }
    }
}
