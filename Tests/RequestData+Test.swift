//
//  File.swift
//  Vapor
//
//  Created by Logan Wright on 2/21/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

extension Request {
    public struct Data {
        
        // MARK: Initialization
        
        public let query: [String : String]
        public let bytes: [UInt8]
        
        internal init(query: [String : String] = [:], bytes: [UInt8]) {
            self.query = query
            self.bytes = bytes
        }
    }
}
