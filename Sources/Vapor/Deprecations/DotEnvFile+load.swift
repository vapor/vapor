import Logging
import NIOCore
import NIOPosix

extension DotEnvFile {
    /// Reads the dotenv files relevant to the environment and loads them into the process.
    ///
    ///     let environment: Environment
    ///     let elgp: EventLoopGroupProvider
    ///     let logger: Logger
    ///     try DotEnvFile.load(for: .development, on: elgp, logger: logger)
    ///     print(Environment.process.FOO) // BAR
    ///
    /// - parameters:
    ///     - environment: current environment, selects which .env file to use.
    ///     - eventLoopGroupProvider: Either provides an EventLoopGroup or tells the function to create a new one.
    ///     - logger: Optionally provide an existing logger.
    @available(*, deprecated, message: "use `load(for:on:fileio:logger)`")
    public static func load(
        for environment: Environment = .development,
        on eventLoopGroupProvider: Application.EventLoopGroupProvider = .createNew,
        logger: Logger = Logger(label: "dot-env-loggger")
    ) {
        let threadPool = NIOThreadPool(numberOfThreads: 1)
        threadPool.start()
        defer {
            do {
                try threadPool.syncShutdownGracefully()
            } catch {
                logger.warning("Shutting down threadPool failed: \(error)")
            }
        }
        let fileio = NonBlockingFileIO(threadPool: threadPool)

        self.load(for: environment, on: eventLoopGroupProvider, fileio: fileio, logger: logger)
    }

    /// Reads the dotenv files relevant to the environment and loads them into the process.
    ///
    ///     let path: String
    ///     let elgp: EventLoopGroupProvider
    ///     let logger: Logger
    ///     try DotEnvFile.load(path: path, on: elgp, logger: logger)
    ///     print(Environment.process.FOO) // BAR
    ///
    /// - parameters:
    ///     - path: Absolute or relative path of the dotenv file.
    ///     - eventLoopGroupProvider: Either provides an EventLoopGroup or tells the function to create a new one.
    ///     - logger: Optionally provide an existing logger.
    @available(*, deprecated, message: "use `load(path:on:fileio:logger)`")
    public static func load(
        path: String,
        on eventLoopGroupProvider: Application.EventLoopGroupProvider = .createNew,
        logger: Logger = Logger(label: "dot-env-loggger")
    ) {
        let threadPool = NIOThreadPool(numberOfThreads: 1)
        threadPool.start()
        defer {
            do {
                try threadPool.syncShutdownGracefully()
            } catch {
                logger.warning("Shutting down threadPool failed: \(error)")
            }
        }
        let fileio = NonBlockingFileIO(threadPool: threadPool)

        self.load(path: path, on: eventLoopGroupProvider, fileio: fileio, logger: logger)
    }
}
