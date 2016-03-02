import XCTest
@testable import Vaportest

XCTMain([
	ControllerTests(),
	EnvironmentTests(),
	HashTests(),
	LogTests(),
	ResponseTests(),
	RouterTests(),
	RouteTests()
])
