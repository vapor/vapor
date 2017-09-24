
// MARK: Alphabet

extension Byte {
    /// Returns true if the given byte is between lowercase or uppercase A-Z in UTF8.
    public var isLetter: Bool {
       return (self >= .a && self <= .z) || (self >= .A && self <= .Z)
    }

    /// Returns whether or not a given byte represents a UTF8 digit 0 through 9, or an arabic letter
    public var isAlphanumeric: Bool {
        return isLetter || isDigit
    }

    /// Returns whether a given byte can be interpreted as a hex value in UTF8, ie: 0-9, a-f, A-F.
    public var isHexDigit: Bool {
        return (self >= .zero && self <= .nine) || (self >= .A && self <= .F) || (self >= .a && self <= .f)
    }

    /// A
    public static let A: Byte = 0x41

    /// B
    public static let B: Byte = 0x42

    /// C
    public static let C: Byte = 0x43

    /// D
    public static let D: Byte = 0x44

    /// E
    public static let E: Byte = 0x45

    /// F
    public static let F: Byte = 0x46

    /// G
    public static let G: Byte = 0x47

    /// H
    public static let H: Byte = 0x48

    /// I
    public static let I: Byte = 0x49

    /// J
    public static let J: Byte = 0x4A

    /// K
    public static let K: Byte = 0x4B

    /// L
    public static let L: Byte = 0x4C

    /// M
    public static let M: Byte = 0x4D

    /// N
    public static let N: Byte = 0x4E

    /// O
    public static let O: Byte = 0x4F

    /// P
    public static let P: Byte = 0x50

    /// Q
    public static let Q: Byte = 0x51

    /// R
    public static let R: Byte = 0x52

    /// S
    public static let S: Byte = 0x53

    /// T
    public static let T: Byte = 0x54

    /// U
    public static let U: Byte = 0x55

    /// V
    public static let V: Byte = 0x56

    /// W
    public static let W: Byte = 0x57

    /// X
    public static let X: Byte = 0x58

    /// Y
    public static let Y: Byte = 0x59

    /// Z
    public static let Z: Byte = 0x5A
}

extension Byte {
    /// a
    public static let a: Byte = 0x61

    /// b
    public static let b: Byte = 0x62

    /// c
    public static let c: Byte = 0x63

    /// d
    public static let d: Byte = 0x64

    /// e
    public static let e: Byte = 0x65

    /// f
    public static let f: Byte = 0x66

    /// g
    public static let g: Byte = 0x67

    /// h
    public static let h: Byte = 0x68

    /// i
    public static let i: Byte = 0x69

    /// j
    public static let j: Byte = 0x6A

    /// k
    public static let k: Byte = 0x6B

    /// l
    public static let l: Byte = 0x6C

    /// m
    public static let m: Byte = 0x6D

    /// n
    public static let n: Byte = 0x6E

    /// o
    public static let o: Byte = 0x6F

    /// p
    public static let p: Byte = 0x70

    /// q
    public static let q: Byte = 0x71

    /// r
    public static let r: Byte = 0x72

    /// s
    public static let s: Byte = 0x73

    /// t
    public static let t: Byte = 0x74

    /// u
    public static let u: Byte = 0x75

    /// v
    public static let v: Byte = 0x76

    /// w
    public static let w: Byte = 0x77

    /// x
    public static let x: Byte = 0x78

    /// y
    public static let y: Byte = 0x79

    /// z
    public static let z: Byte = 0x7A
}

