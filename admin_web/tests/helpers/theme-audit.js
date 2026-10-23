async function auditTheme(page) {
  return page.evaluate(() => {
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = 1;
    const context = canvas.getContext('2d', { willReadFrequently: true });
    const colors = new Map();
    const layers = value => {
      const result = [];
      let depth = 0, start = 0;
      for (let i = 0; i < value.length; i++) {
        if (value[i] === '(') depth++;
        if (value[i] === ')') depth--;
        if (value[i] === ',' && depth === 0) { result.push(value.slice(start, i)); start = i + 1; }
      }
      result.push(value.slice(start));
      return result;
    };
    const rgba = color => {
      if (!colors.has(color)) {
        context.clearRect(0, 0, 1, 1);
        context.fillStyle = color;
        context.fillRect(0, 0, 1, 1);
        const channels = [...context.getImageData(0, 0, 1, 1).data];
        colors.set(color, [...channels.slice(0, 3), channels[3] / 255]);
      }
      return colors.get(color);
    };
    const blend = (front, back) => {
      const alpha = front[3] ?? 1;
      return front.slice(0, 3).map((channel, i) => channel * alpha + back[i] * (1 - alpha));
    };
    const luminance = rgb => rgb.slice(0, 3).map(channel => {
      channel /= 255;
      return channel <= .04045 ? channel / 12.92 : ((channel + .055) / 1.055) ** 2.4;
    }).reduce((sum, channel, i) => sum + channel * [.2126, .7152, .0722][i], 0);
    const describe = element => element.id ? `#${element.id}` : `${element.tagName.toLowerCase()}.${[...element.classList].join('.')}`;
    const contrast = [];
    const brightSurfaces = [];
    for (const element of document.body.querySelectorAll('*')) {
      if (!element.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true }) || element.closest('[aria-hidden="true"], .appearance-preview-frame')) continue;
      const style = getComputedStyle(element);
      const bounds = element.getBoundingClientRect();
      const ownBackground = rgba(style.backgroundColor);
      if (document.documentElement.dataset.theme === 'dark' && (ownBackground[3] ?? 1) > .8 && luminance(ownBackground) > .7 && bounds.width * bounds.height > 4000) {
        brightSurfaces.push(describe(element));
      }
      if (![...element.childNodes].some(node => node.nodeType === Node.TEXT_NODE && node.textContent.trim())) continue;
      const ancestors = [];
      let image = false;
      for (let parent = element; parent; parent = parent.parentElement) {
        const parentStyle = getComputedStyle(parent);
        if (parentStyle.backgroundImage.includes('url(')) image = true;
        const gradients = layers(parentStyle.backgroundImage).map(layer => [...layer.matchAll(/rgba?\([^)]*\)|color\(srgb[^)]*\)|oklab\([^)]*\)/g)].map(match => rgba(match[0]))).filter(stops => stops.length);
        const background = rgba(parentStyle.backgroundColor);
        ancestors.push({ background, gradients });
        if ((background[3] ?? 1) === 1 || gradients.some(stops => stops.every(stop => (stop[3] ?? 1) === 1))) break;
      }
      // Uploaded photographs are inspected visually; check every gradient stop.
      if (image) continue;
      const backgrounds = ancestors.reverse().reduce((backs, { background, gradients }) => {
        const bases = backs.map(back => blend(background, back));
        return gradients.reverse().reduce((under, stops) => under.flatMap(base => stops.map(stop => blend(stop, base))).slice(0, 32), bases);
      }, [[255, 255, 255]]);
      const ratios = backgrounds.map(background => {
        const foreground = blend(rgba(style.color), background);
        return (Math.max(luminance(foreground), luminance(background)) + .05) / (Math.min(luminance(foreground), luminance(background)) + .05);
      });
      const ratio = Math.min(...ratios);
      const background = backgrounds[ratios.indexOf(ratio)];
      const large = parseFloat(style.fontSize) >= 24 || (parseFloat(style.fontSize) >= 18.66 && parseFloat(style.fontWeight) >= 700);
      const minimum = large || element.classList.contains('material-symbols-rounded') ? 3 : 4.5;
      if (ratio + .05 < minimum) contrast.push({ element: describe(element), text: element.textContent.trim().slice(0, 55), ratio: +ratio.toFixed(2), color: style.color, background: background.map(Math.round) });
    }
    return { brightSurfaces, contrast, overflow: document.documentElement.scrollWidth > innerWidth };
  });
}

module.exports = { auditTheme };
