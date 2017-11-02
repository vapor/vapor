public protocol Identifiable {
    /// A readable name for the error's Type. This is usually
    /// similar to the Type name of the error with spaces added.
    /// This will normally be printed proceeding the error's reason.
    /// - note: For example, an error named `FooError` will have the
    /// `readableName` `"Foo Error"`.
    static var readableName: String { get }

    /// The reason for the error.
    /// Typical implementations will switch over `self`
    /// and return a friendly `String` describing the error.
    /// - note: It is most convenient that `self` be a `Swift.Error`.
    ///
    /// Here is one way to do this:
    ///
    ///     switch self {
    ///     case someError:
    ///        return "A `String` describing what went wrong including the actual error: `Error.someError`."
    ///     // other cases
    ///     }
    var reason: String { get }

    // MARK: Identifiers

    /// A unique identifier for the error's Type.
    /// - note: This defaults to `ModuleName.TypeName`,
    /// and is used to create the `identifier` property.
    static var typeIdentifier: String { get }

    /// Some unique identifier for this specific error.
    /// This will be used to create the `identifier` property.
    /// Do NOT use `String(reflecting: self)` or `String(describing: self)`
    /// or there will be infinite recursion
    var identifier: String { get }
}

extension Identifiable {
    public func identifiableHelp(format: HelpFormat) -> String {
        var print: [String] = []

        switch format {
        case .long:
            print.append("⚠️ \(Self.readableName): \(reason)")
            print.append("- id: \(fullIdentifier)")
        case .short:
            print.append("⚠️ [\(fullIdentifier): \(reason)]")
        }

        return print.joined(separator: "\n")
    }

    public var fullIdentifier: String {
        return Self.typeIdentifier + "." + identifier
    }
}

extension Identifiable {
    /// Default implementation of readable name that expands
    /// SomeModule.MyType.Error => My Type Error
    public static var readableName: String {
        return typeIdentifier.readableTypeName()
    }

    public static var typeIdentifier: String {
        return String(reflecting: self)
    }
}

extension String {
    func readableTypeName() -> String {
        let characterSequence = self.split(separator: ".")
            .dropFirst() // drop module
            .joined(separator: [])

        let characters = Array(characterSequence)
        guard var expanded = characters.first.flatMap({ String($0) }) else { return "" }

        characters.suffix(from: 1).forEach { char in
            if char.isUppercase {
                expanded.append(" ")
            }

            expanded.append(char)
        }

        return expanded
    }
}

extension Character {
    var isUppercase: Bool {
        switch self {
        case "A"..."Z":
            return true
        default:
            return false
        }
    }
}
