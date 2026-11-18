import React from 'react';
import { useCountUp } from '../hooks/useMotion';

interface AnimatedNumberProps {
  value: number;
  decimals?: number;
  duration?: number;
  suffix?: string;
}

/**
 * Displays a numeric KPI value with a single 600–900ms count-up on initial reveal.
 * Preserves the exact final number for screen readers via aria-label.
 */
export const AnimatedNumber: React.FC<AnimatedNumberProps> = ({
  value,
  decimals = 0,
  duration = 750,
  suffix = '',
}) => {
  const animated = useCountUp(value, { duration, decimals });
  const formattedAnimated = decimals > 0 ? animated.toFixed(decimals) : String(Math.round(animated));
  const formattedFinal = decimals > 0 ? value.toFixed(decimals) : String(value);

  return (
    <span aria-label={`${formattedFinal}${suffix}`}>
      {formattedAnimated}
      {suffix}
    </span>
  );
};

