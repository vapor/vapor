import C7

// ASCII
// http://www.theasciicode.com.ar/ascii-control-characters/form-feed-female-symbol-venus-ascii-code-12.html
let NewLine: C7.Byte = 10
let CarriageReturn: C7.Byte = 13
let MinimumValidAsciiCharacter = CarriageReturn + 1

// MARK: Byte => Character
extension Character {
    init(_ byte: C7.Byte) {
        let scalar = UnicodeScalar(byte)
        self.init(scalar)
    }
}
