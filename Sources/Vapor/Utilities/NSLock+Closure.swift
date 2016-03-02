//
//  NSLock+Closure.swift
//  Vapor
//
//  Created by James Richard on 3/2/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

extension NSLock {
    func locked(@noescape closure: () throws -> Void) rethrows {
        lock()
        defer { unlock() }
        try closure()
    }
}
