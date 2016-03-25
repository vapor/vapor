//
//  LogTests.swift
//  Vapor
//
//  Created by Matthew on 23/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

#if os(Linux)
    extension LogTests: XCTestCaseProvider {
        var allTests : [(String, () throws -> Void)] {
            return [
                ("testCanOverrideDefaultLogger", testCanOverrideDefaultLogger),
                ("testAllLevelsEnabledByDefault", testAllLevelsEnabledByDefault),
                ("testCanOverrideDefaultEnabledLevels", testCanOverrideDefaultEnabledLevels),
                ("testDisabledLogsDoNoOutput", testDisabledLogsDoNoOutput),
                ("testVerboseDidLog", testVerboseDidLog),
                ("testDebugDidLog", testDebugDidLog),
                ("testInfoDidLog", testInfoDidLog),
                ("testWarningDidLog", testWarningDidLog),
                ("testErrorDidLog", testErrorDidLog),
                ("testFatalDidLog", testFatalDidLog),
                ("testCustomDidLog", testCustomDidLog),
                ("testConsoleLoggerDidPrintToConsole", testConsoleLoggerDidPrintToConsole)
            ]
        }
    }
#endif

class LogTests: XCTestCase {

    class DummyLogger: LogDriver {
        
        static var output: String?
        
        func log(level: Log.Level, message: String) {
            DummyLogger.output = "\(level.description) \(message)"
        }
    }
    
    /* Resets the logger for each test
     */
    //due to running tests on both Linux and OSX, we can't
    //use methods setup etc, because those are overriden methods on one platform
    //and implemented protocol method on another.
    //we can use it again once those APIs converge again
    func prepare() {
        DummyLogger.output = nil
        Log.driver = DummyLogger()
        Log.enabledLevels = Log.Level.all
    }
    
    func testCanOverrideDefaultLogger() {
        prepare()
        XCTAssertTrue(String(Log.driver).contains("DummyLogger"), "driver should be DummyLogger")
    }
    
    func testAllLevelsEnabledByDefault() {
        prepare()
        let levels = Log.Level.all
        levels.forEach { level in
            XCTAssertTrue(Log.enabledLevels.contains(level), "\(level) should be enabled")
        }
    }
    
    func testCanOverrideDefaultEnabledLevels() {
        prepare()
        Log.enabledLevels = [Log.Level.Debug]
        XCTAssertTrue(Log.enabledLevels.count == 1, "only one log level should be enabled")
        XCTAssertTrue(Log.enabledLevels.first == Log.Level.Debug, "only Debug logs should be enabled")
    }
    
    func testDisabledLogsDoNoOutput() {
        prepare()
        Log.enabledLevels = [Log.Level.Debug]
        Log.error("this should not output")
        XCTAssertNil(DummyLogger.output, "disabled level should not output")
    }
    
    func testVerboseDidLog() {
        prepare()
        Log.verbose("foo")
        XCTAssertTrue(DummyLogger.output == "VERBOSE foo", "logger should output VERBOSE foo")
    }
    
    func testDebugDidLog() {
        prepare()
        Log.debug("foo")
        XCTAssertTrue(DummyLogger.output == "DEBUG foo", "logger should output DEBUG foo")
    }
    
    func testInfoDidLog() {
        prepare()
        Log.info("foo")
        XCTAssertTrue(DummyLogger.output == "INFO foo", "logger should output INFO foo")
    }
    
    func testWarningDidLog() {
        prepare()
        Log.warning("foo")
        XCTAssertTrue(DummyLogger.output == "WARNING foo", "logger should output WARNING foo")
    }
    
    func testErrorDidLog() {
        prepare()
        Log.error("foo")
        XCTAssertTrue(DummyLogger.output == "ERROR foo", "logger should output ERROR foo")
    }
    
    func testFatalDidLog() {
        prepare()
        Log.fatal("foo")
        XCTAssertTrue(DummyLogger.output == "FATAL foo", "logger should output FATAL foo")
    }
    
    func testCustomDidLog() {
        prepare()
        Log.custom("foo", label: "customlog")
        XCTAssertTrue(DummyLogger.output == "CUSTOMLOG foo", "logger should output CUSTOMLOG foo")
    }
    
    func testConsoleLoggerDidPrintToConsole() {
        prepare()
        Log.driver = ConsoleLogger()
        XCTAssertNotNil(Log.info("foo")) //Todo: This test isn't actually doing anything. I'm unsure how to assert console output...?
    }
}