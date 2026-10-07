import { useCallback, useEffect, useRef, useState } from 'react';

/** Keep complete editor snapshots, including unsaved upload Files. */
export function useBannerHistory<T>(value: T, active: boolean, restore: (value: T) => void) {
  const entries = useRef<T[]>([]);
  const cursor = useRef(0);
  const pending = useRef<T | null>(null);
  const restoring = useRef(false);
  const interacting = useRef(false);
  const [status, setStatus] = useState({ canUndo: false, canRedo: false });
  const refresh = useCallback(() => setStatus({ canUndo: pending.current !== null || cursor.current > 0, canRedo: pending.current === null && cursor.current < entries.current.length - 1 }), []);
  const commit = useCallback(() => {
    if (pending.current === null) return;
    entries.current = [...entries.current.slice(0, cursor.current + 1), pending.current].slice(-100);
    cursor.current = entries.current.length - 1;
    pending.current = null;
    refresh();
  }, [refresh]);
  useEffect(() => {
    if (!active) { entries.current = []; pending.current = null; return; }
    if (!entries.current.length) { entries.current = [value]; cursor.current = 0; refresh(); return; }
    if (restoring.current) { restoring.current = false; return; }
    pending.current = value;
    refresh();
    const timer = window.setTimeout(() => { if (!interacting.current) commit(); }, 500);
    return () => window.clearTimeout(timer);
    // Snapshots are memoized by the caller; UI history updates must not record themselves.
  }, [value, active, commit, refresh]);
  return {
    ...status,
    checkpoint: commit,
    begin: () => { commit(); interacting.current = true; },
    end: () => { interacting.current = false; commit(); },
    undo: () => { commit(); if (cursor.current > 0) { restoring.current = true; restore(entries.current[--cursor.current]); refresh(); } },
    redo: () => { if (pending.current === null && cursor.current < entries.current.length - 1) { restoring.current = true; restore(entries.current[++cursor.current]); refresh(); } },
  };
}
