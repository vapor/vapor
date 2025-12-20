import Vapor
import Testing
import Logging

@Suite("Application Creation Tests")
struct ApplicationCreationTests {

    @Test("Create Default Logger")
    func defaultLogger() async throws {
        let app = try await Application(.testing)
        #expect(app.logger.label == "codes.vapor.application")
        try await app.shutdown()
    }

    @Test("Create Custom Logger")
    func customLogger() async throws {
        let logger = Logger(label: "custom")
        let app = try await Application(.testing, services: .init(logger: .provided(logger)))
        #expect(app.logger.label == "custom")
        try await app.shutdown()
    }
}
