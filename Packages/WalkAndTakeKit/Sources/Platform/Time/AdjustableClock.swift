//
//  AdjustableClock.swift
//  WalkAndTakeKit
//
//  DEBUG-only clock for time travel, previews, tests and UI tests.
//

#if DEBUG
    import Foundation
    import Synchronization

    /// Either runs at live speed with an offset, or is frozen at a fixed instant.
    public final class AdjustableClock: Clock {
        private enum Mode {
            case offset(TimeInterval)
            case frozen(Date)
        }

        private let base: any Clock
        private let mode: Mutex<Mode>
        private let broadcaster = Broadcaster<Void>()

        /// Live time shifted by `offset` seconds.
        public init(base: any Clock = LiveClock(), offset: TimeInterval = 0) {
            self.base = base
            mode = Mutex(.offset(offset))
        }

        /// Frozen at `date` until moved.
        public init(fixedAt date: Date) {
            base = LiveClock()
            mode = Mutex(.frozen(date))
        }

        public var now: Date {
            switch mode.withLock({ $0 }) {
            case .offset(let offset): base.now.addingTimeInterval(offset)
            case .frozen(let date): date
            }
        }

        public var isLive: Bool {
            if case .offset(0) = mode.withLock({ $0 }) { true } else { false }
        }

        public func changes() -> AsyncStream<Void> {
            broadcaster.stream()
        }

        /// Jumps to `date`, keeping the current mode (running or frozen).
        public func travel(to date: Date) {
            mode.withLock { mode in
                switch mode {
                case .offset: mode = .offset(date.timeIntervalSince(base.now))
                case .frozen: mode = .frozen(date)
                }
            }
            broadcaster.send(())
        }

        public func advance(by interval: TimeInterval) {
            travel(to: now.addingTimeInterval(interval))
        }

        /// Back to real time.
        public func resetToLive() {
            mode.withLock { $0 = .offset(0) }
            broadcaster.send(())
        }
    }
#endif
