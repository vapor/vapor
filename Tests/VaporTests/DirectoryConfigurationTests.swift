@testable import Vapor
import XCTest
import Foundation

class DirectoryConfigurationTests: XCTestCase {

    // The code we test here is only compiled in when `#if Xcode` is true, so we match the condition here too.
    #if Xcode
    
    func testDirectoryConfigurationDetectsValidBuildArea() throws {
    
        // Set up a fake build area that satisfies the conditions we check for.
        let tempDirectoryURL = URL(fileURLWithPath: try createTemporaryDirectory(), isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }
        
        let buildProductsForConfigURL = tempDirectoryURL
            .appendingPathComponent("Build", isDirectory: true)
            .appendingPathComponent("Products", isDirectory: true)
            .appendingPathComponent("Debug", isDirectory: true)
        let fakeWorkspaceURL = tempDirectoryURL.appendingPathComponent("Workspace", isDirectory: true)
        let plistInfo: [String: Any] = ["LastAccessedDate": Date(), "WorkspacePath": fakeWorkspaceURL.path]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plistInfo, format: .xml, options: 0)
        
        try FileManager.default.createDirectory(at: buildProductsForConfigURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL.appendingPathComponent("Index", isDirectory: true), withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: fakeWorkspaceURL, withIntermediateDirectories: false)
                
        try plistData.write(to: tempDirectoryURL.appendingPathComponent("info.plist", isDirectory: false))
        try Data().write(to: fakeWorkspaceURL.appendingPathComponent("Package.swift", isDirectory: false))
        
        guard FileManager.default.changeCurrentDirectoryPath(buildProductsForConfigURL.path) else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        let detectedConfig = DirectoryConfiguration.detect()
        
        XCTAssertEqual(detectedConfig.workingDirectory, fakeWorkspaceURL.path.finished(with: "/"))
    }
    
    #endif

}

// Taken from https://github.com/apple/swift-nio/blob/2.14.0/Tests/NIOTests/TestUtils.swift#L134-L147
// Modified to:
//  - Query `FileManager` directly
//  - Use a different prefix
//  - Throw a `POSIXError` if `mkdtemp(3)` fails.
func createTemporaryDirectory() throws -> String {
    let template = "\(FileManager.default.temporaryDirectory.path)/.VaporTests-temp-dir_XXXXXX"

    var templateBytes = template.utf8 + [0]
    let templateBytesCount = templateBytes.count
    try templateBytes.withUnsafeMutableBufferPointer { ptr in
        try ptr.baseAddress!.withMemoryRebound(to: Int8.self, capacity: templateBytesCount) { (ptr: UnsafeMutablePointer<Int8>) in
            guard mkdtemp(ptr) != nil else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EINVAL, userInfo: [NSFilePathErrorKey: template])
            }
        }
    }
    templateBytes.removeLast()
    return String(decoding: templateBytes, as: Unicode.UTF8.self)
}
