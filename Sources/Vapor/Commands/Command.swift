import libc
import Foundation

/**
    Commands are ran when the application
    is started based on which identifier
    is passed as an argument to the executable.
*/
public protocol Command {
    /**
        The main identifier for the command.
        If this identifier matches the string 
        passed to the application executable during
        boot, the command will run.
    */
    static var id: String { get }

    /**
        An array of help messages that are
        printed by the help command.
        Each item in the array is printed on
        one line of the command.
    */
    static var help: [String] { get }

    /**
        An array of Arguments and Options that this 
        command accepts. This will be used to ensure 
        the command does not run unless enough arguments 
        are passed. It is also used to create the signature

        Arguments are required items. Options are optional.
    */
    static var signature: [Signature] { get }

    /**
        The command needs a reference to the
        application to perform various tasks.
        This is usually passed in as an init parameter.
     */
    var app: Application { get }

    /**
        Creates an instance of the command.

        This inhibits the command from having its
        own init method and non-optional properties,
        but it ensures that the application does not
        boot unnecessary resources for each command
        by only booting commands when they run.
     */
    init(app: Application)

    /**
        Runs the command.

        `CommandError.custom` can be thrown
        to echo an error to the console while
        halting the command.
    */
    func run() throws
}

public enum CommandError: ErrorProtocol {
    case invalidArgument(String)
    case insufficientArguments
    case custom(String)
}

/**
    Defaults for basic commands.
*/
extension Command {
    public static var help: [String] {
        return []
    }

    public static var signature: [Signature] {
        return []
    }


    /**
        Returns the command's signature.
     */
    public static func signature(leading: String = "") -> String {
        var signature = "\(Self.id)"

        let arguments = Self.signature.filter { signature in
            return signature is Argument
        }

        let options = Self.signature.filter { signature in
            return signature is Option
        }

        for argument in arguments {
            signature += " <\(argument)>"
        }

        for option in options {
            signature += " {--\(option)}"
        }

        return signature
    }
}
