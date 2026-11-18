export type ThemeMode = 'light' | 'dark' | 'system';
export type ResolvedTheme = 'light' | 'dark';

const THEME_STORAGE_KEY = 'crm_theme_mode';

/** Read saved theme preference safely from localStorage. */
export function getStoredThemeMode(): ThemeMode {
  if (typeof window === 'undefined') return 'light';
  try {
    const saved = window.localStorage.getItem(THEME_STORAGE_KEY);
    if (saved === 'light' || saved === 'dark' || saved === 'system') {
      return saved;
    }
  } catch {
    // Ignore storage access errors in restricted contexts.
  }
  return 'light';
}

/** Resolve 'system' to the current OS color scheme preference. */
export function resolveTheme(mode: ThemeMode): ResolvedTheme {
  if (mode === 'light' || mode === 'dark') return mode;
  if (typeof window !== 'undefined' && typeof window.matchMedia === 'function') {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  return 'light';
}

/** Persist and apply data-theme to documentElement without triggering motion shifts. */
export function applyThemeMode(mode: ThemeMode): ResolvedTheme {
  const resolved = resolveTheme(mode);
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('data-theme', resolved);
    document.documentElement.style.colorScheme = resolved;
  }
  if (typeof window !== 'undefined') {
    try {
      window.localStorage.setItem(THEME_STORAGE_KEY, mode);
    } catch {
      // Ignore storage access errors in restricted contexts.
    }
  }
  return resolved;
}

/** Initialize theme synchronously at app boot before first paint. */
export function initTheme(): { mode: ThemeMode; resolved: ResolvedTheme } {
  const mode = getStoredThemeMode();
  const resolved = applyThemeMode(mode);
  return { mode, resolved };
}

