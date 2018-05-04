extension Thread {
    /// Convenience wrapper around `Thread.detachNewThread`.
    public static func async(_ work: @escaping () -> ()) {
        if #available(OSX 10.12, *) {
            Thread.detachNewThread {
                work()
            }
        } else {
            ERROR("Thead.async requires macOS 10.12 or greater")
        }
    }
}
