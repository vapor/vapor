import XCTest
@testable import Vaportest

XCTMain([
	ControllerTests(),
	EnvironmentTests(),
	HashTests(),
	LogTests(),
	MemorySessionDriverTests(),
	ResponseTests(),
	RouterTests(),
	RouteTests(),
	SessionTests()
])
