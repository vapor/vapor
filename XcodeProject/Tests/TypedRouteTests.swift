//
//  RouterTests.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/18/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation
import XCTest
@testable import Vapor

#if os(Linux)
    extension TypedRouteTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
               ("testSingleHostRouting", testSingleHostRouting),
            ]
        }
    }
#endif

class TypedRouteTests: XCTestCase {
    
    func testSingleHostRouting() {
        
    }
    
}
