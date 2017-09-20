#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

extension Int {
    public static func random(max: Int) -> Int {
        let max = UInt32(max)
        #if os(Linux)
            let val = Int(Glibc.random() % Int(max))
        #else
            let val = Int(arc4random_uniform(max))
        #endif
        return val
    }
}

extension Array {
    var random: Element {
        return self[Int.random(max: count)]
    }
}
