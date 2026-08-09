export const contentTabs = Object.freeze(["clipboard", "agent"]);

export function isContentTab(value) {
  return contentTabs.includes(value);
}

export function parseContentTabLaunch(urlLike, expectedOrigin) {
  try {
    const url = new URL(urlLike, expectedOrigin);
    const origin = new URL(expectedOrigin).origin;
    if (url.origin !== origin) return null;
    const tab = url.searchParams.get("tab");
    if (!isContentTab(tab)) return null;
    url.searchParams.delete("tab");
    return {
      tab,
      cleanPath: `${url.pathname}${url.search}${url.hash}`,
    };
  } catch {
    return null;
  }
}

export function contentTabAtScrollPosition(scrollLeft, pageWidth) {
  if (!Number.isFinite(pageWidth) || pageWidth <= 0) return contentTabs[0];
  const index = Math.max(
    0,
    Math.min(contentTabs.length - 1, Math.round(scrollLeft / pageWidth)),
  );
  return contentTabs[index];
}

export function contentScrollIsSnapped(scrollLeft, pageWidth, tolerance = 2) {
  if (!Number.isFinite(pageWidth) || pageWidth <= 0) return true;
  const nearestSnap = Math.round(scrollLeft / pageWidth) * pageWidth;
  return Math.abs(scrollLeft - nearestSnap) <= tolerance;
}

export function adjacentContentTab(tab, direction) {
  const currentIndex = contentTabs.indexOf(tab);
  if (currentIndex < 0) return contentTabs[0];
  const nextIndex = Math.max(
    0,
    Math.min(contentTabs.length - 1, currentIndex + direction),
  );
  return contentTabs[nextIndex];
}
