//
//  Log.swift
//  Vapor
//
//  Created by Matthew on 21/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation


/* Log
*/
public class Log {
    
    public static var driver: Logger = ConsoleLogger()
    public static var enabledLevels: [LogLevel] = LogLevel.all
    
    public static func verbose(message: String) {
        if Log.enabledLevels.contains(.Verbose) {
            driver.log(.Verbose, message: message)
        }
    }
    
    public static func debug(message: String) {
        if Log.enabledLevels.contains(.Debug) {
            driver.log(.Debug, message: message)
        }
    }
    
    public static func info(message: String) {
        if Log.enabledLevels.contains(.Info) {
            driver.log(.Info, message: message)
        }
    }
    
    public static func warning(message: String) {
        if Log.enabledLevels.contains(.Warning) {
             driver.log(.Warning, message: message)
        }
    }
    
    public static func error(message: String) {
        if Log.enabledLevels.contains(.Error) {
            driver.log(.Error, message: message)
        }
    }
    
    public static func fatal(message: String) {
        if Log.enabledLevels.contains(.Fatal) {
            driver.log(.Fatal, message: message)
        }
    }
    
    public static func custom(message: String, label: String) {
        driver.log(.Custom(label), message: message)
    }
}