//
//  File.swift
//  Vapor
//
//  Created by Logan Wright on 2/21/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

extension Request {
    ///Available Data Types
    public enum Data {
        case UrlQuery([String : String])
        case Json(String)
        case NotAvailable
        
        public init(bytes: [UInt8]) {
            self = .Json("This is not ready for testing -- Placeholder until Xcode can compile swift packages")
        }
    }
    
}
