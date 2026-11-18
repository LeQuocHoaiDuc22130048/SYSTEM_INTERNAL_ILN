export interface TooltipAnchorRect {
  top: number;
  bottom: number;
  left: number;
  width: number;
}

export interface TooltipPosition {
  top: number;
  left: number;
  placement: 'top' | 'bottom';
  arrowLeft: number;
}

/** Tính toán vị trí nổi cố định theo viewport để tooltip không bị cắt bởi overflow của bảng */
export const computeFloatingTooltipPosition = (
  anchorRect: TooltipAnchorRect,
  tipSize: { width: number; height: number },
  viewport: { width: number; height: number },
  options: { margin?: number; gap?: number; topSafeLimit?: number } = {}
): TooltipPosition => {
  const margin = options.margin ?? 12;
  const gap = options.gap ?? 10;
  const topSafeLimit = options.topSafeLimit ?? 76;

  const fitsAbove = anchorRect.top - tipSize.height - gap >= topSafeLimit;
  const placement: 'top' | 'bottom' = fitsAbove ? 'top' : 'bottom';
  let top = fitsAbove
    ? anchorRect.top - tipSize.height - gap
    : anchorRect.bottom + gap;
  top = Math.max(margin, Math.min(top, viewport.height - tipSize.height - margin));

  const anchorCenterX = anchorRect.left + anchorRect.width / 2;
  const idealLeft = anchorCenterX - tipSize.width / 2;
  const maxLeft = Math.max(margin, viewport.width - tipSize.width - margin);
  const left = Math.max(margin, Math.min(idealLeft, maxLeft));

  const arrowEdgeInset = Math.min(14, Math.floor(tipSize.width / 2));
  const arrowLeft = Math.max(
    arrowEdgeInset,
    Math.min(tipSize.width - arrowEdgeInset, anchorCenterX - left)
  );

  return { top, left, placement, arrowLeft };
};

