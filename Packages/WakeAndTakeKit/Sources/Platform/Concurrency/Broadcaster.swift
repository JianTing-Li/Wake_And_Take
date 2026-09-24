//
//  Broadcaster.swift
//  WakeAndTakeKit
//
//  Fans one stream of events out to any number of listeners.
//

import Foundation
import Synchronization

/// Each call to `stream()` gets its own `AsyncStream`; `send` yields to all of them.
/// A listener stops receiving when its task is cancelled or its stream is dropped.
public final class Broadcaster<Element: Sendable>: Sendable {
    private let continuations = Mutex<[UUID: AsyncStream<Element>.Continuation]>([:])

    public init() {}

    public func stream() -> AsyncStream<Element> {
        let (stream, continuation) = AsyncStream<Element>.makeStream(bufferingPolicy: .bufferingNewest(32))
        let id = UUID()
        continuations.withLock { $0[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            self?.continuations.withLock { _ = $0.removeValue(forKey: id) }
        }
        return stream
    }

    public func send(_ element: Element) {
        let targets = continuations.withLock { Array($0.values) }
        for continuation in targets {
            continuation.yield(element)
        }
    }

    /// Number of active listeners (for tests).
    public var listenerCount: Int {
        continuations.withLock { $0.count }
    }
}
