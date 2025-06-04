// ===----------------------------------------------------------------------===##
//
//  This source file is part of the Vapor open source project
//
//  Copyright (c) 2017-2021 Vapor project authors
//  Licensed under MIT
//
//  See LICENSE for license information
//
//  SPDX-License-Identifier: MIT
//
// ===----------------------------------------------------------------------===##
// This was adapted from Swift Metrics's TestMetrics.swift code.
// The license for the original work is reproduced below. See NOTICES.txt for
// more.

import Metrics
import Foundation
import NIOConcurrencyHelpers

internal final class TaskLocalMetricsSysemWrapper: MetricsFactory {
    func makeCounter(label: String, dimensions: [(String, String)]) -> any CoreMetrics.CounterHandler {
        metrics.makeCounter(label: label, dimensions: dimensions)
    }
    
    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> any CoreMetrics.RecorderHandler {
        metrics.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
    }
    
    func makeTimer(label: String, dimensions: [(String, String)]) -> any CoreMetrics.TimerHandler {
        metrics.makeTimer(label: label, dimensions: dimensions)
    }
    
    func destroyCounter(_ handler: any CoreMetrics.CounterHandler) {
        metrics.destroyCounter(handler)
    }
    
    func destroyRecorder(_ handler: any CoreMetrics.RecorderHandler) {
        metrics.destroyRecorder(handler)
    }
    
    func destroyTimer(_ handler: any CoreMetrics.TimerHandler) {
        metrics.destroyTimer(handler)
    }
}

/// Metrics factory which allows inspecting recorded metrics programmatically.
/// Only intended for tests of the Metrics API itself.
internal final class CapturingMetricsSystem: MetricsFactory, @unchecked Sendable {
    private let lock = NIOLock()
    var counters = [String: any CounterHandler]()
    var recorders = [String: any RecorderHandler]()
    var timers = [String: any TimerHandler]()
    let number: String

    init(_ number: String) {
        self.number = number
    }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> any CounterHandler {
        print("CaputuringMetricsSystem \(number)")
        return self.lock.withLock { self.make(label: label, dimensions: dimensions, registry: &self.counters, maker: TestCounter.init) }
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> any RecorderHandler {
        print("CaputuringMetricsSystem \(number)")
        let maker = { (label: String, dimensions: [(String, String)]) -> any RecorderHandler in
            TestRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        }
        return self.lock.withLock { self.make(label: label, dimensions: dimensions, registry: &self.recorders, maker: maker) }
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> any TimerHandler {
        print("CaputuringMetricsSystem \(number)")
        return self.lock.withLock { self.make(label: label, dimensions: dimensions, registry: &self.timers, maker: TestTimer.init) }
    }

    private func make<Item>(label: String, dimensions: [(String, String)], registry: inout [String: Item], maker: (String, [(String, String)]) -> Item) -> Item {
        let item = maker(label, dimensions)
        registry[label] = item
        return item
    }

    func destroyCounter(_ handler: any CounterHandler) {
        print("CaputuringMetricsSystem \(number)")
        if let testCounter = handler as? TestCounter {
            self.lock.withLockVoid {
                self.counters.removeValue(forKey: testCounter.label)
            }
        }
    }

    func destroyRecorder(_ handler: any RecorderHandler) {
        print("CaputuringMetricsSystem \(number)")
        if let testRecorder = handler as? TestRecorder {
            self.lock.withLockVoid {
                self.recorders.removeValue(forKey: testRecorder.label)
            }
        }
    }

    func destroyTimer(_ handler: any TimerHandler) {
        print("CaputuringMetricsSystem \(number)")
        if let testTimer = handler as? TestTimer {
            self.lock.withLockVoid {
                self.timers.removeValue(forKey: testTimer.label)
            }
        }
    }
}

internal final class TestCounter: CounterHandler, Equatable, @unchecked Sendable {
    let id: String
    let label: String
    let dimensions: [(String, String)]

    let lock = NIOLock()
    var values = [(Date, Int64)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = UUID().uuidString
        self.label = label
        self.dimensions = dimensions
    }

    func increment(by amount: Int64) {
        self.lock.withLock {
            self.values.append((Date(), amount))
        }
    }

    func reset() {
        self.lock.withLock {
            self.values = []
        }
    }

    public static func == (lhs: TestCounter, rhs: TestCounter) -> Bool {
        return lhs.id == rhs.id
    }
}

internal final class TestRecorder: RecorderHandler, Equatable, @unchecked Sendable {
    let id: String
    let label: String
    let dimensions: [(String, String)]
    let aggregate: Bool

    let lock = NIOLock()
    var values = [(Date, Double)]()

    init(label: String, dimensions: [(String, String)], aggregate: Bool) {
        self.id = UUID().uuidString
        self.label = label
        self.dimensions = dimensions
        self.aggregate = aggregate
    }

    func record(_ value: Int64) {
        self.record(Double(value))
    }

    func record(_ value: Double) {
        self.lock.withLock {
            values.append((Date(), value))
        }
    }

    public static func == (lhs: TestRecorder, rhs: TestRecorder) -> Bool {
        return lhs.id == rhs.id
    }
}

internal final class TestTimer: TimerHandler, Equatable, @unchecked Sendable {
    let id: String
    let label: String
    var displayUnit: TimeUnit?
    let dimensions: [(String, String)]

    let lock = NIOLock()
    var values = [(Date, Int64)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = UUID().uuidString
        self.label = label
        self.displayUnit = nil
        self.dimensions = dimensions
    }

    func preferDisplayUnit(_ unit: TimeUnit) {
        self.lock.withLock {
            self.displayUnit = unit
        }
    }

    func retrieveValueInPreferredUnit(atIndex i: Int) -> Double {
        return self.lock.withLock {
            let value = values[i].1
            guard let displayUnit = self.displayUnit else {
                return Double(value)
            }
            return Double(value) / Double(displayUnit.scaleFromNanoseconds)
        }
    }

    func recordNanoseconds(_ duration: Int64) {
        self.lock.withLock {
            values.append((Date(), duration))
        }
    }

    public static func == (lhs: TestTimer, rhs: TestTimer) -> Bool {
        return lhs.id == rhs.id
    }
}
