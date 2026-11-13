const fs = require('fs');
const path = require('path');

function formatPhotoUrl(req, rawUrl) {
  if (!rawUrl) return null;
  const str = String(rawUrl).trim();
  if (!str || str === 'null' || str === 'undefined' || str === '0' || str === 'false') return null;

  // If already absolute URL (http:// or https://)
  if (str.startsWith('http://') || str.startsWith('https://')) {
    try {
      const urlObj = new URL(str);
      const pathname = urlObj.pathname.replace(/^\/+/, '');
      if (pathname.startsWith('uploads/')) {
        const localFilePath = path.join(__dirname, '..', pathname);
        if (!fs.existsSync(localFilePath)) {
          return null;
        }
      }
    } catch (_) {}
    return str;
  }

  // Clean relative path (remove leading slashes or duplicate server prefix)
  let cleanPath = str.replace(/^\/+/, '');
  if (cleanPath.startsWith('gold_pawn_erp/backend/')) {
    cleanPath = cleanPath.substring('gold_pawn_erp/backend/'.length);
  } else if (cleanPath.startsWith('backend/')) {
    cleanPath = cleanPath.substring('backend/'.length);
  }

  cleanPath = cleanPath.replace(/^\/+/, '');

  if (!cleanPath.startsWith('uploads/')) {
    cleanPath = 'uploads/' + cleanPath;
  }

  // Check if file exists on disk
  try {
    const fullPath = path.join(__dirname, '..', cleanPath);
    if (!fs.existsSync(fullPath)) {
      return null;
    }
  } catch (_) {}

  return cleanPath;
}

module.exports = {
  formatPhotoUrl
};
