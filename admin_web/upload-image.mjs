// Optimize public announcement covers, never verification/proof documents.
export async function prepareAnnouncementImage(file) {
  if (file.size < 384 * 1024 || !['image/jpeg', 'image/png', 'image/webp'].includes(file.type)
      || typeof createImageBitmap !== 'function') return file;
  let bitmap;
  try {
    bitmap = await createImageBitmap(file);
    const scale = Math.min(1, 2048 / Math.max(bitmap.width, bitmap.height));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(bitmap.width * scale));
    canvas.height = Math.max(1, Math.round(bitmap.height * scale));
    const context = canvas.getContext('2d');
    if (!context) return file;
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/webp', .88));
    if (!blob || blob.type !== 'image/webp' || blob.size >= file.size * .9) return file;
    return new File([blob], file.name.replace(/\.[^.]+$/, '') + '.webp', { type: blob.type, lastModified: file.lastModified });
  } catch { return file; }
  finally { bitmap?.close(); }
}
