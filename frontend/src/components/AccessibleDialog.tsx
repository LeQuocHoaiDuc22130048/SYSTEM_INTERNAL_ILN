import React, { useRef, type ReactNode } from 'react';
import { useDialogA11y } from '../hooks/useMotion';

interface AccessibleDialogProps {
  onClose: () => void;
  className?: string;
  ariaLabel?: string;
  ariaLabelledBy?: string;
  children: ReactNode;
}

/**
 * Reusable dialog surface that wires Escape handling, focus trapping, and
 * focus restoration without requiring callers to manage refs directly.
 */
export const AccessibleDialog: React.FC<AccessibleDialogProps> = ({
  onClose,
  className,
  ariaLabel,
  ariaLabelledBy,
  children,
}) => {
  const dialogRef = useRef<HTMLDivElement>(null);
  useDialogA11y(true, onClose, dialogRef);

  return (
    <div
      ref={dialogRef}
      className={className}
      role="dialog"
      aria-modal="true"
      aria-label={ariaLabel}
      aria-labelledby={ariaLabelledBy}
      tabIndex={-1}
      onClick={(e) => e.stopPropagation()}
    >
      {children}
    </div>
  );
};

