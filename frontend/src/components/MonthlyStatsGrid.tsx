import React from 'react';
import { AnimatedNumber } from './AnimatedNumber';

interface MonthlyStatsGridProps {
  totalStandardDays: number;
  averagePresent: number;
  totalLateCount: number;
  totalAbsentDays: number;
}

export const MonthlyStatsGrid: React.FC<MonthlyStatsGridProps> = ({
  totalStandardDays,
  averagePresent,
  totalLateCount,
  totalAbsentDays,
}) => {
  return (
    <section className="stats-grid">
      <div className="stats-card">
        <span className="stats-label">Ngày làm việc tiêu chuẩn</span>
        <div className="stats-value-row">
          <span className="stats-value"><AnimatedNumber value={totalStandardDays} /></span>
          <span className="stats-badge success">ngày / tháng</span>
        </div>
      </div>
      <div className="stats-card">
        <span className="stats-label">Đủ công trung bình</span>
        <div className="stats-value-row">
          <span className="stats-value"><AnimatedNumber value={averagePresent} decimals={1} /></span>
          <span className="stats-badge success">ngày / NV</span>
        </div>
      </div>
      <div className="stats-card">
        <span className="stats-label">Tổng lượt đi muộn</span>
        <div className="stats-value-row">
          <span className="stats-value"><AnimatedNumber value={totalLateCount} /></span>
          <span className="stats-badge late">lượt</span>
        </div>
      </div>
      <div className="stats-card">
        <span className="stats-label">Vắng không phép</span>
        <div className="stats-value-row">
          <span className="stats-value"><AnimatedNumber value={totalAbsentDays} /></span>
          <span className="stats-badge absent">ngày</span>
        </div>
      </div>
    </section>
  );
};
