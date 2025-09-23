//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Collections
public import NIOConcurrencyHelpers
public import NIOCore
public import NIOHTTPTypes

/// Request Body
///
/// Can be either a stream of ByteBuffers or a single ByteBuffer
public struct RequestBody: Sendable, AsyncSequence {
    @usableFromInline
    internal enum _Backing: Sendable {
        case byteBuffer(ByteBuffer, NIOAsyncChannelRequestBody?)
        case nioAsyncChannelRequestBody(NIOAsyncChannelRequestBody)
        case anyAsyncSequence(AnyAsyncSequence<ByteBuffer>, NIOAsyncChannelRequestBody?)
    }

    @usableFromInline
    internal let _backing: _Backing

    @usableFromInline
    init(_ backing: _Backing) {
        self._backing = backing
    }

    ///  Initialise ``RequestBody`` from ByteBuffer
    /// - Parameter buffer: ByteBuffer
    @inlinable
    public init(buffer: ByteBuffer) {
        self.init(.byteBuffer(buffer, nil))
    }

    ///  Initialise ``RequestBody`` from AsyncSequence of ByteBuffers
    /// - Parameter asyncSequence: AsyncSequence
    @inlinable
    package init(nioAsyncChannelInbound: NIOAsyncChannelRequestBody) {
        self.init(.nioAsyncChannelRequestBody(nioAsyncChannelInbound))
    }

    ///  Initialise ``RequestBody`` from AsyncSequence of ByteBuffers
    /// - Parameter asyncSequence: AsyncSequence
    @inlinable
    public init<AS: AsyncSequence & Sendable>(asyncSequence: AS) where AS.Element == ByteBuffer, AS.AsyncIterator: SendableMetatype {
        self.init(.anyAsyncSequence(.init(asyncSequence), nil))
    }
}

/// AsyncSequence protocol requirements
extension RequestBody {
    public typealias Element = ByteBuffer

    public struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline
        internal enum _Backing {
            case byteBuffer(ByteBuffer)
            case nioAsyncChannelRequestBody(NIOAsyncChannelRequestBody.AsyncIterator)
            case anyAsyncSequence(AnyAsyncSequence<ByteBuffer>.AsyncIterator)
            case done
        }

        @usableFromInline
        var _backing: _Backing

        @usableFromInline
        init(_ backing: _Backing) {
            self._backing = backing
        }

        @inlinable
        public mutating func next() async throws -> ByteBuffer? {
            switch self._backing {
            case .byteBuffer(let buffer):
                self._backing = .done
                return buffer

            case .nioAsyncChannelRequestBody(var iterator):
                let next = try await iterator.next()
                self._backing = .nioAsyncChannelRequestBody(iterator)
                return next

            case .anyAsyncSequence(let iterator):
                return try await iterator.next()

            case .done:
                return nil
            }
        }
    }

    @inlinable
    public func makeAsyncIterator() -> AsyncIterator {
        switch self._backing {
        case .byteBuffer(let buffer, _):
            return .init(.byteBuffer(buffer))
        case .nioAsyncChannelRequestBody(let requestBody):
            return .init(.nioAsyncChannelRequestBody(requestBody.makeAsyncIterator()))
        case .anyAsyncSequence(let stream, _):
            return .init(.anyAsyncSequence(stream.makeAsyncIterator()))
        }
    }

    var originalRequestBody: NIOAsyncChannelRequestBody? {
        switch _backing {
        case .nioAsyncChannelRequestBody(let body): body
        case .byteBuffer(_, let body): body
        case .anyAsyncSequence: nil
        }
    }
}

/// Extend RequestBody to create request body streams backed by `NIOThrowingAsyncSequenceProducer`.
extension RequestBody {
    @usableFromInline
    typealias Producer = NIOThrowingAsyncSequenceProducer<
        ByteBuffer,
        any Error,
        NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark,
        Delegate
    >

    /// Delegate for NIOThrowingAsyncSequenceProducer
    ///
    /// This can be a struct as the state is stored inside a NIOLockedValueBox which
    /// turns it into a reference value
    @usableFromInline
    struct Delegate: NIOAsyncSequenceProducerDelegate, Sendable {
        enum State {
            case produceMore
            case waitingForProduceMore(CheckedContinuation<Void, Never>?)
            case multipleWaitingForProduceMore(Deque<CheckedContinuation<Void, Never>>)
            case terminated
        }
        let state: NIOLockedValueBox<State>

        @usableFromInline
        init() {
            self.state = .init(.produceMore)
        }

        @usableFromInline
        func produceMore() {
            self.state.withLockedValue { state in
                switch state {
                case .produceMore:
                    break
                case .waitingForProduceMore(let continuation):
                    if let continuation {
                        continuation.resume()
                    }
                    state = .produceMore

                case .multipleWaitingForProduceMore(var continuations):
                    // this isnt exactly correct as the number of continuations
                    // resumed can overflow the back pressure
                    while let cont = continuations.popFirst() {
                        cont.resume()
                    }
                    state = .produceMore

                case .terminated:
                    preconditionFailure("Unexpected state")
                }
            }
        }

        @usableFromInline
        func didTerminate() {
            self.state.withLockedValue { state in
                switch state {
                case .produceMore:
                    break
                case .waitingForProduceMore(let continuation):
                    if let continuation {
                        continuation.resume()
                    }
                    state = .terminated
                case .multipleWaitingForProduceMore(var continuations):
                    while let cont = continuations.popFirst() {
                        cont.resume()
                    }
                    state = .terminated
                case .terminated:
                    preconditionFailure("Unexpected state")
                }
            }
        }

        @usableFromInline
        func waitForProduceMore() async {
            switch self.state.withLockedValue({ $0 }) {
            case .produceMore, .terminated:
                break
            case .waitingForProduceMore, .multipleWaitingForProduceMore:
                await withCheckedContinuation { (newContinuation: CheckedContinuation<Void, Never>) in
                    self.state.withLockedValue { state in
                        switch state {
                        case .produceMore:
                            newContinuation.resume()
                        case .waitingForProduceMore(let firstContinuation):
                            if let firstContinuation {
                                var continuations = Deque<CheckedContinuation<Void, Never>>()
                                continuations.reserveCapacity(2)
                                continuations.append(firstContinuation)
                                continuations.append(newContinuation)
                                state = .multipleWaitingForProduceMore(continuations)
                            } else {
                                state = .waitingForProduceMore(newContinuation)
                            }
                        case .multipleWaitingForProduceMore(var continuations):
                            continuations.append(newContinuation)
                            state = .multipleWaitingForProduceMore(continuations)
                        case .terminated:
                            newContinuation.resume()
                        }
                    }
                }
            }
        }

        @usableFromInline
        func stopProducing() {
            self.state.withLockedValue { state in
                switch state {
                case .produceMore:
                    state = .waitingForProduceMore(nil)
                case .waitingForProduceMore:
                    break
                case .multipleWaitingForProduceMore:
                    break
                case .terminated:
                    break
                }
            }
        }
    }

    /// A source used for driving a ``RequestBody`` stream.
    public final class Source: Sendable {
        @usableFromInline
        let source: Producer.Source
        @usableFromInline
        let delegate: Delegate

        @usableFromInline
        init(source: Producer.Source, delegate: Delegate) {
            self.source = source
            self.delegate = delegate
        }

        /// Yields the element to the inbound stream.
        ///
        /// This function implements back pressure in that it will wait if the producer
        /// sequence indicates the Source should produce more ByteBuffers.
        ///
        /// - Parameter element: The element to yield to the inbound stream.
        @inlinable
        public func yield(_ element: ByteBuffer) async throws {
            // if previous call indicated we should stop producing wait until the delegate
            // says we can start producing again
            await self.delegate.waitForProduceMore()
            let result = self.source.yield(element)
            if result == .stopProducing {
                self.delegate.stopProducing()
            }
        }

        /// Finished the inbound stream.
        @inlinable
        public func finish() {
            self.source.finish()
        }

        /// Finished the inbound stream.
        ///
        /// - Parameter error: The error to throw
        @inlinable
        public func finish(_ error: any Error) {
            self.source.finish(error)
        }
    }

    ///  Make a new ``RequestBody`` stream
    /// - Returns: The new `RequestBody` and a source to yield ByteBuffers to the `RequestBody`.
    @inlinable
    public static func makeStream() -> (RequestBody, Source) {
        let delegate = Delegate()
        let newSequence = Producer.makeSequence(
            backPressureStrategy: .init(lowWatermark: 2, highWatermark: 4),
            finishOnDeinit: false,
            delegate: delegate
        )
        return (.init(asyncSequence: newSequence.sequence), Source(source: newSequence.source, delegate: delegate))
    }
}

/// Request body that is a stream of ByteBuffers sourced from a NIOAsyncChannelInboundStream.
///
/// This is a unicast async sequence that allows a single iterator to be created.
@usableFromInline
package struct NIOAsyncChannelRequestBody: Sendable, AsyncSequence {
    public typealias Element = ByteBuffer
    public typealias InboundStream = NIOAsyncChannelInboundStream<HTTPRequestPart>

    @usableFromInline
    internal let underlyingIterator: UnsafeTransfer<InboundStream.AsyncIterator>
    @usableFromInline
    internal let alreadyIterated: NIOLockedValueBox<Bool>

    /// Initialize NIOAsyncChannelRequestBody from AsyncIterator of a NIOAsyncChannelInboundStream
    @inlinable
    public init(iterator: InboundStream.AsyncIterator) {
        self.underlyingIterator = .init(iterator)
        self.alreadyIterated = .init(false)
    }

    /// Async Iterator for NIOAsyncChannelRequestBody
    public struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline
        internal var underlyingIterator: InboundStream.AsyncIterator
        @usableFromInline
        internal var done: Bool

        @inlinable
        init(underlyingIterator: InboundStream.AsyncIterator, done: Bool = false) {
            self.underlyingIterator = underlyingIterator
            self.done = done
        }

        @inlinable
        public mutating func next() async throws -> ByteBuffer? {
            if self.done { return nil }
            // if we are still expecting parts and the iterator finishes.
            // In this case I think we can just assume we hit an .end
            guard let part = try await self.underlyingIterator.next() else { return nil }
            switch part {
            case .body(let buffer):
                return buffer
            case .end:
                self.done = true
                return nil
            default:
                throw HTTPChannelError.unexpectedHTTPPart(part)
            }
        }
    }

    @inlinable
    public func makeAsyncIterator() -> AsyncIterator {
        // verify if an iterator has already been created. If it has then create an
        // iterator that returns nothing. This could be a precondition failure (currently
        // an assert) as you should not be allowed to do this.
        let done = self.alreadyIterated.withLockedValue {
            assert($0 == false, "Can only create iterator from request body once")
            let done = $0
            $0 = true
            return done
        }
        return AsyncIterator(underlyingIterator: self.underlyingIterator.wrappedValue, done: done)
    }
}
