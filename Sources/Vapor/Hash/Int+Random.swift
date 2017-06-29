import Foundation
import libc

extension Int {
    /// Generates a random number between (and inclusive of)
    /// the given minimum and maximum.
    #if os(Linux)
    static private var randomInitialized: Bool = {
        /// This stylized initializer is used to work around dispatch_once
        /// not existing and still guarantee thread safety
        let current = Date().timeIntervalSinceReferenceDate
        let salt = current.truncatingRemainder(dividingBy: 1) * 100000000
        libc.srand(UInt32(current + salt))
        return true
    }()
    #endif

    public static func random(min: Int, max: Int) -> Int {
        let top = max - min + 1
        #if os(Linux)
            guard Int.randomInitialized else { fatalError() }
            return Int(libc.random() % top) + min
        #else
            return Int(arc4random_uniform(UInt32(top))) + min
        #endif
    }
}
