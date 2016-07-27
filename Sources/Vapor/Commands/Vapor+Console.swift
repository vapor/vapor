import Console
@_exported import protocol Console.ConsoleProtocol
@_exported import protocol Console.Command
@_exported import struct Console.Option
@_exported import protocol Console.Argument
@_exported import protocol Console.Runnable
@_exported import class Console.Terminal
@_exported import enum Console.ConsoleStyle
@_exported import enum Console.ConsoleColor
@_exported import enum Console.ConsoleClear
@_exported import enum Console.ConsoleError

public typealias ArgValue = Value

public enum CommandError: Swift.Error {
    case general(String)
}
