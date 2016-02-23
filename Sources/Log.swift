//
//  Log.swift
//  Vapor
//
//  Created by Matthew on 21/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

/* Log class
*/
public class Log {
    
    /**
     Logger. Default is the console logger.
     This can be overriden with a custom logger.
     */
    public static var driver: Logger = ConsoleLogger()
    
    /**
     Enabled log levels. Default is to log all levels. This
     can be overridden.
     */
    public static var enabledLevels: [LogLevel] = LogLevel.all
    
    /**
     Logs verbose messages if .Verbose is enabled
     
     - parameter message: String to log
     
     */
    public static func verbose(message: String) {
        if Log.enabledLevels.contains(.Verbose) {
            driver.log(.Verbose, message: message)
        }
    }
    
    /**
     Logs debug messages if .Debug is enabled
     
     - parameter message: String to log
     
     */
    public static func debug(message: String) {
        if Log.enabledLevels.contains(.Debug) {
            driver.log(.Debug, message: message)
        }
    }
    
    /**
     Logs info messages if .Info is enabled
     
     - parameter message: String to log
     
     */
    public static func info(message: String) {
        if Log.enabledLevels.contains(.Info) {
            driver.log(.Info, message: message)
        }
    }
    
    /**
     Logs warning messages if .Warning is enabled
     
     - parameter message: String to log
     
     */
    public static func warning(message: String) {
        if Log.enabledLevels.contains(.Warning) {
             driver.log(.Warning, message: message)
        }
    }
    
    /**
     Logs error messages if .Error is enabled
     
     - parameter message: String to log
     
     */
    public static func error(message: String) {
        if Log.enabledLevels.contains(.Error) {
            driver.log(.Error, message: message)
        }
    }
    
    /**
     Logs fatal messages if .Fatal is enabled
     
     - parameter message: String to log
     
     */
    public static func fatal(message: String) {
        if Log.enabledLevels.contains(.Fatal) {
            driver.log(.Fatal, message: message)
        }
    }
    
    /**
     Logs custom messages. Always enabled.
     
     - parameter message: String to log
     
     */
    public static func custom(message: String, label: String) {
        driver.log(.Custom(label), message: message)
    }
}