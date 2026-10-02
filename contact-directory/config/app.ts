/** General app settings. Change values here, not in components. */

const parsedStale = Number(process.env.NEXT_PUBLIC_STALE_DAYS);

/** A contact with no interaction for this many days is highlighted. */
export const STALE_DAYS = Number.isFinite(parsedStale) && parsedStale > 0 ? parsedStale : 60;

/** "Follow-ups due" shows overdue items and those due within this many days. */
export const FOLLOW_UP_WINDOW_DAYS = 14;

/** Import limits, to keep a bad file from overwhelming the app. */
export const IMPORT_MAX_BYTES = 5 * 1024 * 1024;
export const IMPORT_MAX_ROWS = 5000;
