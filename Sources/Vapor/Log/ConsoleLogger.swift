import libc

/**
    Logs to the console

    - parameter level: LogLevel enum
    - parameter message: String to log
*/
public class ConsoleLogger: LogDriver {
	let console: Console

	/**
		Creates an instance of `ConsoleLogger`
		with the desired `Console`.
	*/
	public init(console: Console) {
		self.console = console
	}

    /**
        The basic log function of the console.

        - parameter level: the level with which to filter
        - parameter message: the message to log to console
     */
    public func log(_ level: Log.Level, message: String) {
        let date = time(nil)
        console.output("[\(date)] [\(level)] \(message)")
    }
}
