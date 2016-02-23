//
//  LogTests.swift
//  Vapor
//
//  Created by Matthew on 23/02/2016.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
//@testable import Vapor

class LogTests: XCTestCase {

    class DummyLogger: Logger {
        
        static var output: String?
        
        func log(level: LogLevel, message: String) {
            DummyLogger.output = "\(level.description) \(message)"
        }
    }
    
    /* Resets the logger for each test
     */
    override func setUp() {
        DummyLogger.output = nil
        Log.driver = DummyLogger()
        Log.enabledLevels = LogLevel.all
    }
    
    func testCanOverrideDefaultLogger() {
        XCTAssertTrue(String(Log.driver).containsString("DummyLogger"), "driver should be DummyLogger")
    }
    
    func testAllLevelsEnabledByDefault() {
        let levels = LogLevel.all
        levels.forEach { level in
            XCTAssertTrue(Log.enabledLevels.contains(level))
        }
    }
    
    func testCanOverrideDefaultEnabledLevels() {
        Log.enabledLevels = [LogLevel.Debug]
        XCTAssertTrue(Log.enabledLevels.count == 1, "only one log level should be enabled")
        XCTAssertTrue(Log.enabledLevels.first == LogLevel.Debug, "only Debug logs should be enabled")
    }
    
    func testDisabledLogsDoNoOutput() {
        Log.enabledLevels = [LogLevel.Debug]
        Log.error("this should not output")
        XCTAssertNil(DummyLogger.output, "disabled level should not output")
    }
    
    func testVerboseDidLog() {
        Log.verbose("foo")
        XCTAssertTrue(DummyLogger.output == "VERBOSE foo", "logger should output VERBOSE foo")
    }
    
    func testDebugDidLog() {
        Log.debug("foo")
        XCTAssertTrue(DummyLogger.output == "DEBUG foo", "logger should output DEBUG foo")
    }
    
    func testInfoDidLog() {
        Log.info("foo")
        XCTAssertTrue(DummyLogger.output == "INFO foo", "logger should output INFO foo")
    }
    
    func testWarningDidLog() {
        Log.warning("foo")
        XCTAssertTrue(DummyLogger.output == "WARNING foo", "logger should output WARNING foo")
    }
    
    func testErrorDidLog() {
        Log.error("foo")
        XCTAssertTrue(DummyLogger.output == "ERROR foo", "logger should output ERROR foo")
    }
    
    func testFatalDidLog() {
        Log.fatal("foo")
        XCTAssertTrue(DummyLogger.output == "FATAL foo", "logger should output FATAL foo")
    }
    
    func testCustomDidLog() {
        Log.custom("foo", label: "customlog")
        XCTAssertTrue(DummyLogger.output == "CUSTOMLOG foo", "logger should output CUSTOMLOG foo")
    }
    
    func testConsoleLoggerDidPrintToConsole() {
        Log.driver = ConsoleLogger()
        XCTAssertNotNil(Log.info("foo")) //Todo: This test isn't actually doing anything. I'm unsure how to assert console output...?
    }
}