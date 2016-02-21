//
//  LogDriver.swift
//  Vapor
//
//  Created by Matthew on 21/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

public protocol LoggerDriver {
    func log(log: Loggable)
}

public class ConsoleLogDriver: LoggerDriver {
    public func log(log: Loggable) {
        print(log)
    }
}
