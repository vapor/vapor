//
// ThreadSafeStore.swift
// Vapor
//
// Created by Logan Wright on 03/13/2016
//

import Foundation

internal final class ThreadSafeSocketStore {
    
    // MARK: Properties
    
    private var lock = NSLock()
    private var storage: [String: Socket] = [:]
    
    // MARK: Computed
    
    var count: Int {
        var count = 0
        lock.locked {
            count = storage.count
        }
        return count
    }
    
    // MARK: Features
    
    func insert(element: Socket) {
        lock.locked {
            storage[element.id] = element
        }
    }
    
    func remove(element: Socket) {
        lock.locked {
            storage[element.id] = element
        }
    }
    
    // MARK: SequenceType
    
    func forEach(@noescape body: Socket throws -> Void) rethrows {
        try lock.locked {
            try storage.values.forEach(body)
        }
    }
}
