/// Underlying colors for console styles.
/// - Note: Normal and bright colors are represented here
/// separately instead of as a flag on `ConsoleStyle`
/// basically because "that's how ANSI colors work". It's
/// a little conceptually weird, but so are terminal
/// control codes.
public enum ConsoleColor {
    case black
    case red
    case green
    case yellow
    case blue
    case magenta
    case cyan
    case white
    
    case brightBlack
    case brightRed
    case brightGreen
    case brightYellow
    case brightBlue
    case brightMagenta
    case brightCyan
    case brightWhite
    
    /// A color from the predefined 256-color palette
    case palette(UInt8)
    
    /// A 24-bit "true" color
    case custom(r: UInt8, g: UInt8, b: UInt8)
}
