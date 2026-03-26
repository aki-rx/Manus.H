/*
 * Model Parameter Fader + Provider Color Tagger
 * ===============================================
 * 1. Finds model names containing ⸨...⸩ markers and wraps the param
 *    portion in <span class="model-param"> for CSS fading.
 * 2. Detects model provider from the model ID / name and applies a
 *    data-provider attribute so CSS can color-code the background.
 *
 * Provider detection keywords:
 *   - "gpt" / "chatgpt" / "openai" / "o1" / "o3" / "o4"  -> openai
 *   - "claude" / "anthropic"                                -> anthropic
 *   - "gemini" / "google" / "palm"                          -> google
 *   - everything else                                       -> other
 */
(function () {
  'use strict';

  const MARKER_START = '\u2E28'; // ⸨
  const MARKER_END   = '\u2E29'; // ⸩
  const PROCESSED_ATTR = 'data-param-faded';
  const PROVIDER_ATTR  = 'data-provider';

  // ---------------------------------------------------------------
  // Provider detection
  // ---------------------------------------------------------------
  const PROVIDER_RULES = [
    { provider: 'openai',    patterns: [/\bgpt\b/i, /\bchatgpt\b/i, /\bopenai\b/i, /\bo1\b/i, /\bo3\b/i, /\bo4\b/i] },
    { provider: 'anthropic', patterns: [/\bclaude\b/i, /\banthropic\b/i] },
    { provider: 'google',    patterns: [/\bgemini\b/i, /\bgoogle\b/i, /\bpalm\b/i] },
  ];

  function detectProvider(text) {
    const lower = text.toLowerCase();
    for (const rule of PROVIDER_RULES) {
      for (const re of rule.patterns) {
        if (re.test(lower)) return rule.provider;
      }
    }
    return 'other';
  }

  // ---------------------------------------------------------------
  // Faded parameter processing
  // ---------------------------------------------------------------
  function processTextNode(node) {
    const text = node.textContent;
    if (!text || !text.includes(MARKER_START)) return;

    const regex = new RegExp(
      `\\${MARKER_START}([^\\${MARKER_END}]+)\\${MARKER_END}`, 'g'
    );
    if (!regex.test(text)) return;
    regex.lastIndex = 0;

    const parent = node.parentElement;
    if (!parent || parent.getAttribute(PROCESSED_ATTR)) return;

    const fragment = document.createDocumentFragment();
    let lastIndex = 0;
    let match;

    while ((match = regex.exec(text)) !== null) {
      if (match.index > lastIndex) {
        fragment.appendChild(
          document.createTextNode(text.slice(lastIndex, match.index))
        );
      }
      const span = document.createElement('span');
      span.className = 'model-param';
      span.textContent = match[1];
      fragment.appendChild(span);
      lastIndex = regex.lastIndex;
    }

    if (lastIndex < text.length) {
      fragment.appendChild(document.createTextNode(text.slice(lastIndex)));
    }

    parent.setAttribute(PROCESSED_ATTR, 'true');
    parent.replaceChild(fragment, node);
  }

  function scanTextNodes(root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null, false);
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    nodes.forEach(processTextNode);
  }

  // ---------------------------------------------------------------
  // Provider color tagging
  // ---------------------------------------------------------------
  // We look for elements that represent a model entry in dropdowns,
  // selectors, sidebar, etc. Open WebUI uses [role="option"] in the
  // model selector and various button/div patterns elsewhere.

  const MODEL_SELECTORS = [
    '[role="option"]',                       // model dropdown options
    '[data-model-id]',                       // any element with model id
    'button[class*="model"]',                // model buttons
    '.model-item',                           // custom class if present
  ].join(', ');

  function tagProviderColors(root) {
    const els = root.querySelectorAll
      ? root.querySelectorAll(MODEL_SELECTORS)
      : [];

    els.forEach((el) => {
      if (el.getAttribute(PROVIDER_ATTR)) return; // already tagged

      // Gather text from the element and any data attributes
      const text = (el.textContent || '') +
                   (el.getAttribute('data-model-id') || '') +
                   (el.getAttribute('data-value') || '') +
                   (el.getAttribute('title') || '');

      const provider = detectProvider(text);
      el.setAttribute(PROVIDER_ATTR, provider);
    });
  }

  // Also tag the currently selected model display in the chat header
  function tagSelectedModel() {
    // The model name in the chat header / selector button
    const candidates = document.querySelectorAll(
      '#model-selector, [class*="model-select"], [aria-haspopup="listbox"]'
    );
    candidates.forEach((el) => {
      const text = el.textContent || '';
      if (text.length > 0 && text.length < 200) {
        const provider = detectProvider(text);
        el.setAttribute(PROVIDER_ATTR, provider);
      }
    });
  }

  // ---------------------------------------------------------------
  // Run
  // ---------------------------------------------------------------
  function fullScan() {
    scanTextNodes(document.body);
    tagProviderColors(document.body);
    tagSelectedModel();
  }

  // Initial scan
  fullScan();

  // Observe DOM changes
  const observer = new MutationObserver((mutations) => {
    let needsScan = false;
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE) {
          scanTextNodes(node);
          tagProviderColors(node);
          needsScan = true;
        } else if (node.nodeType === Node.TEXT_NODE) {
          processTextNode(node);
        }
      }
    }
    if (needsScan) tagSelectedModel();
  });

  observer.observe(document.body, { childList: true, subtree: true });

  // Periodic re-scan for dynamically rendered content
  setInterval(fullScan, 2000);
})();
