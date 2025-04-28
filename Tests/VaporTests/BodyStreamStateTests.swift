@testable import Vapor
import Testing
import NIOCore
import Foundation

@Suite("Body Stream State Tests")
struct BodyStreamStateTests {
    @Test("Test Synchronous Body")
    func testSynchronous() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString("Hello, world!")

        var state = HTTPBodyStreamState()
        #expect(state.didReadBytes(buffer) == .init(action: .write(buffer), callRead: false))
        #expect(state.didWrite() == .init(action: .nothing, callRead: false))
        #expect(state.didReceiveReadRequest() == .init(action: .nothing, callRead: true))
        #expect(state.didReadBytes(buffer) == .init(action: .write(buffer), callRead: false))
        #expect(state.didWrite() == .init(action: .nothing, callRead: false))
        #expect(state.didEnd() == .init(action: .close(nil), callRead: false))
    }

    @Test("Test Read During Write")
    func testReadDuringWrite() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString("Hello, world!")

        var state = HTTPBodyStreamState()
        #expect(state.didReadBytes(buffer) == .init(action: .write(buffer), callRead: false))
        #expect(state.didReceiveReadRequest() == .init(action: .nothing, callRead: false))
        #expect(state.didWrite() == .init(action: .nothing, callRead: true))
        #expect(state.didEnd() == .init(action: .close(nil), callRead: false))
    }

    @Test("Test Error During Write")
    func testErrorDuringWrite() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString("Hello, world!")
        struct Test: Error { }

        var state = HTTPBodyStreamState()
        #expect(state.didReadBytes(buffer) == .init(action: .write(buffer), callRead: false))
        #expect(state.didReceiveReadRequest() == .init(action: .nothing, callRead: false))
        #expect(state.didError(Test()) == .init(action: .nothing, callRead: false))
        #expect(state.didReadBytes(buffer) == .init(action: .nothing, callRead: false))
        #expect(state.didWrite() == .init(action: .close(Test()), callRead: false))
    }

    @Test("Test Buffered Writes")
    func testBufferedWrites() throws {
        var a = ByteBufferAllocator().buffer(capacity: 0)
        a.writeString("a")
        var b = ByteBufferAllocator().buffer(capacity: 0)
        b.writeString("b")
        struct Test: Error { }

        var state = HTTPBodyStreamState()
        #expect(state.didReadBytes(a) == .init(action: .write(a), callRead: false))
        #expect(state.didReadBytes(b) == .init(action: .nothing, callRead: false))
        #expect(state.didEnd() == .init(action: .nothing, callRead: false))
        #expect(state.didWrite() == .init(action: .write(b), callRead: false))
        #expect(state.didWrite() == .init(action: .close(nil), callRead: false))
    }
}

extension Vapor.HTTPBodyStreamState.Result: Swift.Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.action == rhs.action && lhs.callRead == rhs.callRead
    }
}

extension Vapor.HTTPBodyStreamState.Result.Action: Swift.Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.nothing, .nothing):
            return true
        case (.write(let a), .write(let b)):
            return Data(a.readableBytesView) == Data(b.readableBytesView)
        case (.close, .close):
            return true
        default:
            return false
        }
    }
}
