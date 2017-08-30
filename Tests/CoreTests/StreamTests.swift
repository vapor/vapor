import XCTest
import Core

final class StreamTests : XCTestCase {
    func testPipeline() throws {
        let numberEmitter = EmitterStream(Int.self)
        let squareMapStream = MapStream<Int, Int> { int in
            return int * int
        }

        var squares: [Int] = []

        numberEmitter.stream(to: squareMapStream).drain { square in
            squares.append(square)
        }

        numberEmitter.emit(1)
        numberEmitter.emit(2)
        numberEmitter.emit(3)

        XCTAssertEqual(squares, [1, 4, 9])
    }

    func testDelta() throws {
        let numberEmitter = EmitterStream<Int>()
        let splitter = OutputStreamSplitter(numberEmitter)

        var output: [Int] = []

        splitter.split { int in
            output.append(int)
        }
        splitter.split { int in
            output.append(int)
        }

        numberEmitter.emit(1)
        numberEmitter.emit(2)
        numberEmitter.emit(3)

        XCTAssertEqual(output, [1, 1, 2, 2, 3, 3])
    }


    static let allTests = [
        ("testPipeline", testPipeline),
        ("testDelta", testDelta),
    ]
}


