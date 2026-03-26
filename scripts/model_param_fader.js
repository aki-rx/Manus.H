/*
 * Model Parameter Fader
 * =====================
 * This script runs as a MutationObserver in Open WebUI to find model names
 * containing Unicode markers ⸨...⸩ and wraps the parameter portion in
 * <span class="model-param"> for CSS fading.
 *
 * Inject this via a custom <script> tag in the Dockerfile or
 * paste into Admin Panel > Settings > Interface > Custom Script.
 */
(function () {
  'use strict';

  const MARKER_START = '\u2E28'; // ⸨
  const MARKER_END = '\u2E29';   // ⸩
  const PROCESSED_ATTR = 'data-param-faded';

  function processTextNode(node) {
    const text = node.textContent;
    if (!text || !text.includes(MARKER_START)) return;

    const regex = new RegExp(
      `${MARKER_START}([^${MARKER_END}]+)${MARKER_END}`,
      'g'
    );

    if (!regex.test(text)) return;
    regex.lastIndex = 0;

    // Check if parent already processed
    const parent = node.parentElement;
    if (!parent || parent.getAttribute(PROCESSED_ATTR)) return;

    const fragment = document.createDocumentFragment();
    let lastIndex = 0;
    let match;

    while ((match = regex.exec(text)) !== null) {
      // Text before the match
      if (match.index > lastIndex) {
        fragment.appendChild(
          document.createTextNode(text.slice(lastIndex, match.index))
        );
      }

      // The faded parameter span
      const span = document.createElement('span');
      span.className = 'model-param';
      span.textContent = match[1]; // Just the param text, no brackets
      fragment.appendChild(span);

      lastIndex = regex.lastIndex;
    }

    // Remaining text
    if (lastIndex < text.length) {
      fragment.appendChild(document.createTextNode(text.slice(lastIndex)));
    }

    parent.setAttribute(PROCESSED_ATTR, 'true');
    parent.replaceChild(fragment, node);
  }

  function scanNode(root) {
    const walker = document.createTreeWalker(
      root,
      NodeFilter.SHOW_TEXT,
      null,
      false
    );
    const nodes = [];
    while (walker.nextNode()) {
      nodes.push(walker.currentNode);
    }
    nodes.forEach(processTextNode);
  }

  // Initial scan
  scanNode(document.body);

  // Observe DOM changes for dynamically loaded model names
  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE) {
          scanNode(node);
        } else if (node.nodeType === Node.TEXT_NODE) {
          processTextNode(node);
        }
      }
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
  });
})();
