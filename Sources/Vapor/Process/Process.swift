//
//  Process.swift
//  Vapor
//
//  Created by Logan Wright on 2/27/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

extension Process {
    
    /**
     Returns the string value of an
     argument passed to the executable
     in the format --name=value
     */
    static func valueFor(argument name: String) -> String? {
        for argument in arguments where argument.hasPrefix("--\(name)=") {
            return argument.split("=").last
        }
        return nil
    }
    
}
