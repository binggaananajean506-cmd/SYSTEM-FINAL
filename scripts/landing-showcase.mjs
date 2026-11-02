import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const escape = value => String(value).replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);

export function loadLandingShowcase(root) {
  const images = JSON.parse(readFileSync(resolve(root, 'landing_web/showcase.json'), 'utf8'));
  if (images.length !== 11 || new Set(images.map(image => image.file)).size !== 11 || images.some(image => !/^[a-z-]+\.jpg$/.test(image.file) || !existsSync(resolve(root, 'landing_web/assets/screenshots', image.file)))) {
    throw new Error('Use only the 11 distinct screenshots supplied by the user.');
  }
  const html = '<div class="showcase-gallery" data-showcase-gallery>' +
    '<div class="gallery-heading"><p>Swipe through the app. Select a screen for a closer look.</p><div class="showcase-controls" hidden><button type="button" data-showcase-direction="-1" aria-label="Previous app screenshots" aria-controls="app-screenshots"><svg class="icon"><use href="#arrow"/></svg></button><button type="button" data-showcase-direction="1" aria-label="Next app screenshots" aria-controls="app-screenshots"><svg class="icon"><use href="#arrow"/></svg></button></div></div>' +
    '<div class="showcase-rail" id="app-screenshots" tabindex="0" role="region" aria-label="E-SUGID app screenshots">' +
    images.map((image, index) => '<figure class="showcase-sheet" id="preview-' + image.id + '">' +
      '<a class="showcase-image-link device-frame" href="/landing-assets/screenshots/' + image.file + '" target="_blank" rel="noopener" data-preview-link data-preview-title="' + escape(image.title) + '" data-preview-description="' + escape(image.description) + '" aria-label="Enlarge: ' + escape(image.title) + '"><span class="device-screen"><img src="/landing-assets/screenshots/' + image.file + '" width="' + image.width + '" height="' + image.height + '" loading="lazy" decoding="async" alt="' + escape(image.title) + ' — E-SUGID app screenshot"></span></a>' +
      '<figcaption><span class="snapshot-number">' + String(index + 1).padStart(2, '0') + ' / INSIDE THE APP</span><h3>' + escape(image.title) + '</h3><p>' + escape(image.description) + '</p></figcaption></figure>').join('\n') +
    '</div></div>';
  return { html, images, assets: images };
}
