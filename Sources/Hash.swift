//
//  Hash.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/7/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

public class Hash {
    
    public static var applicationKey: String = ""
    
    public class func make(string: String) -> String {
        return "\(string)\(applicationKey)".SHA1
    }
    
}