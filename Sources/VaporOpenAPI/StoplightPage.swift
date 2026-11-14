#if OpenAPI
import Vapor

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A page that shows an OpenAPI document with [Stoplight Elements](https://stoplight.io/open-source/elements).
///
/// Elements loads from a CDN, so the page needs a connection to it. The version is pinned and its
/// files checked by their hashes, so a changed or compromised package can't run on the API's origin.
struct StoplightPage: ResponseEncodable {
    /// The Elements release the page loads. Update the `integrity` hashes along with it.
    static let version = "9.0.29"

    /// The page's title.
    var title: String
    /// Where the page loads the document from, such as `./docs/openapi.json`.
    var documentURL: String

    var html: String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(Self.escaped(title))</title>
          <script src="https://unpkg.com/@stoplight/elements@\(Self.version)/web-components.min.js"
            integrity="sha384-enyjBaVmV00WFIo0D7AIVgtZ/4x0idVNWHotG8WUpvQo9HXgMSGAAW2YEOpiJTpP" crossorigin="anonymous"></script>
          <link rel="stylesheet" href="https://unpkg.com/@stoplight/elements@\(Self.version)/styles.min.css"
            integrity="sha384-iVQBHadsD+eV0M5+ubRCEVXrXEBj+BqcuwjUwPoVJc0Pb1fmrhYSAhL+BFProHdV" crossorigin="anonymous">
        </head>
        <body>
          <elements-api apiDescriptionUrl="\(Self.escaped(documentURL))" router="hash" layout="sidebar"></elements-api>
        </body>
        </html>
        """
    }

    func encodeResponse(for request: Request) async throws -> Response {
        try await View(data: Data(html.utf8)).encodeResponse(for: request)
    }

    /// Where the page at `pagePath`, a request's percent-encoded path, finds the document, relative to it.
    ///
    /// Worked out from the request rather than the route, so a group's path prefix and a trailing
    /// slash both count: `/api/docs` gives `./docs/openapi.json`, `/api/docs/` gives `./openapi.json`.
    static func documentURL(from pagePath: String) -> String {
        guard !pagePath.hasSuffix("/"), let last = pagePath.split(separator: "/").last else {
            return "./openapi.json"
        }
        // The path is already percent-encoded, so the segment is used as it is. The `./` stops a
        // segment such as `v1:docs` from being read as a URL scheme.
        return "./\(last)/openapi.json"
    }

    /// `text` with the characters HTML gives a meaning to replaced, so it can't break the page.
    private static func escaped(_ text: String) -> String {
        text.replacing("&", with: "&amp;")
            .replacing("<", with: "&lt;")
            .replacing(">", with: "&gt;")
            .replacing("\"", with: "&quot;")
    }
}
#endif
