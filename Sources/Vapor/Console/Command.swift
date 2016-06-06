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
    var id: String { get }

    /**
        The command needs a reference to the
        application to perform various tasks.
        This is usually passed in as an init parameter.
    */
    var app: Application { get }

    /**
        An array of help messages that are
        printed by the help command.
        Each item in the array is printed on
        one line of the command.
    */
    var help: [String] { get }

    /**
        An array of Arguments that this command accepts. 
        This will be used to ensure the command does 
        not run unless enough arguments are passed.
        It is also used to create the command's signature

        Arguments are required items.
    */
    var arguments: [Argument] { get }

    /**
        An array of Options that this command
        accepts. This will be used to format
        the command's signature.
    */
    var options: [Option] { get }

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
    public var help: [String] {
        return []
    }

    public var arguments: [Argument] {
        return []
    }

    public var options: [Option] {
        return []
    }
}
