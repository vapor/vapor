import Async
import Dispatch
import XCTest

final class FutureTests : XCTestCase {
    func testSimpleFuture() throws {
        let promise = Promise(String.self)
        promise.complete("test")
        XCTAssertEqual(try promise.future.blockingAwait(), "test")
    }
    
    func testFutureThen() throws {
        let promise = Promise(String.self)
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            promise.complete("test")
        }

        let group = DispatchGroup()
        group.enter()

        promise.future.do { result in
            XCTAssertEqual(result, "test")
            group.leave()
        }.catch { error in
            XCTFail("\(error)")
        }
        
        group.wait()
        XCTAssert(promise.future.isCompleted)
    }
    
    func testTimeoutFuture() throws {
        let promise = Promise(String.self)

        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            promise.complete("test")
        }
        
        XCTAssertFalse(promise.future.isCompleted)
        XCTAssertThrowsError(try promise.future.blockingAwait(timeout: .seconds(1)))
    }
    
    func testErrorFuture() throws {
        let promise = Promise(String.self)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            promise.fail(CustomError())
        }

        var executed = 0
        var caught = false

        let group = DispatchGroup()
        group.enter()
        promise.future.do { _ in
            XCTFail()
            executed += 1
        }.catch { error in
            executed += 1
            caught = true
            group.leave()
            XCTAssert(error is CustomError)
        }
        
        group.wait()
        XCTAssert(caught)
        XCTAssertTrue(promise.future.isCompleted)
        XCTAssertEqual(executed, 1)
    }

    func testArrayFuture() throws {
        let promiseA = Promise(String.self)
        let promiseB = Promise(String.self)

        let futures = [promiseA.future, promiseB.future]

        let group = DispatchGroup()
        group.enter()
        futures.flatten().do { array in
            XCTAssertEqual(array, ["a", "b"])
            group.leave()
        }.catch { error in
            XCTFail("\(error)")
        }

        promiseA.complete("a")
        promiseB.complete("b")

        group.wait()
    }

    func testFutureMap() throws {
        let intPromise = Promise(Int.self)

        let group = DispatchGroup()
        group.enter()

        intPromise.future.map { int in
            return String(int)
        }.do { string in
            XCTAssertEqual(string, "42")
            group.leave()
        }.catch { error in
            XCTFail("\(error)")
            group.leave()
        }

        intPromise.complete(42)
        group.wait()
    }
    
    func testFutureFlatMap() throws {
        let string = Promise<String>()
        let bool = Promise<Bool>()
        
        let integer = string.future.flatMap { string in
            return bool.future.map { bool in
                return bool ? Int(string) : -1
            }
        }
        
        string.complete("30")
        bool.complete(true)
        
        let int = try integer.blockingAwait()
        
        XCTAssertEqual(int, 30)
    }
    
    func testFutureFlatMap2() throws {
        let string = Promise<String>()
        let bool = Promise<Bool>()
        
        let integer = string.future.flatMap { string in
            return bool.future.map { bool in
                return bool ? Int(string) : -1
            }
        }
        
        string.complete("30")
        bool.complete(false)
        
        let int = try integer.blockingAwait()
        
        XCTAssertEqual(int, -1)
    }
    
    func testFutureFlatMapErrors() throws {
        let string = Promise<String>()
        let bool = Promise<Bool>()
        
        let integer = string.future.flatMap { string in
            return bool.future.map { bool -> Int? in
                guard bool else {
                    throw CustomError()
                }
                
                return bool ? Int(string) : -1
            }
        }
        
        string.complete("30")
        bool.complete(false)
        
        XCTAssertThrowsError(try integer.blockingAwait())
    }
    
    func testFutureFlatMapErrors2() throws {
        let string = Promise<String>()
        let bool = Promise<Bool>()
        
        let integer = string.future.flatMap { string -> Future<Int?> in
            guard string == "-1" else {
                throw CustomError()
            }
            
            return bool.future.map { bool in
                return bool ? Int(string) : -1
            }
        }
        
        string.complete("30")
        bool.complete(false)
        
        XCTAssertThrowsError(try integer.blockingAwait())
    }
    
    func testFlatten() throws {
        let future = Future("TEST example")
        
        let promise = Promise<String>()
        promise.flatten(future)
        
        XCTAssertEqual(try promise.future.blockingAwait(), "TEST example")
    }
    
    func testPrecompleted() throws {
        let future = Future("Hello world")
        XCTAssertEqual(try future.blockingAwait(), "Hello world")
        
        let future2 = Future<Any>(error: CustomError())
        XCTAssertThrowsError(try future2.blockingAwait())
    }

    static let allTests = [
        ("testSimpleFuture", testSimpleFuture),
        ("testFutureThen", testFutureThen),
        ("testTimeoutFuture", testTimeoutFuture),
        ("testErrorFuture", testErrorFuture),
        ("testArrayFuture", testArrayFuture),
        ("testFutureMap", testFutureMap),
        ("testFutureFlatMap", testFutureFlatMap),
        ("testFutureFlatMap2", testFutureFlatMap2),
    ]
}

struct CustomError : Error {}
