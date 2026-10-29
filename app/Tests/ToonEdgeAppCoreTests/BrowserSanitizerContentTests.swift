import Foundation
import Testing
@testable import ToonEdgeAppCore

/// Owned structural reproductions of observed site labels. CSP prevents remote resource bytes.
@Suite(.serialized)
@MainActor
struct BrowserSanitizerContentTests {
    @Test(arguments: ["read-container", "sidebar-hidden", "fade-out", "combined"], [false, true])
    func chapterLayoutRemainsVisible(label: String, hydrate: Bool) async throws {
        let html = fixture(label: label, hydrate: hydrate)
        let origin = URL(string: "https://owned.example.test/chapter-7")!
        for sanitize in [false, true] {
            let harness = MatrixWebKitHarness()
            let page = try await harness.analyze(html: html, pageURL: origin, sanitize: sanitize,
                                                 phase: hydrate ? .afterHydration : .static)
            let panels = page.images.filter { $0.id?.hasPrefix("panel-") == true }
            #expect(panels.count == 14)
            #expect(panels.allSatisfy { $0.width == 390 && $0.renderedHeight == 1350 },
                "Noise labels must not collapse chapter ancestors")
            #expect(zip(panels, panels.dropFirst()).allSatisfy { $0.top < $1.top })
            for id in ["inline-noise", "sponsor-noise", "sidebar-noise"] {
                let noise = try #require(page.images.first { $0.id == id })
                #expect(noise.renderedHeight == (sanitize ? 0 : 600),
                    "Real ad/sidebar surfaces must still be removed, including inside chapter content")
            }
            #expect(harness.externalResourceByteCount == 0)
        }
    }

    private func fixture(label: String, hydrate: Bool) -> String {
        let bodyClass = label == "fade-out" || label == "combined" ? "fade-out" : ""
        let outerClass = label == "sidebar-hidden" || label == "combined"
            ? "main-col col-md-12 col-sm-12 sidebar-hidden" : "main-col"
        let innerClass = label == "read-container" || label == "combined" ? "read-container" : "content"
        let panels = (1...14).map {
            "<img id='panel-\($0)' data-reader-page-image src='/pages/\($0).jpg'>"
        }.joined()
        let content = "<div class='\(outerClass)'><div class='\(innerClass)'><main class='chapter-content'>\(panels)<div class='sidebar-hidden ad-slot'><img id='inline-noise' class='noise' src='/ads/one.jpg'></div></main></div></div><div class='sponsored-banner'><img id='sponsor-noise' class='noise' src='/ads/two.jpg'></div><aside class='sidebar'><img id='sidebar-noise' class='noise' src='/ads/three.jpg'></aside>"
        let encoded = String(data: try! JSONEncoder().encode(content), encoding: .utf8)!
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
        <title>Owned Chapter 7</title><style>html,body{margin:0;width:390px}img{display:block;width:390px;height:1350px}.noise{height:600px}</style>
        </head><body class="\(bodyClass)"><div id="mount">\(hydrate ? "" : content)</div>
        <script>window.matrixHydrate=()=>{document.getElementById('mount').innerHTML=\(encoded);window.matrixHydrated=true;};</script>
        </body></html>
        """
    }
}
