import NIOCore
import _NIOFileSystem
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Writes a temporary file of `size` bytes and returns its path.
func makeTemporaryFile(size: Int) async throws -> String {
    let directory = try await FileSystem.shared.temporaryDirectory
    let path = directory.appending("vapor-test-\(UUID().uuidString).bin")
    try await FileSystem.shared.withFileHandle(
        forWritingAt: path, options: .newFile(replaceExisting: true)
    ) { handle in
        _ = try await handle.write(contentsOf: ByteBuffer(repeating: 0x41, count: size), toAbsoluteOffset: 0)
    }
    return path.string
}
