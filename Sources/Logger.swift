//
//  Logger.swift
//  Vapor
//
//  Created by Matthew on 21/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

/** Logger Class

*/
public class Logger {

    private let driver: LoggerDriver
    
    public static let sharedInstance = Logger()

    private init() {
        driver = ConsoleLogDriver()
    }
    
    public func log(log: Loggable) {
        driver.log(log)
    }
}
