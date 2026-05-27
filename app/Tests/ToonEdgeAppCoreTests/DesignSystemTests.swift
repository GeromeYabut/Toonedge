import Testing
@testable import ToonEdgeAppCore

@Test func toonEdgeNavigationChromeUsesReadableDarkModeTitleColors() {
    let chrome = ToonEdgeNavigationChrome.dark

    #expect(chrome.colorScheme == .dark)
    #expect(chrome.prefersVisibleLargeTitles)
}
