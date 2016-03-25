#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/**
    A Swift wrapper around pthread_mutex from
    Swift's Foundation project.
*/
class Lock {

    #if swift(>=3.0)
        let mutex = UnsafeMutablePointer<pthread_mutex_t>(allocatingCapacity: 1)
    #else
        let mutex = UnsafeMutablePointer<pthread_mutex_t>.alloc(1)
    #endif

    init() {
        pthread_mutex_init(mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(mutex)
        #if swift(>=3.0)
            mutex.deinitialize()
            mutex.deallocateCapacity(1)
        #else
            mutex.destroy()
            mutex.dealloc(1)
        #endif
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
