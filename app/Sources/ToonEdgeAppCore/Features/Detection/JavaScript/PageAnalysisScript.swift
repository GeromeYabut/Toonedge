import Foundation

public enum PageAnalysisScript {
    public static let javaScript = """
    (() => {
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
        bodyText.includes('enable javascript and cookies to continue') ? 'challenge-copy' : null,
        document.documentElement.innerHTML.includes('cf-mitigated') ? 'cf-mitigated' : null
      ].filter(Boolean);

      return JSON.stringify({
        pageURL: window.location.href,
        title: document.title || '',
        documentHeight: Math.max(
          document.body ? document.body.scrollHeight : 0,
          document.documentElement ? document.documentElement.scrollHeight : 0
        ),
        viewportWidth: window.innerWidth || 0,
        images,
        previousChapterURL: chapterLink('prev'),
        nextChapterURL: chapterLink('next'),
        challengeSignals
      });
    })();
    """
}
