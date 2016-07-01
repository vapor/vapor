/*
 Temporary file to ease burden if different names on Linux and osx :(
 */
#if !os(Linux)
    import Foundation
    typealias NSDate = Date
    typealias NSDateFormatter = DateFormatter
    typealias NSProcessInfo = ProcessInfo
#endif
