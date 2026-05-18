/**
 * Utility helper functions for managing Indian Standard Time (IST) timezone conversions.
 */

/**
 * Returns a new Date object shifted to the Indian Standard Time (IST) offset (+5:30).
 */
export function getISTDate(baseDate: Date = new Date()): Date {
  const utc = baseDate.getTime() + baseDate.getTimezoneOffset() * 60 * 1000;
  const istOffset = 5.5 * 60 * 60 * 1000; // +5:30 in milliseconds
  return new Date(utc + istOffset);
}

/**
 * Returns current date formatted as YYYY-MM-DD in IST.
 */
export function getISTDateString(baseDate: Date = new Date()): string {
  const istDate = getISTDate(baseDate);
  const year = istDate.getFullYear();
  const month = String(istDate.getMonth() + 1).padStart(2, '0');
  const day = String(istDate.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Returns an ISO timestamp string representing the current moment formatted in IST (+05:30).
 */
export function getISTDateTimeString(baseDate: Date = new Date()): string {
  const istDate = getISTDate(baseDate);
  const year = istDate.getFullYear();
  const month = String(istDate.getMonth() + 1).padStart(2, '0');
  const day = String(istDate.getDate()).padStart(2, '0');
  const hours = String(istDate.getHours()).padStart(2, '0');
  const minutes = String(istDate.getMinutes()).padStart(2, '0');
  const seconds = String(istDate.getSeconds()).padStart(2, '0');
  const milliseconds = String(istDate.getMilliseconds()).padStart(3, '0');
  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}.${milliseconds}+05:30`;
}
