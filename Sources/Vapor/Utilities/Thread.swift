extension Thread {
    /// Convenience wrapper around `Thread.detachNewThread`.
    public static func async(_ work: @escaping () -> ()) {
        Thread.detachNewThread {
            work()
        }
    }
}
