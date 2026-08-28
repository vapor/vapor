import NIOCore
import NIOPosix
import NIOConcurrencyHelpers

/// Sends a raw request over a plain TCP socket and returns every byte the server sends back
/// within `grace`, along with whether the server closed the connection.
///
/// A real HTTP client hides framing violations — it parses the response according to the rules
/// the server is supposed to be following — so checking "is there a body on the wire" needs a
/// socket, not a client. The deadline is client-side: waiting for the server to close would
/// otherwise park the test on the server's read-header timeout.
func rawExchange(
    port: Int,
    path: String,
    extraHeaders: String = "",
    until isComplete: @escaping @Sendable (String) -> Bool = { _ in false },
    quiet: Duration = .milliseconds(250),
    deadline: Duration = .seconds(10)
) async throws -> (bytes: String, serverClosed: Bool) {
    try await rawExchange(
        port: port,
        rawRequest: "GET \(path) HTTP/1.1\r\nHost: localhost\r\n\(extraHeaders)\r\n",
        until: isComplete,
        quiet: quiet,
        deadline: deadline)
}

/// As above, but sends `rawRequest` verbatim — for requests a client wouldn't let you make.
/// - Parameters:
///   - isComplete: Called with everything received so far; returning `true` ends the exchange.
///     Give this whenever the test knows what it is waiting for — the `quiet` fallback below can
///     stop early on a slow machine, mid-way through a response the server is still sending.
///   - quiet: How long to wait after the last byte before assuming nothing more is coming. Only a
///     heuristic, and only sound for tests asserting that something is *absent*.
func rawExchange(
    port: Int,
    rawRequest: String,
    until isComplete: @escaping @Sendable (String) -> Bool = { _ in false },
    quiet: Duration = .milliseconds(250),
    deadline: Duration = .seconds(10)
) async throws -> (bytes: String, serverClosed: Bool) {
    let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
        .connect(host: "127.0.0.1", port: port) { channel in
            channel.eventLoop.makeCompletedFuture {
                try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
            }
        }
    return try await channel.executeThenClose { inbound, outbound in
        try await outbound.write(ByteBuffer(string: rawRequest))
        let received = NIOLockedValueBox("")
        let lastActivity = NIOLockedValueBox(ContinuousClock.now)
        let reachedEnd = NIOLockedValueBox(false)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    for try await buffer in inbound {
                        received.withLockedValue { $0 += String(buffer: buffer) }
                        lastActivity.withLockedValue { $0 = ContinuousClock.now }
                    }
                    reachedEnd.withLockedValue { $0 = true }
                } catch {
                    // Cancelled below, or the connection failed. Either way whatever arrived is
                    // what we assert on.
                }
            }
            group.addTask {
                // Wait for the response to go quiet rather than for a fixed slice of time: a
                // loaded machine can take a while to answer at all, and a fixed grace period
                // then reads nothing and fails the test for the wrong reason. `deadline` only
                // runs out if the response never arrives.
                let start = ContinuousClock.now
                while true {
                    try? await Task.sleep(for: .milliseconds(25))
                    if reachedEnd.withLockedValue({ $0 }) { return }
                    if isComplete(received.withLockedValue { $0 }) { return }
                    let idle = ContinuousClock.now - lastActivity.withLockedValue { $0 }
                    if !received.withLockedValue({ $0.isEmpty }), idle >= quiet { return }
                    if ContinuousClock.now - start >= deadline { return }
                }
            }
            await group.next()
            group.cancelAll()
        }
        return (received.withLockedValue { $0 }, reachedEnd.withLockedValue { $0 })
    }
}
