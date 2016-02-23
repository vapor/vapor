//
//  HashTests.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/22/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

class HashTests: XCTestCase {
    
    func testHash() {
        let string = "vapor"
        let expected = "fb7ae694ba3fd90ae3909ccccd0be0dae988e70296d7099bc5708a872f4cc172"
        
        let result = Hash.make(vapor)
        
        XCAsset(expected == result, "Hash did not match")
    }

}