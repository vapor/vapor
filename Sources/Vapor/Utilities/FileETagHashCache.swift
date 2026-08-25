#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// Caches the content hashes used for advanced ETag comparison.
///
/// Hashing a file means reading all of it, so the result is worth keeping. The cache is an actor
/// rather than a dictionary in `Application.storage` for two reasons: storage hands back a copy, so
/// read-modify-write updates could lose entries, and a shared mutable dictionary can't dedupe
/// concurrent work. Here a miss becomes a single task that every caller for that file awaits.
package actor FileETagHashCache {
    /// A cached hash, along with what it was computed from.
    package struct Entry: Sendable, Equatable {
        package let lastModified: Date
        package let size: Int64
        package let digestHex: String
    }

    /// What a cached hash is keyed on: a file whose size or modification date has changed is a
    /// different file as far as the cache is concerned.
    ///
    /// Modification date alone isn't enough — filesystems that record it to the nearest second will
    /// happily report the same date for an edit made moments later.
    private struct Generation: Hashable {
        let path: String
        let lastModified: Date
        let size: Int64
    }

    /// The most entries to keep. A cache of one entry per file ever served would grow without
    /// limit; static sites can have plenty of files, and a directory of user uploads has no bound
    /// at all.
    package static let defaultCapacity = 1024

    private let capacity: Int
    private var entries: [String: Entry] = [:]
    /// Bumped on every hit and insert so eviction can pick the coldest entry.
    private var useCounter: UInt64 = 0
    private var lastUsed: [String: UInt64] = [:]
    /// Hashes currently being computed, so concurrent callers share one read of the file.
    private var inFlight: [Generation: Task<String, any Error>] = [:]

    package init(capacity: Int = FileETagHashCache.defaultCapacity) {
        precondition(capacity > 0, "The ETag hash cache needs room for at least one entry")
        self.capacity = capacity
    }

    /// Returns the hash for a file, computing it only if it isn't already cached or being computed.
    ///
    /// - Parameters:
    ///   - path: The file's path.
    ///   - lastModified: When the file was last modified.
    ///   - size: The file's size in bytes.
    ///   - compute: Produces the hash. Called at most once per file generation, however many
    ///     callers arrive at once.
    package func digestHex(
        forFileAt path: String,
        lastModified: Date,
        size: Int64,
        compute: @escaping @Sendable () async throws -> String
    ) async throws -> String {
        if let entry = self.entries[path], entry.lastModified == lastModified, entry.size == size {
            self.touch(path)
            return entry.digestHex
        }

        let generation = Generation(path: path, lastModified: lastModified, size: size)
        if let existing = self.inFlight[generation] {
            // Someone is already reading this file; wait for their result rather than reading it
            // again. `value` rethrows their failure, which is the same failure we'd have hit.
            return try await existing.value
        }

        let task = self.makeComputeTask(compute)
        self.inFlight[generation] = task
        defer { self.inFlight[generation] = nil }

        let digestHex = try await task.value
        self.store(Entry(lastModified: lastModified, size: size, digestHex: digestHex), for: path)
        return digestHex
    }

    /// The cached entry for a file, if there is one. For tests.
    package func entry(forFileAt path: String) -> Entry? {
        self.entries[path]
    }

    /// How many entries are currently cached. For tests.
    package var count: Int {
        self.entries.count
    }

    /// Starts the hashing off the actor.
    ///
    /// A `Task` created inside an actor method inherits that actor's isolation, which would run the
    /// hashing — a CPU-bound loop over the whole file — on the cache's executor and block every
    /// other lookup behind it. Created from a `nonisolated` context it runs on the global executor
    /// instead, while still inheriting task locals (unlike a detached task).
    ///
    /// The task is deliberately unstructured: if the caller who started it goes away, the remaining
    /// waiters still need the result, so it isn't cancelled with them.
    private nonisolated func makeComputeTask(
        _ compute: @escaping @Sendable () async throws -> String
    ) -> Task<String, any Error> {
        Task { try await compute() }
    }

    private func store(_ entry: Entry, for path: String) {
        self.entries[path] = entry
        self.touch(path)

        // Evict coldest-first until we're back within capacity. Entries are only added one at a
        // time, so this drops at most one per insert.
        while self.entries.count > self.capacity {
            guard let coldest = self.lastUsed.min(by: { $0.value < $1.value })?.key else { break }
            self.entries[coldest] = nil
            self.lastUsed[coldest] = nil
        }
    }

    private func touch(_ path: String) {
        self.useCounter += 1
        self.lastUsed[path] = self.useCounter
    }
}
