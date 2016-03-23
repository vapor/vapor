import XCTest
@testable import Vaportest

XCTMain([
	ConfigTests(),
	ControllerTests(),
	EnvironmentTests(),
	HashTests(),
	LogTests(),
	MemorySessionDriverTests(),
	ResponseTests(),
	RouterTests(),
	RouteTests(),
	SessionTests(),
	TypedRouteTests()
])
