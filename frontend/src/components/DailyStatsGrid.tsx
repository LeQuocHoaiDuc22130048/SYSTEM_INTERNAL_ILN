import React from 'react';

interface DailyStatsGridProps {
  total: number;
  onTime: number;
  lateEarly: number;
  absent: number;
}

export const DailyStatsGrid: React.FC<DailyStatsGridProps> = ({
  total,
  onTime,
  lateEarly,
  absent,
}) => {
  return (
    <section className="stats-grid">
      <div className="stats-card">
        <span className="stats-label">Tổng số nhân sự</span>
        <div className="stats-value-row">
          <span className="stats-value">{total}</span>
          <span className="stats-badge success">nhân viên</span>
        </div>
      </div>
      <div className="stats-card">
        <span className="stats-label">Đúng giờ / Có mặt</span>
        <div className="stats-value-row">
          <span className="stats-value">{onTime}</span>
          <span className="stats-badge success">đang làm việc</span>
        </div>
      </div>
      <div className="stats-card">
        <span className="stats-label">Đi muộn / Về sớm</span>
        <div className="stats-value-row">
          <span className="stats-value">{lateEarly}</span>
          <span className="stats-badge late">trường hợp</span>
        </div>
      </div>
      <div className="stats-card">
        <span className="stats-label">Vắng mặt / Nghỉ phép</span>
        <div className="stats-value-row">
          <span className="stats-value">{absent}</span>
          <span className="stats-badge absent">vắng</span>
        </div>
      </div>
    </section>
  );
};
