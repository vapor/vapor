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
	ProcessTests(),
	RouterTests(),
	RouteTests(),
	QueryParametersTests(),
	SessionTests(),
	TypedRouteTests(),
	JeevesTests()
])
