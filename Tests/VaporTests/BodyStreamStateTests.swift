import NIOCore
import XCTest

@testable import Vapor

final class BodyStreamStateTests: XCTestCase {
    func testSynchronous() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString("Hello, world!")

        var state = HTTPBodyStreamState()
        XCTAssertEqual(
            state.didReadBytes(buffer),
            .init(action: .write(buffer), callRead: false)
        )
        XCTAssertEqual(
            state.didWrite(),
            .init(action: .nothing, callRead: false)
        )
        XCTAssertEqual(
            state.didReceiveReadRequest(),
            .init(action: .nothing, callRead: true)
        )
        XCTAssertEqual(
            state.didReadBytes(buffer),
            .init(action: .write(buffer), callRead: false)
        )
        XCTAssertEqual(
            state.didWrite(),
            .init(action: .nothing, callRead: false)
        )
        XCTAssertEqual(
            state.didEnd(),
            .init(action: .close(nil), callRead: false)
        )
    }

    func testReadDuringWrite() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString("Hello, world!")

        var state = HTTPBodyStreamState()
        XCTAssertEqual(
            state.didReadBytes(buffer),
            .init(action: .write(buffer), callRead: false)
        )
        XCTAssertEqual(
            state.didReceiveReadRequest(),
            .init(action: .nothing, callRead: false)
        )
        XCTAssertEqual(
            state.didWrite(),
            .init(action: .nothing, callRead: true)
        )
        XCTAssertEqual(
            state.didEnd(),
            .init(action: .close(nil), callRead: false)
        )
    }

    func testErrorDuringWrite() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString("Hello, world!")
        struct Test: Error {}

        var state = HTTPBodyStreamState()
        XCTAssertEqual(
            state.didReadBytes(buffer),
            .init(action: .write(buffer), callRead: false)
        )
        XCTAssertEqual(
            state.didReceiveReadRequest(),
            .init(action: .nothing, callRead: false)
        )
        XCTAssertEqual(
            state.didError(Test()),
            .init(action: .nothing, callRead: false)
        )
        XCTAssertEqual(
            state.didReadBytes(buffer),
            .init(action: .nothing, callRead: false)
        )
        XCTAssertEqual(
            state.didWrite(),
            .init(action: .close(Test()), callRead: false)
        )
    }

    func testBufferedWrites() throws {
        var a = ByteBufferAllocator().buffer(capacity: 0)
        a.writeString("a")
        var b = ByteBufferAllocator().buffer(capacity: 0)
        b.writeString("b")
        struct Test: Error {}

        var state = HTTPBodyStreamState()
        XCTAssertEqual(
            state.didReadBytes(a),
            .init(action: .write(a), callRead: false)
        )
        XCTAssertEqual(
            state.didReadBytes(b),
            .init(action: .nothing, callRead: false)
        )
        XCTAssertEqual(
            state.didEnd(),
            .init(action: .nothing, callRead: false)
        )
        XCTAssertEqual(
            state.didWrite(),
            .init(action: .write(b), callRead: false)
        )
        XCTAssertEqual(
            state.didWrite(),
            .init(action: .close(nil), callRead: false)
        )
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
