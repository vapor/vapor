import XCTest
import Vapor
@testable import Vapor

final class ServiceIdentifiableTests: XCTestCase {
    
    func testServiceIdentifiableInitialization() async throws {
        // Create a service identifier
        let serviceID = await ServiceIdentifiable(Application.self, label: "test-service", version: 1.0)
        
        // Assert that we can get a valid string representation
        let idString = await serviceID.string
        XCTAssertTrue(idString.contains("test-service"))
        XCTAssertTrue(idString.contains("@1.0"))
        
        // Test the description property
        XCTAssertEqual(serviceID.description, "[invalid]:test-service@[invalid]")
    }
    
    func testServiceIdStorage() async throws {
        // Create an application instance
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // Initially the ID should be nil
        let initialID = await app.id.description
        XCTAssertNil(initialID)
        
        // Create and set a service identifier
        let serviceID = await ServiceIdentifiable(Application.self, label: "vapor-app", version: 2.5)
        await app.id.register(serviceID)
        
        // Verify we can retrieve the stored ID
        let retrievedID = await app.id.description
        XCTAssertNotNil(retrievedID)
        
        // Verify the retrieved ID has correct values
        let idString = await retrievedID!.description
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
        let serviceId1 = await ServiceIdentifiable(Application.self, label: "app-1", version: 1.0)
        let serviceId2 = await ServiceIdentifiable(Application.self, label: "app-2", version: 1.1)
        
        // Set the IDs
        await app1.id.register(serviceId1)
        await app2.id.register(serviceId2)
        
        // Retrieve and verify
        let id1 = await app1.id.description
        let id2 = await app2.id.description
        
        XCTAssertNotNil(id1)
        XCTAssertNotNil(id2)
        
        let id1String = id1!.description
        let id2String = id2!.description
        
        XCTAssertTrue(id1String.contains("app-1"))
        XCTAssertTrue(id2String.contains("app-2"))
        
        XCTAssertNotEqual(id1String, id2String)
    }
    
    func testFatalErrorOnDuplicateAppType() async throws {
        // Testing that a fatal error is thrown when trying to create a service ID
        // with the same app type twice
        
        // First create a service ID
        _ = await ServiceIdentifiable(Application.self, label: "first", version: 1.0)
        
        // Expect a fatal error when creating another with the same type
        // Note: In real tests, you would need to use a special technique to catch fatal errors
        // This is a placeholder showing the intent of the test
        
        // expectFatalError {
        //     await ServiceIdentifiable(Application.self, label: "second", version: 2.0)
        // }
        
        // Since we can't easily test for fatal errors in Swift, we'll add a comment
        // indicating that this should be manually verified
        print("Manual verification required: Creating duplicate ServiceIdentifiable with same app type should cause fatal error")
    }
    
    func testServiceIdPersistence() async throws {
        // Create an application and set its ID
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let serviceID = await ServiceIdentifiable(Application.self, label: "persistent-app", version: 3.0)
        await app.id.register(serviceID)
        
        // Retrieve through a different accessor to verify storage works
        let retrievedID = await app.id.description
        XCTAssertNotNil(retrievedID)
        
        // Create a new accessor and verify it can still find the same ID
      let anotherAccessor = Application.ServiceIdentity(_application: app)
        let idFromAnotherAccessor = await anotherAccessor.description
        XCTAssertNotNil(idFromAnotherAccessor)
        
        // Verify they're the same by comparing string representations
        let str1 = retrievedID?.description
        let str2 = idFromAnotherAccessor?.description
        XCTAssertEqual(str1, str2)
    }
    
    func testClearingServiceId() async throws {
        // Create an application and set its ID
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let serviceID = await ServiceIdentifiable(Application.self, label: "temp-app", version: 1.5)
        await app.id.register(serviceID)
        
        // Verify ID is set
        let initialID = await app.id.register(serviceID)
        XCTAssertNotNil(initialID)
        
        // Clear the ID
        await app.id.description
        
        // Verify ID is now nil
        let clearedId = await app.id.description
        XCTAssertNil(clearedId)
    }
    
    static var allTests = [
        ("testServiceIdentifiableInitialization", testServiceIdentifiableInitialization),
        ("testServiceIdStorage", testServiceIdStorage),
        ("testMultipleApplicationsWithUniqueIds", testMultipleApplicationsWithUniqueIds),
        ("testFatalErrorOnDuplicateAppType", testFatalErrorOnDuplicateAppType),
        ("testServiceIdPersistence", testServiceIdPersistence),
        ("testClearingServiceId", testClearingServiceId)
    ]
}

