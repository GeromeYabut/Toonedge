import Foundation
import Testing
#if canImport(JavaScriptCore)
import JavaScriptCore
#endif
@testable import ToonEdgeAppCore

@Test func manualBandRetainsViableSessionWithoutRecommendingIt() throws {
    let result = GenericChapterDetector().detect(page: try entryPage(count: 4))
    #expect(result.score == 46)
    #expect(result.confidence == .low)
    #expect(result.readerEntryDisposition == .manual)
    #expect(result.readerSession?.imageURLs.count == 4)
}

@Test func highBandDoesNotFallBackWhenCandidateAndHeightConstraintsFail() throws {
    let page = DetectionPageAnalysis(
        pageURL: try #require(URL(string: "https://example.test/chapter-1")),
        title: "Chapter 1", documentHeight: 18_000, viewportWidth: 390,
        images: Array(chapterImages(host: "cdn.example.test").prefix(5))
    )
    let result = GenericChapterDetector().detect(page: page)
    #expect(result.score >= 78)
    #expect(result.readerEntryDisposition == .unavailable)
    #expect(result.diagnostics.tallestHeightRatio == 0)
    #expect(result.readerSession == nil)
}

@Test func protectedViewerIsUnavailableRegardlessOfScore() throws {
    var page = try entryPage(count: 8, width: 900, height: 1_350)
    page.documentHeight = 18_000
    for block in DetectionHardBlock.allCases {
        let protectedPage = try pageWithPayloadFields(page, fields: ["hardBlocks": [block.rawValue]])
        let result = ProfileAwareChapterDetector().detect(page: protectedPage)
        #expect(result.readerEntryDisposition == .unavailable)
        #expect(result.diagnostics.hardBlocks.contains(block))
        #expect(result.readerSession == nil, "Blocked by \(block.rawValue)")
    }
}

@Test func tallestImageRequiresActualViewportHeight() throws {
    var page = try entryPage(count: 2, width: 900, height: 4_500)
    page.documentHeight = 18_000
    let tallViewport = try pageWithPayloadFields(page, fields: ["viewportHeight": 1_500])
    let shortViewport = try pageWithPayloadFields(page, fields: ["viewportHeight": 800])
    #expect(GenericChapterDetector().detect(page: tallViewport).readerSession == nil)
    #expect(GenericChapterDetector().detect(page: shortViewport).readerSession != nil)
    #expect(GenericChapterDetector().detect(page: shortViewport).readerEntryDisposition == .recommended)
    #expect(GenericChapterDetector().detect(page: shortViewport).diagnostics.negativeScore == -16)
    #expect(GenericChapterDetector().detect(page: shortViewport).diagnostics.tallestHeightRatio == 5.625)
}

@Test func unavailableResultsPreserveAllTypedBlocksThroughProfilesAndFollowUp() throws {
    for host in ["unknown.example.test", "mangapill.com", "mangafire.to", "m.webtoons.com", "mangahere.cc"] {
        var page = try entryPage(count: 8, width: 900, height: 1_350)
        page.pageURL = try #require(URL(string: "https://\(host)/chapter-1"))
        page.hardBlocks = [.authentication, .paywall, .protectedViewer]
        page.challengeSignals = ["challenge-copy"]
        let detector = ProfileAwareChapterDetector()
        for result in [detector.detect(page: page), detector.detectBrowserSessionFollowUp(page: page)] {
            #expect(result.readerEntryDisposition == .unavailable)
            #expect(result.readerSession == nil)
            #expect(result.retryRecommendation == .none)
            #expect(result.diagnostics.hardBlocks.isSuperset(of: [.challenge, .authentication, .paywall, .protectedViewer]))
        }
    }
}

@Test func legacyAnalysisAndDiagnosticsDecodeWithConservativeDefaults() throws {
    let page = try detectionFixture(named: "mangapill_hydrated_dom")
    #expect(page.viewportHeight == 0)
    #expect(page.hardBlocks.isEmpty)
    let json = Data(#"{"confidence":"low","score":0,"parserPath":"genericHeuristic","retryRecommendation":"none","candidateCount":0,"messages":[]}"#.utf8)
    let diagnostics = try JSONDecoder().decode(DetectionDiagnostics.self, from: json)
    #expect(diagnostics.hardBlocks.isEmpty)
    #expect(diagnostics.negativeScore == 0)
    #expect(diagnostics.tallestHeightRatio == 0)
}

@Test func blockedResultInitializerCannotHonorAnExplicitEntryDisposition() throws {
    let page = try entryPage(count: 8, width: 900, height: 1_350)
    let session = try #require(GenericChapterDetector().detect(page: page).readerSession)
    let result = DetectionResult(pageURL: page.pageURL, confidence: .high, score: 100, candidates: page.images,
        readerSession: session,
        diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic, hardBlocks: [.paywall]),
        readerEntryDisposition: .automatic)
    #expect(result.readerEntryDisposition == .unavailable)
    #expect(result.readerSession == nil)
}

@Test func unavailableResultInitializerCannotRetainAReaderSession() throws {
    let page = try entryPage(count: 8, width: 900, height: 1_350)
    let session = try #require(GenericChapterDetector().detect(page: page).readerSession)
    let result = DetectionResult(pageURL: page.pageURL, confidence: .high, score: 100, candidates: page.images,
        readerSession: session,
        diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic),
        readerEntryDisposition: .unavailable)
    #expect(result.readerSession == nil)
    #expect(result.readerEntryDisposition == .unavailable)
}

@Test func taggedOpaqueSourcesNeverCreateReaderSession() throws {
    for scheme in ["blob:https://cdn.example.test/", "data:image/png;base64,", "file:///pages/", "javascript:"] {
        var page = try entryPage(count: 8, width: 900, height: 1_350)
        for index in page.images.indices {
            page.images[index].src = scheme + String(index)
            page.images[index].semanticHints = ["data-reader-page-image", "data-reader-index"]
        }
        let result = GenericChapterDetector().detect(page: page)
        #expect(result.readerSession == nil)
        #expect(result.readerEntryDisposition == .unavailable)
        #expect(result.candidates.isEmpty)
    }
}

@Test func knownViewportAllowsAutomaticEntryForFiveActuallyTallImages() throws {
    var page = try entryPage(count: 5, width: 900, height: 4_500)
    page.viewportHeight = 800
    let result = GenericChapterDetector(entryPolicy: .architectureDefault).detect(page: page)
    #expect(result.score == 79)
    #expect(result.readerEntryDisposition == .automatic)
    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 5)
}

#if canImport(JavaScriptCore)
@Test func renderedGatesBlockCleanModeWithoutTreatingGlobalDecorationsAsProtection() throws {
    for (gate, expected) in [("Sign in to read this chapter", "authentication"), ("Subscribe to unlock this chapter", "paywall"), ("404 page not found", "errorPage")] {
        let payload = try renderedEntryPayload(mainText: gate)
        let blocks = try #require(payload["hardBlocks"] as? [String])
        #expect(blocks == [expected], "Visible gate: \(gate)")
    }
    let ordinary = try renderedEntryPayload(mainText: "Chapter 1 Login", globalText: "Login Accept cookies Subscribe", decorativeCanvas: true)
    #expect((ordinary["hardBlocks"] as? [String])?.isEmpty == true)
}

@Test func renderedOpaqueViewersNeedContentSizeAndAbsenceOfNetworkPages() throws {
    for viewer in ["canvas", "blob"] {
        let opaque = try renderedEntryPayload(mainText: "Chapter 1", viewer: viewer)
        #expect(opaque["hardBlocks"] as? [String] == ["canvasOrBlob"])
        let withPages = try renderedEntryPayload(mainText: "Chapter 1", viewer: viewer, hasNetworkImages: true)
        #expect((withPages["hardBlocks"] as? [String])?.isEmpty == true)
    }
    let decoration = try renderedEntryPayload(mainText: "Chapter 1", decorativeCanvas: true, viewer: "canvas")
    #expect((decoration["hardBlocks"] as? [String])?.isEmpty == true)
    let recoverable = try renderedEntryPayload(mainText: "Chapter 1", viewer: "canvas", readerTaggedUnloadedImages: true)
    #expect((recoverable["hardBlocks"] as? [String])?.isEmpty == true)
}

@Test func renderedProtectedMarkersAndHiddenGatesRemainDistinct() throws {
    for marker in ["protectedViewer", "drm"] {
        let protected = try renderedEntryPayload(mainText: "Chapter 1", marker: marker)
        #expect(protected["hardBlocks"] as? [String] == [marker])
    }
    let hidden = try renderedEntryPayload(mainText: "Sign in to read this chapter", visible: false, marker: "protectedViewer")
    #expect((hidden["hardBlocks"] as? [String])?.isEmpty == true)
}

@Test func renderedLazySrcsetHydrationRemainsEligibleBesideOpaqueViewers() throws {
    for attribute in ["data-srcset", "data-lazy-srcset"] {
        for viewer in ["canvas", "blob"] {
            let fixture = try renderedChapterFixture(sourceAttribute: attribute, unloaded: true, viewer: viewer)
            #expect(fixture.page.hardBlocks.isEmpty, "\(attribute) beside \(viewer)")
            let result = GenericChapterDetector().detect(page: fixture.page)
            #expect(result.readerEntryDisposition == .automatic)
            #expect(result.readerSession?.imageURLs.count == 6)
            #expect(result.readerSession?.imageURLs.first?.absoluteString == "https://unknown.example.test/pages/1.jpg")
        }
    }
}

@Test func renderedOpaqueSchemesDoNotCountAsNetworkPages() throws {
    for attribute in ["src", "srcset", "data-srcset", "data-lazy-srcset"] {
        for source in ["blob:opaque-{index}", "data:image/png;base64,opaque{index}", "file:///pages/{index}.jpg", "javascript:page{index}"] {
            let fixture = try renderedChapterFixture(sourceAttribute: attribute, source: source, unloaded: true, viewer: "canvas")
            #expect(fixture.page.hardBlocks == [.canvasOrBlob], "\(attribute): \(source)")
            #expect(GenericChapterDetector().detect(page: fixture.page).readerSession == nil)
        }
    }
}

@Test func sanitizerPreservesVisibleAccessGatesBeforeDetection() throws {
    for (copy, gateClass, expected) in [
        ("Sign in to read this chapter", "auth-modal", DetectionHardBlock.authentication),
        ("Subscribe to unlock this chapter", "paywall-overlay", DetectionHardBlock.paywall)
    ] {
        for wrapped in [false, true] {
            let fixture = try renderedChapterFixture(gateText: copy, gateClass: gateClass, gateWrapped: wrapped, sanitize: true)
            #expect(fixture.page.hardBlocks == [expected])
            #expect(fixture.gateVisible, "Original access gate must remain visible")
            #expect(fixture.noiseHidden, "Ordinary ads and decorative overlays still disappear")
            let result = ProfileAwareChapterDetector().detect(page: fixture.page)
            #expect(result.candidates.count == 6, "Underlying images remain viable")
            #expect(result.readerEntryDisposition == .unavailable)
            #expect(result.readerSession == nil)
        }
    }
}

@Test func sanitizerPreservesAccessGateCopyInsideNoiseLabelledDescendants() throws {
    for (copy, expected) in [
        ("Sign in to read this chapter", DetectionHardBlock.authentication),
        ("Subscribe to unlock this chapter", DetectionHardBlock.paywall)
    ] {
        let fixture = try renderedChapterFixture(gateText: copy, gateClass: "auth-modal", gateNestedCopy: true, sanitize: true)
        #expect(fixture.page.hardBlocks == [expected])
        #expect(fixture.gateVisible)
        #expect(fixture.noiseHidden, "Ads in primary content remain suppressible")
        let result = ProfileAwareChapterDetector().detect(page: fixture.page)
        #expect(result.candidates.count == 6)
        #expect(result.readerEntryDisposition == .unavailable)
        #expect(result.readerSession == nil)
    }
}

@Test func sanitizerKeepsOriginallyHiddenLoginTemplatesDistinctFromAccessGates() throws {
    let fixture = try renderedChapterFixture(gateText: "Sign in to read this chapter", gateClass: "auth-modal", gateHidden: true, sanitize: true)
    #expect(fixture.page.hardBlocks.isEmpty)
    #expect(!fixture.gateVisible)
    #expect(fixture.noiseHidden)
    #expect(GenericChapterDetector().detect(page: fixture.page).readerEntryDisposition == .automatic)
}

@Test func sanitizerPreservesVisibleProtectedReaderMarkersAndTheirOverlays() throws {
    for marker in [DetectionHardBlock.protectedViewer, .drm] {
        let fixture = try renderedChapterFixture(gateClass: "protected-modal", gateWrapped: true, marker: marker.rawValue, sanitize: true)
        #expect(fixture.page.hardBlocks == [marker])
        #expect(fixture.gateVisible)
        #expect(fixture.noiseHidden)
        #expect(ProfileAwareChapterDetector().detect(page: fixture.page).readerSession == nil)
        let hidden = try renderedChapterFixture(gateClass: "protected-modal", gateHidden: true, marker: marker.rawValue, sanitize: true)
        #expect(hidden.page.hardBlocks.isEmpty)
        #expect(!hidden.gateVisible)
    }
}

private func installRenderedURLResolver(in context: JSContext) {
    let scheme: @convention(block) (String, String) -> String = { source, base in
        URL(string: source, relativeTo: URL(string: base))?.absoluteURL.scheme ?? ""
    }
    context.setObject(scheme, forKeyedSubscript: "__resolvedURLScheme" as NSString)
    context.evaluateScript("globalThis.URL = class { constructor(source, base) { this.protocol = __resolvedURLScheme(source, base) + ':'; } };")
}

private func renderedChapterFixture(sourceAttribute: String = "src", source: String = "/pages/{index}.jpg",
    unloaded: Bool = false, viewer: String = "", gateText: String = "", gateClass: String = "",
    gateHidden: Bool = false, gateWrapped: Bool = false, gateNestedCopy: Bool = false,
    marker: String = "", sanitize: Bool = false)
    throws -> (page: DetectionPageAnalysis, gateVisible: Bool, noiseHidden: Bool) {
    let context = try #require(JSContext())
    installRenderedURLResolver(in: context)
    let data = try JSONSerialization.data(withJSONObject: ["sourceAttribute": sourceAttribute, "source": source,
        "unloaded": unloaded, "viewer": viewer, "gateText": gateText, "gateClass": gateClass,
        "gateHidden": gateHidden, "gateWrapped": gateWrapped, "gateNestedCopy": gateNestedCopy, "marker": marker])
    let fixture = try #require(String(data: data, encoding: .utf8))
    context.evaluateScript("""
    const fixture = \(fixture);
    const computedStyle = (node) => {
      let hidden = false;
      for (let current = node; current; current = current.parentElement) {
        hidden ||= current.hidden || current.style.display === 'none' || current.style.visibility === 'hidden';
      }
      return { display: hidden ? 'none' : 'block', visibility: hidden ? 'hidden' : 'visible', opacity: '1' };
    };
    const makeNode = (tagName, attributes = {}, text = '', width = 390, height = 844, top = 0) => {
      const node = { tagName, attributes, text, children: [], parentElement: null, hidden: false,
        id: attributes.id || '', className: attributes.class || '', alt: '', currentSrc: '', naturalWidth: 0, naturalHeight: 0,
        style: { setProperty(name, value) { this[name] = value; } },
        getAttribute(name) { return this.attributes[name] || null; },
        hasAttribute(name) { return Object.hasOwn(this.attributes, name); },
        setAttribute(name, value) { this.attributes[name] = value; },
        matches(selector) { return selector.split(',').some((part) => {
          const token = part.trim();
          if (token === 'img[src^="blob:"]') return this.tagName === 'IMG' && (this.getAttribute('src') || '').startsWith('blob:');
          if (token.startsWith('.')) return this.className.split(' ').includes(token.slice(1));
          const attr = token.match(/^\\[([^=\\]]+)(?:="([^"]*)")?\\]$/);
          return attr ? this.hasAttribute(attr[1]) && (attr[2] === undefined || this.getAttribute(attr[1]) === attr[2]) : this.tagName.toLowerCase() === token;
        }); },
        querySelectorAll(selector) { return this.children.flatMap((child) => [child, ...child.querySelectorAll('*')]).filter((child) => selector === '*' || child.matches(selector)); },
        getBoundingClientRect() { return { width: computedStyle(this).display === 'none' ? 0 : width,
          height: computedStyle(this).display === 'none' ? 0 : height, top, left: 0 }; }
      };
      Object.defineProperty(node, 'innerText', { get() { return computedStyle(this).display === 'none' ? '' : [this.text, ...this.children.map((child) => child.innerText)].join(' '); } });
      return node;
    };
    const append = (parent, child) => { parent.children.push(child); child.parentElement = parent; return child; };
    const body = makeNode('BODY'); body.scrollHeight = 18000;
    const main = append(body, makeNode('MAIN', { class: 'reader-main' }, 'Chapter 1', 390, 18000));
    const images = Array.from({ length: 6 }, (_, offset) => {
      const index = offset + 1;
      const source = fixture.source.replace('{index}', index);
      const value = fixture.sourceAttribute.includes('srcset') ? source + ' 900w' : source;
      const image = append(main, makeNode('IMG', { [fixture.sourceAttribute]: value,
        'data-reader-page-image': 'true', 'data-reader-index': String(index) }, '', fixture.unloaded ? 0 : 900,
        fixture.unloaded ? 0 : 1350, index * 1360));
      image.naturalWidth = fixture.unloaded ? 0 : 900; image.naturalHeight = fixture.unloaded ? 0 : 1350;
      return image;
    });
    if (fixture.viewer === 'canvas') append(main, makeNode('CANVAS'));
    if (fixture.viewer === 'blob') { const blob = append(main, makeNode('IMG', { src: 'blob:opaque' })); images.push(blob); }
    const gateParent = fixture.gateNestedCopy ? main : body;
    const wrapper = fixture.gateWrapped ? append(gateParent, makeNode('DIV', { class: 'blocking-overlay' })) : gateParent;
    const gate = append(wrapper, makeNode('DIV', { role: 'dialog', class: fixture.gateClass }, fixture.gateNestedCopy ? '' : fixture.gateText));
    if (fixture.gateNestedCopy) append(gate, makeNode('DIV', { class: 'auth-header' }, fixture.gateText));
    if (fixture.marker === 'protectedViewer') gate.setAttribute('data-protected-reader', 'true');
    if (fixture.marker === 'drm') gate.setAttribute('data-drm-protected', 'true');
    gate.hidden = fixture.gateHidden;
    const ad = append(main, makeNode('ASIDE', { class: 'advert-banner' }, 'Advertisement'));
    const decoration = append(body, makeNode('DIV', { class: 'decorative-overlay' }, 'Accept cookies'));
    globalThis.window = { location: { href: 'https://unknown.example.test/chapter-1' }, innerWidth: 390, innerHeight: 844,
      scrollX: 0, scrollY: 0, getComputedStyle: computedStyle, open: () => null };
    globalThis.MutationObserver = class { constructor(callback) {} observe() {} };
    globalThis.document = { title: 'Chapter 1', images, body, documentElement: { scrollHeight: 18000, innerHTML: '' },
      querySelector: (selector) => body.querySelectorAll(selector)[0] || null,
      querySelectorAll: (selector) => body.querySelectorAll(selector) };
    """)
    #expect(context.exception == nil)
    if sanitize {
        context.evaluateScript(BrowserPageSanitizerScript.javaScript)
        #expect(context.exception == nil)
    }
    let json = try #require(context.evaluateScript(PageAnalysisScript.javaScript)?.toString())
    #expect(context.exception == nil)
    let page = try JSONDecoder().decode(DetectionPageAnalysis.self, from: Data(json.utf8))
    let gateVisibility = try #require(context.evaluateScript("computedStyle(gate).display !== 'none'"))
    let noiseVisibility = try #require(context.evaluateScript("computedStyle(ad).display === 'none' && computedStyle(decoration).display === 'none'"))
    let gateVisible = gateVisibility.toBool()
    let noiseHidden = noiseVisibility.toBool()
    return (page, gateVisible, noiseHidden)
}

private func renderedEntryPayload(mainText: String, globalText: String = "", decorativeCanvas: Bool = false,
    viewer: String = "", hasNetworkImages: Bool = false, visible: Bool = true, marker: String = "",
    readerTaggedUnloadedImages: Bool = false) throws -> [String: Any] {
    let context = try #require(JSContext())
    installRenderedURLResolver(in: context)
    let data = try JSONSerialization.data(withJSONObject: ["mainText": mainText, "globalText": globalText,
        "decorativeCanvas": decorativeCanvas, "viewer": viewer, "hasNetworkImages": hasNetworkImages,
        "visible": visible, "marker": marker, "readerTaggedUnloadedImages": readerTaggedUnloadedImages])
    let fixture = try #require(String(data: data, encoding: .utf8))
    context.evaluateScript("""
    const fixture = \(fixture);
    const main = { innerText: fixture.mainText, textContent: fixture.mainText, hidden: !fixture.visible,
      tagName: 'MAIN', id: '', className: '', getAttribute: () => null, hasAttribute: () => false,
      getBoundingClientRect: () => ({ width: 390, height: 844, top: 0, left: 0 }),
      querySelector: () => null, querySelectorAll: () => [], matches: () => false };
    const canvas = { ...main, tagName: 'CANVAS', getBoundingClientRect: () => ({
      width: fixture.decorativeCanvas ? 30 : 390, height: fixture.decorativeCanvas ? 30 : 844, top: 0, left: 0 }) };
    const networkImage = { ...main, tagName: 'IMG', naturalWidth: fixture.readerTaggedUnloadedImages ? 0 : 900,
      naturalHeight: fixture.readerTaggedUnloadedImages ? 0 : 1350,
      getBoundingClientRect: () => ({ width: fixture.readerTaggedUnloadedImages ? 0 : 390,
        height: fixture.readerTaggedUnloadedImages ? 0 : 844, top: 0, left: 0 }),
      hasAttribute: (name) => fixture.readerTaggedUnloadedImages && ['data-reader-page-image', 'data-reader-index'].includes(name),
      currentSrc: 'https://cdn.example.test/1.jpg', parentElement: main,
      getAttribute: (name) => name === 'src' ? 'https://cdn.example.test/1.jpg' : null };
    const blobImage = { ...networkImage, currentSrc: 'blob:opaque', getAttribute: (name) => name === 'src' ? 'blob:opaque' : null };
    main.querySelectorAll = (selector) => selector === 'img' && (fixture.hasNetworkImages || fixture.readerTaggedUnloadedImages) ? [networkImage] :
      selector === 'canvas, img[src^="blob:"]' ? (fixture.viewer === 'canvas' ? [canvas] : fixture.viewer === 'blob' ? [blobImage] : []) : [];
    globalThis.window = { location: { href: 'https://unknown.example.test/chapter-1' }, innerWidth: 390, innerHeight: 844, scrollX: 0, scrollY: 0,
      getComputedStyle: () => ({ display: 'block', visibility: 'visible', opacity: '1' }) };
    globalThis.getComputedStyle = window.getComputedStyle;
    globalThis.document = { title: 'Chapter 1', images: (fixture.hasNetworkImages || fixture.readerTaggedUnloadedImages) ? [networkImage] : fixture.viewer === 'blob' ? [blobImage] : [],
      body: { innerText: fixture.mainText + ' ' + fixture.globalText, scrollHeight: 844 },
      documentElement: { scrollHeight: 844, innerHTML: '' },
      querySelector: (selector) => selector.includes('main') ? main : null,
      querySelectorAll: (selector) => selector.includes('main') || selector.includes('role="main"') ? [main] :
        selector.includes('data-protected-reader') && fixture.marker === 'protectedViewer' ? [main] :
        selector.includes('data-drm-protected') && fixture.marker === 'drm' ? [main] :
        selector === 'canvas' && fixture.decorativeCanvas ? [canvas] :
        selector === 'iframe' ? [{ ...main, tagName: 'IFRAME', src: 'https://ads.example.test/' }] : [] };
    """)
    let json = try #require(context.evaluateScript(PageAnalysisScript.javaScript)?.toString())
    #expect(context.exception == nil)
    return try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
}
#endif

private func entryPage(count: Int, width: Double = 320, height: Double = 500) throws -> DetectionPageAnalysis {
    DetectionPageAnalysis(
        pageURL: try #require(URL(string: "https://unknown.example.test/story")),
        title: "Story", documentHeight: 2_000, viewportWidth: 390,
        images: (1...count).map { index in
            DetectionImageCandidate(src: "https://cdn.example.test/pages/\(index).jpg", lazySources: [], srcset: nil,
                width: width, height: height, top: Double(index) * (height + 10), left: 0,
                className: nil, id: nil, alt: nil, parentSignature: nil)
        }
    )
}

private func pageWithPayloadFields(_ page: DetectionPageAnalysis, fields: [String: Any]) throws -> DetectionPageAnalysis {
    var payload = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(page)) as? [String: Any])
    payload.merge(fields) { _, new in new }
    return try JSONDecoder().decode(DetectionPageAnalysis.self, from: JSONSerialization.data(withJSONObject: payload))
}

@Test func detectionLogURLShapeDropsQueryCredentialsAndSpecificRouteValues() throws {
    let url = try #require(URL(string:
        "https://user:secret@vortexscans.org/series/past-life-returner/chapter-169?token=private"
    ))

    let shape = DetectionLogURLShape(url: url)

    #expect(shape.host == "vortexscans.org")
    #expect(shape.pathShape == "/series/:segment/chapter-:number")
    #expect(!shape.description.contains("past-life-returner"))
    #expect(!shape.description.contains("token"))
    #expect(!shape.description.contains("secret"))
}

@Test func detectionLogURLShapeDropsMixedRouteValues() throws {
    let url = try #require(URL(string: "https://vortexscans.org/series/past-life-returner/chapter-private-169"))

    let shape = DetectionLogURLShape(url: url)

    #expect(shape.pathShape == "/series/:segment/:segment")
    #expect(!shape.description.contains("private"))
}

@Test func detectorNormalizesLazyLoadedImageSources() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Moonlit Edge Chapter 12",
        documentHeight: 12_000,
        viewportWidth: 390,
        images: [
            DetectionImageCandidate(
                src: "data:image/gif;base64,placeholder",
                lazySources: ["/cdn/chapter-12/001.jpg"],
                srcset: nil,
                width: 900,
                height: 1_400,
                top: 400,
                left: 0,
                className: "chapter-image",
                id: nil,
                alt: "page 1",
                parentSignature: "reader"
            )
        ]
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.candidates.first?.src == "https://example.com/cdn/chapter-12/001.jpg")
}

@Test func pageAnalysisScriptCollectsLazySrcsetAttributes() {
    #expect(PageAnalysisScript.javaScript.contains("data-srcset"))
    #expect(PageAnalysisScript.javaScript.contains("data-lazy-srcset"))
}

@Test func pageAnalysisScriptCollectsReaderSemanticHints() {
    #expect(PageAnalysisScript.javaScript.contains("data-reader-page-image"))
    #expect(PageAnalysisScript.javaScript.contains("semanticHints"))
}

@Test func pageAnalysisScriptCollectsChallengeSignals() {
    #expect(PageAnalysisScript.javaScript.contains("challengeSignals"))
    #expect(PageAnalysisScript.javaScript.contains("cf-mitigated"))
    #expect(PageAnalysisScript.javaScript.contains("too many requests"))
    #expect(PageAnalysisScript.javaScript.contains("rate limit"))
}

@Test func pageAnalysisScriptCollectsAdjacentChapterLinks() {
    #expect(PageAnalysisScript.javaScript.contains("previousChapterURL"))
    #expect(PageAnalysisScript.javaScript.contains("nextChapterURL"))
}

@Test func detectorClassifiesLongVerticalChapterAsHighConfidence() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Moonlit Edge Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: (1...8).map { index in
            DetectionImageCandidate(
                src: "https://img.examplecdn.com/moonlit/chapter-12/\(index).jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_350,
                top: Double(index * 1_360),
                left: 0,
                className: "reading-content",
                id: nil,
                alt: nil,
                parentSignature: "reader-main"
            )
        }
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 8)
}

@Test func detectedReaderSessionPreservesPageDimensions() throws {
    let detector = GenericChapterDetector()
    let page = DetectionPageAnalysis(
        pageURL: try #require(URL(string: "https://example.com/series/chapter-12")),
        title: "Chapter 12",
        documentHeight: 30_000,
        viewportWidth: 390,
        images: chapterImages(host: "img.example.com")
    )

    let result = detector.detect(page: page)
    let session = try #require(result.readerSession)

    #expect(session.pageMetadata.count == session.imageURLs.count)
    #expect(session.pageMetadata.first?.pixelWidth == 900)
    #expect(session.pageMetadata.first?.pixelHeight == 1350)
}

@Test func detectorKeepsThumbnailGridAtLowConfidence() throws {
    let pageURL = try #require(URL(string: "https://shop.example.com/products"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Products",
        documentHeight: 2_400,
        viewportWidth: 390,
        images: (1...20).map { index in
            DetectionImageCandidate(
                src: "https://shop.example.com/thumbs/\(index).jpg",
                lazySources: [],
                srcset: nil,
                width: 160,
                height: 160,
                top: Double((index / 2) * 180),
                left: index.isMultiple(of: 2) ? 0 : 180,
                className: "product thumbnail",
                id: nil,
                alt: "product thumbnail",
                parentSignature: "grid"
            )
        }
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
}

@Test func detectorClassifiesSparseButUsableChapterAsMediumConfidence() throws {
    let pageURL = try #require(URL(string: "https://example.com/read/moonlit-12"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Moonlit Edge 12",
        documentHeight: 7_000,
        viewportWidth: 390,
        images: (1...4).map { index in
            DetectionImageCandidate(
                src: "https://cdn.example.com/ch12/\(index).jpg",
                lazySources: [],
                srcset: nil,
                width: 320,
                height: 500,
                top: Double(index * 1_220),
                left: 0,
                className: "chapter-page",
                id: nil,
                alt: nil,
                parentSignature: "chapter-body"
            )
        }
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.confidence == .medium)
    #expect(result.readerEntryDisposition == .recommended)
    #expect(result.score == 70)
    #expect(result.readerSession?.imageURLs.count == 4)
}

@Test func genericDetectorExcludesLargeAdImagesOutsideReaderFlow() throws {
    let page = DetectionPageAnalysis(
        pageURL: try #require(URL(string: "https://example.com/series/chapter-12")),
        title: "Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: [
            DetectionImageCandidate(
                src: "https://ads.example.com/banner.jpg",
                lazySources: [],
                srcset: nil,
                width: 1_200,
                height: 1_600,
                top: 120,
                left: 0,
                className: "sidebar-ad hero-banner",
                id: nil,
                alt: nil,
                parentSignature: "sidebar ad-container"
            ),
            DetectionImageCandidate(
                src: "https://cdn.example.com/pages/001.jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_500,
                top: 2_000,
                left: 0,
                className: "chapter-page",
                id: nil,
                alt: nil,
                parentSignature: "reader pages"
            ),
            DetectionImageCandidate(
                src: "https://cdn.example.com/pages/002.jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_500,
                top: 3_600,
                left: 0,
                className: "chapter-page",
                id: nil,
                alt: nil,
                parentSignature: "reader pages"
            )
        ]
    )

    let candidates = GenericChapterDetector().normalizedCandidates(from: page)

    #expect(candidates.map(\.src) == [
        "https://cdn.example.com/pages/001.jpg",
        "https://cdn.example.com/pages/002.jpg"
    ])
}

@Test func detectorClassifiesReaderTaggedImagesBeforeDimensionsLoad() throws {
    let pageURL = try #require(URL(string: "https://reader.example.com/series/sample/chapter-32"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Sample Chapter 32",
        documentHeight: 2_400,
        viewportWidth: 390,
        images: (1...11).map { index in
            DetectionImageCandidate(
                src: "https://storage.example.com/upload/series/sample/32/\(String(format: "%02d", index)).webp",
                lazySources: [],
                srcset: nil,
                width: 0,
                height: 0,
                top: Double(index),
                left: 0,
                className: "h-auto w-full object-contain",
                id: nil,
                alt: "Sample Chapter 32 Page \(index)",
                parentSignature: nil,
                semanticHints: ["data-reader-page-image", "data-reader-index"]
            )
        }
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 11)
}

@Test func detectorKeepsChallengePagesOutOfReaderEvenWhenImagesLookUsable() throws {
    let pageURL = try #require(URL(string: "https://blocked.example.com/chapter-1"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Just a moment...",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "blocked.example.com"),
        challengeSignals: ["cf-mitigated:challenge"]
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
    #expect(result.diagnostics.messages.contains("challengePage=true"))
}

@Test func siteProfileRegistryMatchesDomainsAndSubdomains() throws {
    let registry = SiteProfileRegistry(
        profiles: [
            SiteProfile(
                domain: "example.com",
                supportTier: .enabledPublic,
                imageSelectorHints: ["reader"]
            )
        ]
    )

    let rootURL = try #require(URL(string: "https://example.com/chapter-12"))
    let subdomainURL = try #require(URL(string: "https://cdn.example.com/chapter-12"))

    #expect(registry.profile(for: rootURL)?.domain == "example.com")
    #expect(registry.profile(for: subdomainURL)?.domain == "example.com")
}

@Test func defaultSiteProfileRegistryIncludesInitialSupportTiers() throws {
    let registry = SiteProfileRegistry.default

    #expect(registry.profile(for: try #require(URL(string: "https://webtoons.com/en/action/sample/episode-1")))?.supportTier == .browserOnly)
    #expect(registry.profile(for: try #require(URL(string: "https://m.webtoons.com/en/action/sample/viewer")))?.compatibilityClass == .browserOnly)
    #expect(registry.profile(for: try #require(URL(string: "https://globalcomix.com/c/sample/chapters/en/1")))?.supportTier == .browserOnly)
    #expect(registry.profile(for: try #require(URL(string: "https://www.globalcomix.com/c/sample/chapters/en/1")))?.compatibilityClass == .browserOnly)
    #expect(registry.profile(for: try #require(URL(string: "https://asuracomic.net/series/sample/chapter-1")))?.supportTier == .approvedNonPromoted)
    #expect(registry.profile(for: try #require(URL(string: "https://asurascans.com/series/sample/chapter-1")))?.supportTier == .approvedNonPromoted)
    #expect(registry.profile(for: try #require(URL(string: "https://manhwatop.com/manga/sample/chapter-1")))?.supportTier == .approvedNonPromoted)
    #expect(registry.profile(for: try #require(URL(string: "https://manhuaus.com/manga/sample/chapter-1")))?.supportTier == .approvedNonPromoted)
}

@Test func defaultSiteProfileRegistryIncludesRepresentativeCompatibilityClasses() throws {
    let registry = SiteProfileRegistry.default

    #expect(registry.profile(for: try #require(URL(string: "https://asurascans.com/comics/sample/chapter/1")))?.compatibilityClass == .embeddedHTML)
    #expect(registry.profile(for: try #require(URL(string: "https://mangakatana.com/manga/sample/c1")))?.compatibilityClass == .hydratedDOM)
    #expect(registry.profile(for: try #require(URL(string: "https://mangafire.to/read/sample/en/chapter-1")))?.compatibilityClass == .browserSession)
    #expect(registry.profile(for: try #require(URL(string: "https://manhwatop.com/manga/sample/chapter-1")))?.compatibilityClass == .hydratedDOM)
    #expect(registry.profile(for: try #require(URL(string: "https://manhuaus.com/manga/sample/chapter-1")))?.compatibilityClass == .browserSession)
    #expect(registry.profile(for: try #require(URL(string: "https://mangapill.com/chapters/sample/chapter-1")))?.compatibilityClass == .hydratedDOM)
    #expect(registry.profile(for: try #require(URL(string: "https://www.mangahere.cc/manga/sample/c006/15.html")))?.compatibilityClass == .paginatedSinglePage)
}

@Test func relatedAsuraDomainsReuseEmbeddedHTMLTemplate() throws {
    let registry = SiteProfileRegistry.default
    let asuraComicURL = try #require(URL(string: "https://asuracomic.net/series/sample/chapter-1"))
    let asuraScansURL = try #require(URL(string: "https://asurascans.com/comics/sample/chapter/1"))
    let asuraComic = try #require(registry.profile(for: asuraComicURL))
    let asuraScans = try #require(registry.profile(for: asuraScansURL))

    #expect(asuraComic.template == asuraScans.template)
}

@Test func canonicalSeriesURLResolverHandlesAsuraComicChapterURLs() throws {
    let chapterURL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/97"))

    let seriesURL = CanonicalSeriesURLResolver.seriesURL(for: chapterURL)

    #expect(seriesURL.absoluteString == "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5")
}

@Test func siteProfilesExposeSelectorHintExtractionStrategy() throws {
    let profile = SiteProfile(
        domain: "reader.example.com",
        supportTier: .enabledPublic,
        extractionStrategy: .selectorHints(["main-reader"])
    )

    #expect(profile.imageSelectorHints == ["main-reader"])
    #expect(profile.extractionStrategy == .selectorHints(["main-reader"]))
}

@Test func approvedNonPromotedProfilesAreNotSearchSuggestionSources() {
    let registry = SiteProfileRegistry.default
    let promotedDomains = registry.promotedSuggestionDomains

    #expect(!promotedDomains.contains("webtoons.com"))
    #expect(!promotedDomains.contains("globalcomix.com"))
    #expect(!promotedDomains.contains("asuracomic.net"))
    #expect(!promotedDomains.contains("asurascans.com"))
    #expect(!promotedDomains.contains("manhwatop.com"))
}

@Test func protectedReaderImagesCannotProduceReaderPresentation() throws {
    for host in ["m.webtoons.com", "www.globalcomix.com"] {
        let page = DetectionPageAnalysis(
            pageURL: try #require(URL(string: "https://\(host)/sample/chapter-1/viewer")),
            title: "Sample Chapter 1",
            documentHeight: 20_000,
            viewportWidth: 390,
            images: chapterImages(host: "images.example.com")
        )

        let result = ProfileAwareChapterDetector().detect(page: page)

        #expect(result.confidence == .low)
        #expect(result.readerSession == nil)
        #expect(result.diagnostics.parserPath == .browserOnlyProfile)
    }
}

@Test func vortexRouteFixtureProducesOrderedReaderSession() throws {
    let page = try detectionFixture(named: "vortex_spa_chapter_169")
    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.sourceURL == page.pageURL)
    #expect(result.readerSession?.imageURLs.map(\.lastPathComponent) == [
        "001.jpg", "002.jpg", "003.jpg", "004.jpg", "005.jpg", "006.jpg", "007.jpg", "008.jpg"
    ])
}

@Test func comizyRedirectFixtureRetainsCanonicalURLAndOrderedImages() throws {
    let page = try detectionFixture(named: "comizy_redirected_chapter")
    let result = ProfileAwareChapterDetector().detect(page: page)
    let session = try #require(result.readerSession)

    #expect(session.sourceURL.host() == "comizy.io")
    #expect(session.seriesURL.absoluteString == "https://comizy.io/kono-manga-no-heroine-wa-morisaki-amane-desu/")
    #expect(session.imageURLs.count == 10)
    #expect(session.imageURLs.map(\.lastPathComponent) == (1...10).map { String(format: "%03d.jpg", $0) })
}

@Test func remediationSiteFixturesRemainSanitizedOrderedAndPolicyAccurate() throws {
    let readableFixtures = [
        "vortex_spa_chapter_169",
        "mangakatana_hydrated_dom",
        "mangapill_hydrated_dom",
        "comizy_redirected_chapter"
    ]

    for name in readableFixtures {
        let page = try detectionFixture(named: name)
        let result = ProfileAwareChapterDetector().detect(page: page)
        if name == "mangapill_hydrated_dom" {
            #expect(result.readerEntryDisposition == .unavailable)
            #expect(result.readerSession == nil)
            #expect(result.candidates.count == 5)
            continue
        }
        let session = try #require(result.readerSession)
        #expect(result.confidence == .high)
        #expect(session.imageURLs.count == page.images.count)
        #expect(session.imageURLs.allSatisfy { $0.host() == "images.example.test" })
        #expect(session.imageURLs == session.imageURLs.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        })
    }

    let challenge = try detectionFixture(named: "manhwatop_browser_only")
    let challengeResult = ProfileAwareChapterDetector().detect(page: challenge)
    #expect(challengeResult.confidence == .low)
    #expect(challengeResult.readerSession == nil)
    #expect(!challenge.challengeSignals.isEmpty)
}

@Test func embeddedHTMLProfileUsesSiteProfileDetectionPath() throws {
    let page = try detectionFixture(named: "asura_embedded_html")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 8)
    #expect(result.diagnostics.parserPath == .siteProfile)
    #expect(result.diagnostics.compatibilityClass == .embeddedHTML)
}

@Test func hydratedDOMProfileUsesSiteProfileDetectionPath() throws {
    let page = try detectionFixture(named: "mangakatana_hydrated_dom")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 8)
    #expect(result.diagnostics.parserPath == .siteProfile)
    #expect(result.diagnostics.compatibilityClass == .hydratedDOM)
}

@Test func secondHydratedDOMSiteReusesExistingTemplate() throws {
    let page = try detectionFixture(named: "mangapill_hydrated_dom")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerEntryDisposition == .unavailable)
    #expect(result.readerSession == nil)
    #expect(result.candidates.count == 5)
    #expect(result.diagnostics.parserPath == .siteProfile)
    #expect(result.diagnostics.compatibilityClass == .hydratedDOM)
}

@Test func browserSessionProfileSuppressesUnsafeGenericConversion() throws {
    let page = try detectionFixture(named: "mangafire_browser_session")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
    #expect(result.diagnostics.parserPath == .browserSessionProfile)
    #expect(result.diagnostics.compatibilityClass == .browserSession)
    #expect(result.retryRecommendation == .browserSessionFollowUp)
}

@Test func browserSessionFollowUpCanPromoteAfterHydration() throws {
    let page = try detectionFixture(named: "mangafire_browser_session")

    let result = ProfileAwareChapterDetector().detectBrowserSessionFollowUp(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 8)
    #expect(result.retryRecommendation == .none)
}

@Test func manhuaUSBrowserSessionFollowUpPromotesOnlyReaderImages() throws {
    let pageURL = try #require(URL(string: "https://manhuaus.com/manga/the-cold-blooded-warrior/chapter-54/"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "The Cold-Blooded Warrior - Chapter 54",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: [
            DetectionImageCandidate(
                src: "https://ads.example.com/tall-popup.jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_350,
                top: 80,
                left: 0,
                className: "popup-ad",
                id: "ad-modal",
                alt: "advertisement",
                parentSignature: "modal popup ad"
            )
        ] + (1...8).map { index in
            DetectionImageCandidate(
                src: "https://manhuaus.com/wp-content/uploads/the-cold-blooded-warrior/54/\(index).jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_350,
                top: Double(index * 1_360),
                left: 0,
                className: "wp-manga-chapter-img",
                id: nil,
                alt: "The Cold-Blooded Warrior Chapter 54 page \(index)",
                parentSignature: "reading-content manga-reading-content"
            )
        }
    )

    let initial = ProfileAwareChapterDetector().detect(page: page)
    let followUp = ProfileAwareChapterDetector().detectBrowserSessionFollowUp(page: page)

    #expect(initial.confidence == .low)
    #expect(initial.retryRecommendation == .browserSessionFollowUp)
    #expect(followUp.confidence == .high)
    #expect(followUp.readerSession?.imageURLs.count == 8)
    #expect(followUp.readerSession?.imageURLs.first?.absoluteString.contains("ads.example.com") == false)
}

@Test func browserSessionFollowUpWithoutViableCandidatesStaysLowConfidence() throws {
    var page = try detectionFixture(named: "mangafire_browser_session")
    page.images = []

    let result = ProfileAwareChapterDetector().detectBrowserSessionFollowUp(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
    #expect(result.retryRecommendation == .none)
}

@Test func challengePagesDoNotRecommendBrowserSessionRetry() throws {
    var page = try detectionFixture(named: "mangafire_browser_session")
    page.title = "Just a moment..."
    page.challengeSignals = ["cf-mitigated:challenge"]

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.retryRecommendation == .none)
}

@Test func profileAwareDetectorLogsStructuredDiagnostics() throws {
    let logger = SpyDetectionDiagnosticsLogger()
    let pageURL = try #require(URL(string: "https://unknown.example.com/series/chapter-12"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "unknown.example.com")
    )

    _ = ProfileAwareChapterDetector(
        registry: SiteProfileRegistry(profiles: []),
        diagnosticsLogger: logger
    ).detect(page: page)

    #expect(logger.loggedDiagnostics.count == 1)
    #expect(logger.loggedDiagnostics.first?.confidence == .high)
    #expect(logger.loggedDiagnostics.first?.parserPath == .genericHeuristic)
}

@Test func manhwaTopChallengePageSuppressesReaderConversion() throws {
    let page = try detectionFixture(named: "manhwatop_browser_only")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
    #expect(result.diagnostics.parserPath == .browserSessionProfile)
    #expect(result.diagnostics.compatibilityClass == .hydratedDOM)
}

@Test func manhwaTopProfileCanPromoteViableChapterIntoReader() throws {
    let page = DetectionPageAnalysis(
        pageURL: try #require(URL(string: "https://manhwatop.com/manga/past-life-returner/chapter-1/")),
        title: "Past Life Returner - Chapter 1",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: (1...6).map { index in
            DetectionImageCandidate(
                src: "https://cdn.manhwatop.com/past-life-returner/1/\(index).jpg",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_350,
                top: Double(index * 1_360),
                left: 0,
                className: "chapter-content",
                id: nil,
                alt: "page \(index)",
                parentSignature: "main-reader chapter-content"
            )
        }
    )

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 6)
    #expect(result.diagnostics.parserPath == .siteProfile)
}

@Test func manhwaTopProfileRejectsBlankPlaceholderImages() throws {
    let page = DetectionPageAnalysis(
        pageURL: try #require(URL(string: "https://manhwatop.com/manga/past-life-returner/chapter-1/")),
        title: "Past Life Returner - Chapter 1",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: [
            DetectionImageCandidate(
                src: "https://manhwatop.com/wp-content/uploads/blank.gif",
                lazySources: [],
                srcset: nil,
                width: 900,
                height: 1_350,
                top: 100,
                left: 0,
                className: "chapter-content",
                id: nil,
                alt: nil,
                parentSignature: "main-reader chapter-content"
            )
        ]
    )

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
}

@Test func paginatedSinglePageProfileReportsUnsupportedPaginatedDiagnostics() throws {
    let page = try detectionFixture(named: "mangahere_paginated_single_page")

    let result = ProfileAwareChapterDetector().detect(page: page)

    #expect(result.confidence == .low)
    #expect(result.readerSession == nil)
    #expect(result.retryRecommendation == .none)
    #expect(result.diagnostics.parserPath == .unsupportedPaginatedProfile)
    #expect(result.diagnostics.compatibilityClass == .paginatedSinglePage)
    #expect(result.diagnostics.hardBlocks.contains(.unsupportedPagination))
}

@Test func profileAwareDetectorUsesProfileSelectorHintsBeforeGenericFallback() throws {
    let pageURL = try #require(URL(string: "https://reader.example.com/series/chapter-12"))
    let registry = SiteProfileRegistry(
        profiles: [
            SiteProfile(
                domain: "reader.example.com",
                supportTier: .enabledPublic,
                imageSelectorHints: ["main-reader"]
            )
        ]
    )
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "reader.example.com") + [
            DetectionImageCandidate(
                src: "https://reader.example.com/sidebar/ad.jpg",
                lazySources: [],
                srcset: nil,
                width: 700,
                height: 900,
                top: 100,
                left: 260,
                className: "sidebar-promo",
                id: nil,
                alt: nil,
                parentSignature: "sidebar"
            )
        ]
    )

    let result = ProfileAwareChapterDetector(registry: registry).detect(page: page)

    #expect(result.confidence == .high)
    #expect(result.readerSession?.imageURLs.count == 8)
    #expect(result.diagnostics.parserPath == .siteProfile)
    #expect(result.diagnostics.profileDomain == "reader.example.com")
}

@Test func detectionDiagnosticsExposeConfidenceAndParserPath() throws {
    let pageURL = try #require(URL(string: "https://unknown.example.com/series/chapter-12"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "unknown.example.com")
    )

    let result = ProfileAwareChapterDetector(registry: SiteProfileRegistry(profiles: [])).detect(page: page)

    #expect(result.diagnostics.confidence == .high)
    #expect(result.diagnostics.parserPath == .genericHeuristic)
    #expect(result.diagnostics.score == result.score)
    #expect(result.diagnostics.messages.contains("confidence=high"))
}

@Test func detectedReaderSessionPreservesAdjacentChapterLinks() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let previousURL = try #require(URL(string: "https://example.com/series/chapter-11"))
    let nextURL = try #require(URL(string: "https://example.com/series/chapter-13"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "Chapter 12",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "example.com"),
        previousChapterURL: previousURL,
        nextChapterURL: nextURL
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.readerSession?.previousChapter?.sourceURL == previousURL)
    #expect(result.readerSession?.nextChapter?.sourceURL == nextURL)
    #expect(result.readerSession?.launchOrigin == .browser)
}

@Test func detectedReaderSessionInfersAdjacentChapterLinksFromNumericURLWhenLinksAreMissing() throws {
    let pageURL = try #require(URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241/chapter/3"))
    let page = DetectionPageAnalysis(
        pageURL: pageURL,
        title: "The Cold-Blooded Warrior Chapter 3",
        documentHeight: 18_000,
        viewportWidth: 390,
        images: chapterImages(host: "asurascans.com")
    )

    let result = GenericChapterDetector().detect(page: page)

    #expect(result.readerSession?.previousChapter?.sourceURL == URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241/chapter/2")!)
    #expect(result.readerSession?.nextChapter?.sourceURL == URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241/chapter/4")!)
}

@MainActor
@Test func browserAutoOpensReaderOnlyForHighConfidence() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let viewModel = BrowserViewModel(startPoint: .url(pageURL.absoluteString))
    let session = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))]
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .high,
            score: 100,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic)
        )
    )

    #expect(viewModel.pendingReaderSession == session)
    #expect(!viewModel.showsCleanModeCTA)
}

@MainActor
@Test func browserShowsCTAForMediumConfidenceAndManualOverridePresentsReader() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let viewModel = BrowserViewModel(startPoint: .url(pageURL.absoluteString))
    let session = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))]
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .medium,
            score: 60,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .medium, score: 60, parserPath: .genericHeuristic)
        )
    )

    #expect(viewModel.pendingReaderSession == nil)
    #expect(viewModel.showsCleanModeCTA)

    viewModel.enterCleanModeManually()

    #expect(viewModel.pendingReaderSession == session)
    #expect(!viewModel.showsCleanModeCTA)
}

@MainActor
@Test func browserLeavesLowConfidencePageInBrowser() throws {
    let pageURL = try #require(URL(string: "https://example.com/article"))
    let viewModel = BrowserViewModel(startPoint: .url(pageURL.absoluteString))

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .low,
            score: 10,
            candidates: [],
            readerSession: nil,
            diagnostics: .init(confidence: .low, score: 10, parserPath: .genericHeuristic)
        )
    )

    #expect(viewModel.pendingReaderSession == nil)
    #expect(!viewModel.showsCleanModeCTA)
}

private func chapterImages(host: String, parentSignature: String = "main-reader") -> [DetectionImageCandidate] {
    (1...8).map { index in
        DetectionImageCandidate(
            src: "https://\(host)/series/chapter-12/\(index).jpg",
            lazySources: [],
            srcset: nil,
            width: 900,
            height: 1_350,
            top: Double(index * 1_360),
            left: 0,
            className: "reading-content",
            id: nil,
            alt: nil,
            parentSignature: parentSignature
        )
    }
}

private func detectionFixture(named name: String) throws -> DetectionPageAnalysis {
    let fixtureURL = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)
    return try JSONDecoder().decode(DetectionPageAnalysis.self, from: data)
}

private final class SpyDetectionDiagnosticsLogger: DetectionDiagnosticsLogging, @unchecked Sendable {
    private(set) var loggedDiagnostics: [DetectionDiagnostics] = []

    func log(_ diagnostics: DetectionDiagnostics, pageURL: URL) {
        loggedDiagnostics.append(diagnostics)
    }
}
