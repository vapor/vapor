//
//  VaporAsyncCommand.swift
//  
//
//  Created by 张行 on 2022/6/21.
//
#if compiler(>=5.5) && canImport(_Concurrency)
import Foundation
import ConsoleKit

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol VaporAsyncCommand: Command {
    func runAsync(using context: CommandContext, signature: Signature) async throws
}

extension VaporAsyncCommand {
    public func run(using context: CommandContext, signature: Signature) throws {
        let promise = context.application.eventLoopGroup.next().makePromise(of: Void.self)
        promise.completeWithTask {
            try await runAsync(using: context, signature: signature)
        }
        try promise.futureResult.wait()
    }
}
#endif
