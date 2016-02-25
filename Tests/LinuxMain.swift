import XCTest
@testable import Vaportest

XCTMain([
	ControllerTests(),
	HashTests(),
	LogTests(),
	ResponseTests(),
	RouterTests(),
	RouteTests()
])
