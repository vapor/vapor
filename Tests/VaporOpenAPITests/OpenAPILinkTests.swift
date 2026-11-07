#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

private enum UserID: OpenAPILinkKey {}
private enum OrderID: OpenAPILinkKey {
    static var description: String? { "The order to look up" }
}

@Suite("OpenAPILink")
struct OpenAPILinkTests {
    // MARK: - Runtime expressions

    @Test(
        "Every location maps to the matching runtime expression",
        arguments: [
            (OpenAPILink("limit", in: .request(.query)), "$request.query.limit"),
            (OpenAPILink("X-Id", in: .request(.header)), "$request.header.X-Id"),
            (OpenAPILink("userId", in: .request(.path)), "$request.path.userId"),
            (OpenAPILink("id", in: .request(.body)), "$request.body#/id"),
            (OpenAPILink("Location", in: .response(.header)), "$response.header.Location"),
            (OpenAPILink("id", in: .response(.body)), "$response.body#/id"),
            // An empty body name refers to the whole body.
            (OpenAPILink("", in: .request(.body)), "$request.body"),
            (OpenAPILink("", in: .response(.body)), "$response.body"),
            // A slash in a body name reaches into nested fields.
            (OpenAPILink("data/id", in: .response(.body)), "$response.body#/data/id"),
            (OpenAPILink("data/items/0/id", in: .response(.body)), "$response.body#/data/items/0/id"),
            (OpenAPILink("/id", in: .response(.body)), "$response.body#/id"),
        ]
    )
    func expressions(link: OpenAPILink, expected: String) {
        #expect(link.expression?.rawValue == expected)
    }

    @Test("A request cookie has no runtime expression, since it can only be a target")
    func cookieHasNoExpression() {
        let link = OpenAPILink("session", in: .request(.cookie))

        #expect(link.expression == nil)
        #expect(link.location.description == "request.cookie")
        #expect(link.identifier == "RequestCookieSession")
    }

    // MARK: - Locations

    @Test(
        "Locations describe themselves as in a runtime expression",
        arguments: [
            (OpenAPILink.Location.request(.query), "request.query"),
            (.request(.header), "request.header"),
            (.request(.path), "request.path"),
            (.request(.cookie), "request.cookie"),
            (.request(.body), "request.body"),
            (.response(.header), "response.header"),
            (.response(.body), "response.body"),
        ]
    )
    func locationDescriptions(location: OpenAPILink.Location, expected: String) {
        #expect(location.description == expected)
    }

    // MARK: - Identifiers

    @Test(
        "Identifiers join the location and name in PascalCase, safe to use as component keys",
        arguments: [
            (OpenAPILink("id", in: .response(.body)), "ResponseBodyId"),
            (OpenAPILink("Location", in: .response(.header)), "ResponseHeaderLocation"),
            (OpenAPILink("userId", in: .request(.path)), "RequestPathUserId"),
            (OpenAPILink("", in: .request(.body)), "RequestBody"),
            // Dotted and nested body names split into PascalCase words.
            (OpenAPILink("owner.name", in: .response(.body)), "ResponseBodyOwnerName"),
            (OpenAPILink("data/id", in: .response(.body)), "ResponseBodyDataId"),
            // Characters a component key can't have are replaced.
            (OpenAPILink("owner name", in: .response(.body)), "ResponseBodyOwner-name"),
            (OpenAPILink("user id", in: .request(.path)), "RequestPathUser-id"),
            (OpenAPILink("X-Id", in: .request(.header)), "RequestHeaderX-Id"),
        ]
    )
    func identifiers(link: OpenAPILink, expected: String) {
        #expect(link.identifier == expected)
    }

    // MARK: - Keys

    @Test("Key ids are equal for the same key type and differ across types")
    func keyIDs() {
        #expect(UserID.linkKeyID == UserID.linkKeyID)
        #expect(UserID.linkKeyID != OrderID.linkKeyID)
        #expect(Set([UserID.linkKeyID, UserID.linkKeyID, OrderID.linkKeyID]).count == 2)
    }
}

@Suite("Component key safety")
struct ComponentKeySafeTests {
    @Test(
        "Allowed characters are kept and everything else becomes a dash",
        arguments: [
            ("abcXYZ019", "abcXYZ019"),
            ("a.b-c_d", "a.b-c_d"),
            ("a b", "a-b"),
            ("a/b:c@d", "a-b-c-d"),
            ("ключ", "----"),
            ("", ""),
        ]
    )
    func sanitising(input: String, expected: String) {
        #expect(input.componentKeySafe == expected)
    }
}
#endif
