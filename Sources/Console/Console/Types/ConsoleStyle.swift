/// Representation of a style for outputting to a Console
/// in different colors with differing attributes. A few
/// suggested default styles are provided.
///
/// A `nil` `color` means "don't change the color".
/// A `nil` `background` means "don't change the background".
public struct ConsoleStyle {
    let color: ConsoleColor?
    let background: ConsoleColor?
    let isBold: Bool
    
    public init(color: ConsoleColor?, background: ConsoleColor? = nil, isBold: Bool = false) {
        self.color = color
        self.background = background
        self.isBold = isBold
    }

    public static var plain: ConsoleStyle { return .init(color: nil) }
    public static var success: ConsoleStyle { return .init(color: .green) }
    public static var info: ConsoleStyle { return .init(color: .cyan) }
    public static var warning: ConsoleStyle { return .init(color: .yellow) }
    public static var error: ConsoleStyle { return .init(color: .red) }
}
