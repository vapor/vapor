//
//  PromiseTests.swift
//  Vapor
//
//  Created by Logan Wright on 7/4/16.
//
//

import XCTest
@testable import Vapor

private enum PromiseTestError: ErrorProtocol {
    case someError
    case anotherError
}

class PromiseTests: XCTestCase {

    #if os(Linux)
    /*
    Temporary until we get libdispatch support on Linux, then remove this section.
    */
    static let allTests = [
        ("testPromiseResult", testPromiseResult),
        ("testPromiseFailure", testPromiseFailure),
        ("testDuplicateResults", testDuplicateResults),
        ("testDuplicateErrors", testDuplicateErrors)
    ]

    func testLinux() {
        print("Not yet available on linux")
    }

    #else
    static let allTests = [
        ("testPromiseResult", testPromiseResult),
        ("testPromiseFailure", testPromiseFailure),
        ("testDuplicateResults", testDuplicateResults),
        ("testDuplicateErrors", testDuplicateErrors)
    ]

    func testPromiseResult() throws {
        var array: [Int] = []

        array.append(1)
        let result: Int = try Promise.async { promise in
            array.append(2)
            _ = try background {
                sleep(1)
                array.append(4)
                promise.resolve(with: 42)
            }
            array.append(3)
        }
        array.append(5)

        XCTAssert(array == [1,2,3,4,5])
        XCTAssert(result == 42)
    }

    func testPromiseFailure() {
        var array: [Int] = []

        do {
            array.append(1)
            let _ = try Promise<Int>.async { promise in
                array.append(2)
                _ = try background {
                    sleep(1)
                    array.append(4)
                    promise.reject(with: PromiseTestError.someError)
                }
                array.append(3)
            }
            XCTFail("Promise should throw")
        } catch PromiseTestError.someError {
            // success
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }

        XCTAssert(array == [1,2,3,4])
    }

    func testDuplicateResults() throws {
        let response = try Promise<Int>.async { promise in
            promise.resolve(with: 10)
            // subsequent resolutions should be ignored
            promise.resolve(with: 400)
        }

        XCTAssert(response == 10)
    }


    func testDuplicateErrors() {
        do {
            let _ = try Promise<Int>.async { promise in
                promise.reject(with: PromiseTestError.someError)
                // subsequent rejections should be ignored
                promise.reject(with: PromiseTestError.anotherError)
            }
            XCTFail("Test should not pass")
        } catch PromiseTestError.someError {
            // success
        } catch {
            XCTFail("Unexpected error thrown")
        }
    }
    
    #endif
}
