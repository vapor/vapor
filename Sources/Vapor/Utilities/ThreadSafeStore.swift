//
// ThreadSafeStore.swift
// Vapor
//
// Created by Logan Wright on 03/13/2016
//

import Foundation

internal final class ThreadSafeSocketStore<Socket where Socket: Vapor.Socket, Socket: Hashable> {
    
    // MARK: Properties
    
    private let lock = NSLock()
    private var storage: Set<Socket> = []
    
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
            storage.insert(element)
        }
    }
    
    func remove(element: Socket) {
        lock.locked {
            storage.remove(element)
        }
    }
    
    // MARK: SequenceType
    
    func forEach(@noescape body: Socket throws -> Void) rethrows {
        try lock.locked {
            try storage.forEach(body)
        }
    }
}
