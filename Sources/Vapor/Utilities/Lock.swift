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

    let mutex = UnsafeMutablePointer<pthread_mutex_t>(allocatingCapacity: 1)

    init() {
        pthread_mutex_init(mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(mutex)
        mutex.deinitialize()
        mutex.deallocateCapacity(1)
    }

    func lock() {
        pthread_mutex_lock(mutex)
    }

    func unlock() {
        pthread_mutex_unlock(mutex)
    }

    func locked(closure: @noescape () throws -> Void) rethrows {
        lock()
        defer { unlock() }
        try closure()
    }

    func tryLock() -> Bool {
        return pthread_mutex_trylock(mutex) == 0
    }

}
