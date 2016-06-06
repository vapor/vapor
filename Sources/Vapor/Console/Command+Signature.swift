/**
    A required argument that must be
    passed to the command.
 */
public struct Argument: CustomStringConvertible {
    /**
        The readable name of the argument
        that is used to fetch it with
        the `argument(_:String)` method.
     */
    public let name: String

    public init(_ name: String) {
        self.name = name
    }

    public var description: String {
        return name
    }
}

/**
    An optional item that can be
    passed to the command.
 */
public struct Option: CustomStringConvertible {
    /**
        The readable name of the option
        that is used to fetch it with
        the `option(_:String)` method.
     */
    public let name: String

    public init(_ name: String) {
        self.name = name
    }

    public var description: String {
        return name
    }
}

/**
    Argument and Option additions.
 */
extension Command {
    public func option(_ name: String) -> Polymorphic? {
        return app.config["app", name]
    }

    public func argument(_ name: String) throws -> Polymorphic {
        var index: Int? = nil

        for (i, argument) in arguments.enumerated() {
            if argument.name == name {
                index = i
                break
            }
        }

        guard var i = index else {
            throw CommandError.invalidArgument(name)
        }

        i += 2

        if app.arguments.count < i {
            throw CommandError.insufficientArguments
        }

        return app.arguments[i]
    }
}
