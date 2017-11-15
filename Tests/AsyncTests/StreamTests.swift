import XCTest
import Async

final class StreamTests : XCTestCase {
    func testPipeline() throws {
        let numberEmitter = EmitterStream(Int.self)

        var squares: [Int] = []
        var reported = false

        numberEmitter.map { int in
            return int * int
        }.drain { square in
            squares.append(square)
        }.catch { error in
            reported = true
            XCTAssert(error is CustomError)
        }

        numberEmitter.emit(1)
        numberEmitter.emit(2)
        numberEmitter.emit(3)
        
        numberEmitter.report(CustomError())

        XCTAssertEqual(squares, [1, 4, 9])
        XCTAssert(reported)
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


