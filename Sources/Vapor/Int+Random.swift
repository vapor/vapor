#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

extension Int {
    /**
     * Generates a random number between (and inclusive of)
     * the given minimum and maxiumum.
     */
    public static func random(min min: Int, max: Int) -> Int {
        let top = max - min + 1
        #if os(Linux)
            return Int(Glibc.random() % top) + min
        #else
            return Int(arc4random_uniform(UInt32(top))) + min
        #endif
    }
}