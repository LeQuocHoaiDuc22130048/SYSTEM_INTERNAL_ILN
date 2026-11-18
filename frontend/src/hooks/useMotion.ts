import { useState, useEffect, useRef, type RefObject } from 'react';

const FOCUSABLE_SELECTOR = [
  'a[href]',
  'button:not([disabled])',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  '[tabindex]:not([tabindex="-1"])',
].join(',');

/** Subscribe to the user's OS/browser reduced-motion preference. */
export function useReducedMotion(): boolean {
  const [reduced, setReduced] = useState<boolean>(() => {
    if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') {
      return false;
    }
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  });

  useEffect(() => {
    if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') {
      return;
    }
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    const handleChange = (event: MediaQueryListEvent) => {
      setReduced(event.matches);
    };

    setReduced(mediaQuery.matches);
    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, []);

  return reduced;
}

interface UseCountUpOptions {
  /** Animation duration in ms (CRM Motion Design System: 600–900ms, default 750ms). */
  duration?: number;
  /** Number of decimal places to preserve. */
  decimals?: number;
  /** Disable animation (e.g. while loading). */
  enabled?: boolean;
}

/**
 * Count up a KPI number once when data first appears.
 * Subsequent updates (e.g. polling refreshes) jump directly to the target value
 * per CRM Motion Design System Section 5.9.
 */
export function useCountUp(
  target: number,
  { duration = 750, decimals = 0, enabled = true }: UseCountUpOptions = {}
): number {
  const reducedMotion = useReducedMotion();
  const hasAnimatedInitial = useRef<boolean>(false);
  const [displayValue, setDisplayValue] = useState<number>(target);

  useEffect(() => {
    if (!enabled || reducedMotion || !Number.isFinite(target) || target <= 0) {
      setDisplayValue(target);
      return;
    }

    if (hasAnimatedInitial.current) {
      setDisplayValue(target);
      return;
    }

    hasAnimatedInitial.current = true;
    let frameId = 0;
    const startTime = performance.now();
    const factor = 10 ** decimals;

    const tick = (now: number) => {
      const elapsed = now - startTime;
      const progress = Math.min(1, elapsed / duration);
      // ease-enter / ease-out cubic approximation: 1 - (1 - t)^3
      const eased = 1 - (1 - progress) ** 3;
      const next = Math.round(target * eased * factor) / factor;
      setDisplayValue(next);
      if (progress < 1) {
        frameId = window.requestAnimationFrame(tick);
      } else {
        setDisplayValue(target);
      }
    };

    setDisplayValue(0);
    frameId = window.requestAnimationFrame(tick);
    return () => {
      if (frameId) {
        window.cancelAnimationFrame(frameId);
      }
    };
  }, [target, duration, decimals, enabled, reducedMotion]);

  return displayValue;
}

/**
 * Provide accessible modal/drawer behavior:
 * - Closes on Escape
 * - Restores focus to the triggering element on close/unmount
 * - Moves focus into container on open and traps Tab navigation
 */
export function useDialogA11y(
  isOpen: boolean,
  onClose: () => void,
  containerRef: RefObject<HTMLElement | null>
): void {
  const onCloseRef = useRef(onClose);

  useEffect(() => {
    onCloseRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    if (!isOpen || typeof document === 'undefined') return;

    const previousFocus = document.activeElement as HTMLElement | null;
    const container = containerRef.current;

    if (container) {
      const focusables = Array.from(
        container.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)
      ).filter((el) => el.offsetParent !== null || el === document.activeElement);

      if (!container.contains(document.activeElement)) {
        if (focusables.length > 0) {
          focusables[0].focus({ preventScroll: true });
        } else {
          container.focus({ preventScroll: true });
        }
      }
    }

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.stopPropagation();
        onCloseRef.current();
        return;
      }

      if (event.key !== 'Tab' || !container) return;

      const focusables = Array.from(
        container.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)
      ).filter((el) => el.offsetParent !== null);

      if (focusables.length === 0) {
        event.preventDefault();
        return;
      }

      const first = focusables[0];
      const last = focusables[focusables.length - 1];
      const active = document.activeElement as HTMLElement | null;

      if (event.shiftKey) {
        if (active === first || !container.contains(active)) {
          event.preventDefault();
          last.focus();
        }
      } else if (active === last || !container.contains(active)) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      if (previousFocus && typeof previousFocus.focus === 'function' && document.contains(previousFocus)) {
        previousFocus.focus({ preventScroll: true });
      }
    };
  }, [isOpen, containerRef]);
}
