//
// ThreadSafeStore.swift
// Vapor
//
// Created by Logan Wright on 03/13/2016
//

import Foundation

internal final class ThreadSafeSocketStore<Socket where Socket: Vapor.Socket> {
    
    // MARK: Properties
    
    private let lock = NSLock()
    private var storage: [String : Socket] = [:]
    
    // MARK: Computed
    
    var count: Int {
        var count = 0
        lock.locked {
            count = storage.count
        }
        return count
    }
    
    // MARK: Features
    
    @warn_unused_result
    func insert(element: Socket) -> String {
        let id = NSUUID().UUIDString
        lock.locked {
            storage[id] = element
        }
        return id
    }
    
    func remove(id id: String) {
        lock.locked {
            storage[id] = nil
        }
    }
    
    // MARK: SequenceType
    
    func forEach(@noescape body: Socket throws -> Void) rethrows {
        try lock.locked {
            try storage.values.forEach(body)
        }
    }
}
