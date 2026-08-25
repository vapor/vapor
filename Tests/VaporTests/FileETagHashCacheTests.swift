import Vapor
import VaporTesting
import RoutingKit
import HTTPTypes
import NIOConcurrencyHelpers
import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("File ETag Hash Cache Tests")
struct FileETagHashCacheTests {
    private let modified = Date(timeIntervalSince1970: 1_000)

    @Test("A hash is computed once and then served from the cache")
    func testSecondLookupIsCached() async throws {
        let cache = FileETagHashCache(cacheCapacity: 8)
        let computations = NIOLockedValueBox(0)

        for _ in 0..<3 {
            let digest = try await cache.digestHex(forFileAt: "/a", lastModified: modified, size: 10) {
                computations.withLockedValue { $0 += 1 }
                return "digest"
            }
            #expect(digest == "digest")
        }
        #expect(computations.withLockedValue { $0 } == 1)
    }

    @Test("Concurrent misses share a single computation")
    func testConcurrentMissesShareOneComputation() async throws {
        let cache = FileETagHashCache(cacheCapacity: 8)
        let computations = NIOLockedValueBox(0)

        // Every caller arrives before the first finishes, so a cache that only dedupes on
        // *completed* work would read the file once per caller.
        let digests = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await cache.digestHex(forFileAt: "/a", lastModified: self.modified, size: 10) {
                        computations.withLockedValue { $0 += 1 }
                        try await Task.sleep(for: .milliseconds(50))
                        return "digest"
                    }
                }
            }
            return try await group.reduce(into: [String]()) { $0.append($1) }
        }

        #expect(digests.count == 20)
        #expect(digests.allSatisfy { $0 == "digest" })
        #expect(computations.withLockedValue { $0 } == 1)
    }

    @Test("A failed computation isn't cached and doesn't strand later callers")
    func testFailureIsNotCached() async throws {
        struct HashFailure: Error {}
        let cache = FileETagHashCache(cacheCapacity: 8)

        await #expect(throws: HashFailure.self) {
            try await cache.digestHex(forFileAt: "/a", lastModified: self.modified, size: 10) {
                throw HashFailure()
            }
        }
        #expect(await cache.entry(forFileAt: "/a") == nil)

        // A later caller gets to try again rather than inheriting the failure.
        let digest = try await cache.digestHex(forFileAt: "/a", lastModified: modified, size: 10) { "digest" }
        #expect(digest == "digest")
    }

    @Test("A file is rehashed when its modification date or size changes")
    func testGenerationChangeInvalidates() async throws {
        let cache = FileETagHashCache(cacheCapacity: 8)

        #expect(try await cache.digestHex(forFileAt: "/a", lastModified: modified, size: 10) { "first" } == "first")

        // Same size, later modification date.
        let touched = modified.addingTimeInterval(1)
        #expect(try await cache.digestHex(forFileAt: "/a", lastModified: touched, size: 10) { "second" } == "second")

        // Same modification date, different size — filesystems that record timestamps to the
        // nearest second report an unchanged date for an edit made moments later.
        #expect(try await cache.digestHex(forFileAt: "/a", lastModified: touched, size: 11) { "third" } == "third")
    }

    @Test("Capacity configured on the server reaches the cache")
    func testConfiguredCapacityIsUsed() async throws {
        try await withApp { app in
            #expect(app.serverConfiguration.eTagHashCacheCapacity == 1024)
            app.serverConfiguration.eTagHashCacheCapacity = 1

            // Serve the same two files, so what's cached is decided by the configured capacity
            // rather than by anything the cache was built with.
            app.get("file-stream") { req -> Response in
                try await req.fileio.streamFile(at: #filePath, advancedETagComparison: true)
            }
            app.get("other") { req -> Response in
                try await req.fileio.streamFile(at: #file, advancedETagComparison: true)
            }

            try await app.test(method: .running) { runner in
                _ = try await runner.sendRequest(.get, "/file-stream")
                #expect(await app.fileETagHashCache.count == 1)
                _ = try await runner.sendRequest(.get, "/other")
                // The capacity is read on each insert, so the second file evicts the first.
                #expect(await app.fileETagHashCache.count == 1)
            }
        }
    }

    @Test("The cache evicts the least recently used entry once it is full")
    func testEvictsLeastRecentlyUsed() async throws {
        let cache = FileETagHashCache(cacheCapacity: 2)

        _ = try await cache.digestHex(forFileAt: "/a", lastModified: modified, size: 1) { "a" }
        _ = try await cache.digestHex(forFileAt: "/b", lastModified: modified, size: 1) { "b" }
        // Use "/a" again so "/b" becomes the coldest entry.
        _ = try await cache.digestHex(forFileAt: "/a", lastModified: modified, size: 1) { "a" }
        _ = try await cache.digestHex(forFileAt: "/c", lastModified: modified, size: 1) { "c" }

        #expect(await cache.count == 2)
        #expect(await cache.entry(forFileAt: "/b") == nil)
        #expect(await cache.entry(forFileAt: "/a") != nil)
        #expect(await cache.entry(forFileAt: "/c") != nil)
    }
}
