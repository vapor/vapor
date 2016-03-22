//
//  Lock.swift
//  Vapor
//
//  Created by James Richard on 3/2/16.
//

// Most of this code is from the Swift Foundation project

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

class Lock {

    let mutex = UnsafeMutablePointer<pthread_mutex_t>.alloc(1)

    init() {
        pthread_mutex_init(mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(mutex)
        mutex.destroy()
        mutex.dealloc(1)
    }

    func lock() {
        pthread_mutex_lock(mutex)
    }

    func unlock() {
        pthread_mutex_unlock(mutex)
    }

    func locked(@noescape closure: () throws -> Void) rethrows {
        lock()
        defer { unlock() }
        try closure()
    }

    func tryLock() -> Bool {
        return pthread_mutex_trylock(mutex) == 0
    }

}
