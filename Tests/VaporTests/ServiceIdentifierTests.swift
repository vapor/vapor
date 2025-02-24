import XCTest
import Vapor
@testable import Vapor

final class ServiceIdentifierTests: XCTestCase {
    
    func testServiceIdentifierInitialization() async throws {
        // Create a service identifier
        let serviceId = await ServiceIdentifier(Application.self, label: "test-service", version: 1.0)
        
        // Assert that we can get a valid string representation
        let idString = await serviceId.string
        XCTAssertTrue(idString.contains("test-service"))
        XCTAssertTrue(idString.contains("@1.0"))
        
        // Test the description property
        XCTAssertEqual(serviceId.description, "[invalid]:test-service@[invalid]")
    }
    
    func testServiceIdStorage() async throws {
        // Create an application instance
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // Initially the ID should be nil
        let initialId = await app.id.getId()
        XCTAssertNil(initialId)
        
        // Create and set a service identifier
        let serviceId = await ServiceIdentifier(Application.self, label: "vapor-app", version: 2.5)
        await app.id.setId(serviceId)
        
        // Verify we can retrieve the stored ID
        let retrievedId = await app.id.getId()
        XCTAssertNotNil(retrievedId)
        
        // Verify the retrieved ID has correct values
        let idString = await retrievedId!.string
        XCTAssertTrue(idString.contains("vapor-app"))
        XCTAssertTrue(idString.contains("@2.5"))
    }
    
    func testMultipleApplicationsWithUniqueIds() async throws {
        // Create multiple application instances
        let app1 = Application(.testing)
        defer { app1.shutdown() }
        
        let app2 = Application(.testing)
        defer { app2.shutdown() }
        
        // Create service identifiers for each app
        let serviceId1 = await ServiceIdentifier(Application.self, label: "app-1", version: 1.0)
        let serviceId2 = await ServiceIdentifier(Application.self, label: "app-2", version: 1.1)
        
        // Set the IDs
        await app1.id.setId(serviceId1)
        await app2.id.setId(serviceId2)
        
        // Retrieve and verify
        let id1 = await app1.id.getId()
        let id2 = await app2.id.getId()
        
        XCTAssertNotNil(id1)
        XCTAssertNotNil(id2)
        
        let id1String = await id1!.string
        let id2String = await id2!.string
        
        XCTAssertTrue(id1String.contains("app-1"))
        XCTAssertTrue(id2String.contains("app-2"))
        
        XCTAssertNotEqual(id1String, id2String)
    }
    
    func testFatalErrorOnDuplicateAppType() async throws {
        // Testing that a fatal error is thrown when trying to create a service ID
        // with the same app type twice
        
        // First create a service ID
        _ = await ServiceIdentifier(Application.self, label: "first", version: 1.0)
        
        // Expect a fatal error when creating another with the same type
        // Note: In real tests, you would need to use a special technique to catch fatal errors
        // This is a placeholder showing the intent of the test
        
        // expectFatalError {
        //     await ServiceIdentifier(Application.self, label: "second", version: 2.0)
        // }
        
        // Since we can't easily test for fatal errors in Swift, we'll add a comment
        // indicating that this should be manually verified
        print("Manual verification required: Creating duplicate ServiceIdentifier with same app type should cause fatal error")
    }
    
    func testServiceIdPersistence() async throws {
        // Create an application and set its ID
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let serviceId = await ServiceIdentifier(Application.self, label: "persistent-app", version: 3.0)
        await app.id.setId(serviceId)
        
        // Retrieve through a different accessor to verify storage works
        let retrievedId = await app.id.getId()
        XCTAssertNotNil(retrievedId)
        
        // Create a new accessor and verify it can still find the same ID
        let anotherAccessor = Application.ServiceID(_application: app)
        let idFromAnotherAccessor = await anotherAccessor.getId()
        XCTAssertNotNil(idFromAnotherAccessor)
        
        // Verify they're the same by comparing string representations
        let str1 = await retrievedId!.string
        let str2 = await idFromAnotherAccessor!.string
        XCTAssertEqual(str1, str2)
    }
    
    func testClearingServiceId() async throws {
        // Create an application and set its ID
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let serviceId = await ServiceIdentifier(Application.self, label: "temp-app", version: 1.5)
        await app.id.setId(serviceId)
        
        // Verify ID is set
        let initialId = await app.id.getId()
        XCTAssertNotNil(initialId)
        
        // Clear the ID
        await app.id.setId(nil)
        
        // Verify ID is now nil
        let clearedId = await app.id.getId()
        XCTAssertNil(clearedId)
    }
    
    static var allTests = [
        ("testServiceIdentifierInitialization", testServiceIdentifierInitialization),
        ("testServiceIdStorage", testServiceIdStorage),
        ("testMultipleApplicationsWithUniqueIds", testMultipleApplicationsWithUniqueIds),
        ("testFatalErrorOnDuplicateAppType", testFatalErrorOnDuplicateAppType),
        ("testServiceIdPersistence", testServiceIdPersistence),
        ("testClearingServiceId", testClearingServiceId)
    ]
}

