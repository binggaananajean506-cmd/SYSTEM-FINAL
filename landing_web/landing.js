const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const themeToggle = document.querySelector('.landing-theme-toggle');
if (themeToggle) {
  const systemTheme = window.matchMedia('(prefers-color-scheme: dark)');
  const syncTheme = dark => {
    document.documentElement.dataset.landingTheme = dark ? 'dark' : 'light';
    themeToggle.setAttribute('aria-pressed', String(dark));
    themeToggle.setAttribute('aria-label', `Switch to ${dark ? 'light' : 'dark'} mode`);
    themeToggle.title = dark ? 'Switch to light mode' : 'Switch to dark mode';
    document.querySelector('meta[name="theme-color"]').content = dark ? '#101f1b' : '#124c3d';
  };
  let chosenTheme;
  try { chosenTheme = localStorage.getItem('esugid-landing-theme'); } catch {}
  syncTheme(document.documentElement.dataset.landingTheme === 'dark');
  themeToggle.hidden = false;
  // Transitions start only after the restored theme is painted.
  requestAnimationFrame(() => requestAnimationFrame(() => document.documentElement.classList.add('landing-theme-ready')));
  themeToggle.addEventListener('click', () => {
    chosenTheme = document.documentElement.dataset.landingTheme === 'dark' ? 'light' : 'dark';
    syncTheme(chosenTheme === 'dark');
    try { localStorage.setItem('esugid-landing-theme', chosenTheme); } catch {}
  });
  systemTheme.addEventListener('change', event => {
    if (chosenTheme !== 'light' && chosenTheme !== 'dark') syncTheme(event.matches);
  });
}
if (!reducedMotion.matches && 'IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) if (entry.isIntersecting) {
      entry.target.classList.add('is-visible');
      observer.unobserve(entry.target);
    }
  }, { threshold: 0.08 });
  document.querySelectorAll('.reveal').forEach(element => observer.observe(element));
  document.body.classList.add('motion-ready');
}
document.querySelectorAll('[data-showcase-gallery]').forEach(gallery => {
  const showcase = gallery.querySelector('.showcase-rail');
  const showcaseControls = gallery.querySelector('.showcase-controls');
  const previous = showcaseControls.querySelector('[data-showcase-direction="-1"]');
  const next = showcaseControls.querySelector('[data-showcase-direction="1"]');
  const updateShowcaseControls = () => {
    previous.disabled = showcase.scrollLeft <= 1;
    next.disabled = showcase.scrollLeft >= showcase.scrollWidth - showcase.clientWidth - 2;
  };
  showcaseControls.hidden = false;
  showcaseControls.addEventListener('click', event => {
    const button = event.target.closest('button[data-showcase-direction]');
    if (!button) return;
    const left = showcase.scrollLeft;
    const inset = parseFloat(getComputedStyle(showcase).paddingLeft);
    const offsets = [...showcase.querySelectorAll('figure')].map(figure => Math.max(0, figure.getBoundingClientRect().left - showcase.getBoundingClientRect().left + left - inset));
    const target = Number(button.dataset.showcaseDirection) > 0 ? offsets.find(offset => offset > left + 2) ?? showcase.scrollWidth : offsets.reverse().find(offset => offset < left - 2) ?? 0;
    showcase.scrollTo({ left: target, behavior: reducedMotion.matches ? 'instant' : 'smooth' });
  });
  showcase.addEventListener('scroll', updateShowcaseControls, { passive: true });
  window.addEventListener('resize', updateShowcaseControls);
  updateShowcaseControls();
});

const previewDialog = document.querySelector('#screenshot-preview');
if (previewDialog && typeof previewDialog.showModal === 'function') {
  const links = [...document.querySelectorAll('[data-preview-link]')];
  const image = previewDialog.querySelector('img');
  const canvas = previewDialog.querySelector('.preview-canvas');
  const zoom = previewDialog.querySelector('[data-preview-zoom]');
  const previous = previewDialog.querySelector('[data-preview-previous]');
  const next = previewDialog.querySelector('[data-preview-next]');
  let current = 0;
  let opener;
  const resetZoom = () => {
    canvas.classList.remove('is-zoomed');
    zoom.textContent = 'Zoom in';
    zoom.setAttribute('aria-pressed', 'false');
    canvas.scrollTo(0, 0);
  };
  const showPreview = index => {
    current = index;
    resetZoom();
    image.src = links[current].href;
    image.alt = links[current].querySelector('img')?.alt || links[current].dataset.previewTitle;
    previewDialog.querySelector('#preview-title').textContent = links[current].dataset.previewTitle;
    previewDialog.querySelector('.preview-description').textContent = links[current].dataset.previewDescription;
    previewDialog.querySelector('[data-preview-position]').textContent = `${current + 1} of ${links.length}`;
    previous.disabled = current === 0;
    next.disabled = current === links.length - 1;
  };
  links.forEach((link, index) => link.addEventListener('click', event => {
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    opener = link;
    showPreview(index);
    previewDialog.showModal();
  }));
  previewDialog.querySelector('[data-preview-close]').addEventListener('click', () => previewDialog.close());
  previewDialog.addEventListener('close', () => { resetZoom(); opener?.focus({ preventScroll: true }); });
  previous.addEventListener('click', () => { if (current > 0) showPreview(current - 1); });
  next.addEventListener('click', () => { if (current < links.length - 1) showPreview(current + 1); });
  zoom.addEventListener('click', () => {
    const zoomed = canvas.classList.toggle('is-zoomed');
    zoom.textContent = zoomed ? 'Fit to screen' : 'Zoom in';
    zoom.setAttribute('aria-pressed', String(zoomed));
  });
}

document.querySelector('#current-year').textContent = String(new Date().getFullYear());
fetch('/release.json').then(response => {
  if (!response.ok) throw new Error('Release metadata unavailable');
  return response.json();
}).then(release => {
  if (typeof release.version === 'string' && /^[\d.]+$/.test(release.version)) {
    document.querySelectorAll('[data-release-version]').forEach(element => { element.textContent = `v${release.version}`; });
  }
  if (Number.isFinite(release.bytes) && release.bytes > 0) {
    const size = `${(release.bytes / 1024 / 1024).toFixed(1)} MB`;
    document.querySelectorAll('[data-release-size]').forEach(element => { element.textContent = size; });
  }
}).catch(() => { /* The static download and installation instructions remain available. */ });
document.querySelectorAll('a[download]').forEach(link => {
  link.addEventListener('click', () => {
    fetch(link.href, { method: 'HEAD' }).then(response => {
      if (!response.ok) throw new Error('Download unavailable');
      document.querySelector('#download-status').hidden = true;
    }).catch(() => { document.querySelector('#download-status').hidden = false; });
  });
});
