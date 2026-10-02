import Foundation

public enum PageAnalysisScript {
    // Shared with Browser sanitation so recognized blocking evidence survives until analysis.
    static let accessGatePreservationJavaScript = """
    const toonEdgeBlockingGateSelector = '[role="dialog"], [aria-modal="true"], .reader-gate, .paywall, .auth-required, .error-page';
    const toonEdgePrimaryGateSelector = 'main, [role="main"], article';
    const toonEdgeGateSelector = toonEdgePrimaryGateSelector + ', ' + toonEdgeBlockingGateSelector;
    const toonEdgeProtectedReaderSelector = '[data-protected-reader="true"], .protected-reader, .reader-protected';
    const toonEdgeDRMSelector = '[data-drm-protected="true"], .drm-protected-reader';
    const toonEdgeAccessGateSelector = [toonEdgeGateSelector, toonEdgeProtectedReaderSelector, toonEdgeDRMSelector].join(', ');
    const toonEdgeAuthenticationPattern = /(?:sign in|log in|login) (?:to (?:read|view|continue|unlock)|is required)|authentication required/;
    const toonEdgePaywallPattern = /(?:subscribe|purchase|pay) to (?:read|view|continue|unlock)|subscription required|this chapter is locked/;
    const toonEdgeErrorPagePattern = /404 (?:page )?not found|403 forbidden|500 internal server error|502 bad gateway|503 service unavailable|page (?:not found|is unavailable)/;
    const toonEdgeHasChallengeCopy = (text) => text.includes('enable javascript and cookies to continue');
    const toonEdgeHasRateLimitCopy = (text) => text.includes('too many requests') || text.includes('rate limit') || text.includes('http 429');
    const toonEdgeIsVisible = (element) => {
      if (!element || element.hidden) return false;
      const rect = element.getBoundingClientRect();
      const style = window.getComputedStyle(element);
      return rect.width > 0 && rect.height > 0 && style.display !== 'none'
        && style.visibility !== 'hidden' && style.opacity !== '0';
    };
    const toonEdgeHasAccessGateEvidence = (element) => {
      if (!toonEdgeIsVisible(element)) return false;
      if (element.matches([toonEdgeProtectedReaderSelector, toonEdgeDRMSelector].join(', '))) return true;
      const text = (element.innerText || '').toLowerCase();
      // Legacy challenge evidence uses visible body copy; other copy remains gate-scoped.
      if (toonEdgeHasChallengeCopy(text) || toonEdgeHasRateLimitCopy(text)) return true;
      if (!(toonEdgeAuthenticationPattern.test(text) || toonEdgePaywallPattern.test(text)
        || toonEdgeErrorPagePattern.test(text))) return false;
      // A copy node inherits an existing visible gate context even without its own metadata.
      for (let surface = element; surface; surface = surface.parentElement) {
        if (surface.matches(toonEdgeGateSelector) && toonEdgeIsVisible(surface)) return true;
      }
      return false;
    };
    const toonEdgeCanPreserveGateSubtree = (element) =>
      !element.matches('html, body, ' + toonEdgePrimaryGateSelector) && toonEdgeHasAccessGateEvidence(element);
    """

    public static let javaScript = """
    (() => {
      \(accessGatePreservationJavaScript)
      const lazyAttributes = [
        'data-src',
        'data-original',
        'data-lazy-src',
        'data-lazy',
        'data-url',
        'data-image',
        'data-full',
        'data-full-src',
        'data-actualsrc'
      ];

      const images = Array.from(document.images).map((image) => {
        const rect = image.getBoundingClientRect();
        const lazySources = lazyAttributes
          .map((attribute) => image.getAttribute(attribute))
          .filter((value) => value && value.trim().length > 0);
        const parent = image.parentElement;
        const semanticHints = [
          image.hasAttribute('data-reader-page-image') ? 'data-reader-page-image' : null,
          image.hasAttribute('data-reader-index') ? 'data-reader-index' : null,
          image.hasAttribute('data-page') ? 'data-page' : null,
          image.getAttribute('role') ? `role:${image.getAttribute('role')}` : null
        ].filter(Boolean);

        return {
          src: image.currentSrc || image.getAttribute('src') || null,
          lazySources,
          srcset: image.getAttribute('srcset') || image.getAttribute('data-srcset') || image.getAttribute('data-lazy-srcset'),
          width: Math.max(rect.width || 0, image.naturalWidth || 0),
          height: Math.max(rect.height || 0, image.naturalHeight || 0),
          top: rect.top + window.scrollY,
          left: rect.left + window.scrollX,
          className: image.className || null,
          id: image.id || null,
          alt: image.alt || null,
          parentSignature: parent ? [parent.id, parent.className, parent.tagName].filter(Boolean).join(' ') : null,
          semanticHints
        };
      });

      const bodyText = document.body ? document.body.innerText.toLowerCase() : '';
      const chapterLink = (direction) => {
        const relLink = document.querySelector(`a[rel="${direction}"]`);
        if (relLink && relLink.href) return relLink.href;

        const labels = direction === 'prev'
          ? ['previous', 'prev', '‹', '«']
          : ['next', '›', '»'];

        const anchor = Array.from(document.querySelectorAll('a[href]')).find((link) => {
          const text = (link.innerText || link.getAttribute('aria-label') || link.title || '').trim().toLowerCase();
          return labels.some((label) => text === label || text.includes(`${label} chapter`));
        });
        return anchor ? anchor.href : null;
      };
      const challengeSignals = [
        document.title.toLowerCase().includes('just a moment') ? 'title:just-a-moment' : null,
        document.querySelector('meta[http-equiv="refresh"]') ? 'meta-refresh' : null,
        document.querySelector('script[src*="challenge-platform"]') ? 'challenge-platform-script' : null,
        toonEdgeHasChallengeCopy(bodyText) ? 'challenge-copy' : null,
        toonEdgeHasRateLimitCopy(bodyText) ? 'rate-limit-copy' : null,
        document.documentElement.innerHTML.includes('cf-mitigated') ? 'cf-mitigated' : null
      ].filter(Boolean);

      // Gate evidence belongs to visible primary content or an explicit blocking surface.
      // Navigation links, cookie notices, ad iframes and small decorative canvases are not gates.
      const isVisible = toonEdgeIsVisible;
      const gateSurfaces = Array.from(document.querySelectorAll(toonEdgeGateSelector)).filter(isVisible);
      const gateText = gateSurfaces.map((element) => (element.innerText || '').toLowerCase()).join(' ');
      const hardBlocks = [];
      if (challengeSignals.length > 0) hardBlocks.push('challenge');
      if (toonEdgeAuthenticationPattern.test(gateText)) {
        hardBlocks.push('authentication');
      }
      if (toonEdgePaywallPattern.test(gateText)) {
        hardBlocks.push('paywall');
      }
      if (toonEdgeErrorPagePattern.test(gateText)
          || /^(?:404|403|500|502|503)(?: |$)|^page not found$/i.test(document.title.trim())) {
        hardBlocks.push('errorPage');
      }
      const visibleMarker = (selectors) => Array.from(document.querySelectorAll(selectors)).some(isVisible);
      if (visibleMarker(toonEdgeProtectedReaderSelector)) {
        hardBlocks.push('protectedViewer');
      }
      if (visibleMarker(toonEdgeDRMSelector)) hardBlocks.push('drm');
      const isContentSized = (element) => {
        const rect = element.getBoundingClientRect();
        return isVisible(element) && rect.width >= (window.innerWidth || 390) * 0.6
          && rect.height >= (window.innerHeight || 844) * 0.5;
      };
      const hasNetworkImage = (scope) => Array.from(scope.querySelectorAll('img')).some((image) => {
        const rect = image.getBoundingClientRect();
        const srcset = image.getAttribute('srcset') || image.getAttribute('data-srcset') || image.getAttribute('data-lazy-srcset');
        // Opaque data payload commas must not become relative network URL fragments.
        const srcsetSources = srcset && !/^data:/i.test(srcset.trim())
          ? srcset.split(',').map((entry) => entry.trim().split(/\\s+/)[0]) : [];
        const sources = lazyAttributes.map((attribute) => image.getAttribute(attribute))
          .concat(srcsetSources, [image.currentSrc || image.getAttribute('src')]);
        const source = sources.map((value) => value && value.trim()).find((value) => value
          && !/^(?:blob:|data:)/i.test(value) && !/placeholder|blank.gif|spacer.gif/i.test(value));
        const parent = image.parentElement;
        const hintText = [image.alt, image.className, parent ? [parent.id, parent.className, parent.tagName].join(' ') : ''].join(' ');
        const hasReaderHint = image.hasAttribute('data-reader-page-image')
          && (image.hasAttribute('data-reader-index') || /chapter|page|reader/i.test(hintText));
        const hasUsableDimensions = Math.max(rect.width, image.naturalWidth || 0) >= 320
          && Math.max(rect.height, image.naturalHeight || 0) >= 500;
        if (!(hasReaderHint || hasUsableDimensions) || !source) return false;
        try {
          return ['http:', 'https:'].includes(new URL(source, window.location.href).protocol);
        } catch (_) {
          return false;
        }
      });
      const hasOpaqueViewer = gateSurfaces.some((scope) => !hasNetworkImage(scope)
        && Array.from(scope.querySelectorAll('canvas, img[src^="blob:"]')).some(isContentSized));
      if (hasOpaqueViewer) hardBlocks.push('canvasOrBlob');

      return JSON.stringify({
        pageURL: window.location.href,
        title: document.title || '',
        documentHeight: Math.max(
          document.body ? document.body.scrollHeight : 0,
          document.documentElement ? document.documentElement.scrollHeight : 0
        ),
        viewportWidth: window.innerWidth || 0,
        viewportHeight: window.innerHeight || 0,
        images,
        previousChapterURL: chapterLink('prev'),
        nextChapterURL: chapterLink('next'),
        challengeSignals,
        hardBlocks
      });
    })();
    """
}
