//
//  RequestData+Target.swift
//  Vapor
//
//  Created by Logan Wright on 2/21/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import PureJsonSerializer

extension Request {
    ///Available Data Types
    public enum Data {
        case UrlQuery([String : String])
        case Json(PureJsonSerializer.Json)
        case NotAvailable
        
        public init(bytes: [UInt8]) {
            do {
                let js = try PureJsonSerializer.Json.deserialize(bytes)
                self = .Json(js)
            } catch {
                self = .NotAvailable
            }
        }
    }
}
