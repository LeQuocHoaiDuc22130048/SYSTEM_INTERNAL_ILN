import React from 'react';

interface TimePicker24hProps {
  value: string; // Định dạng "HH:mm"
  onChange: (value: string) => void;
  disabled?: boolean;
}

export const TimePicker24h: React.FC<TimePicker24hProps> = ({
  value,
  onChange,
  disabled = false,
}) => {
  // Tách giá trị giờ và phút từ chuỗi value và căn lề 2 ký tự (ví dụ: '8' -> '08')
  const [hourRaw, minuteRaw] = (value || '08:00').split(':');
  const hour = (hourRaw || '08').padStart(2, '0');
  const minute = (minuteRaw || '00').padStart(2, '0');

  const handleHourChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    onChange(`${e.target.value}:${minute}`);
  };

  const handleMinuteChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    onChange(`${hour}:${e.target.value}`);
  };

  // Tạo mảng giờ [00..23] và phút [00..59]
  const hours = Array.from({ length: 24 }, (_, i) => String(i).padStart(2, '0'));
  const minutes = Array.from({ length: 60 }, (_, i) => String(i).padStart(2, '0'));

  return (
    <div className="time-picker-24h" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
      <select
        value={hour}
        onChange={handleHourChange}
        disabled={disabled}
        className="edit-time-input"
        style={{
          flex: 1,
          textAlign: 'center',
          cursor: disabled ? 'not-allowed' : 'pointer',
          backgroundColor: disabled ? '#f1f5f9' : '#fff',
        }}
      >
        {hours.map((h) => (
          <option key={h} value={h}>
            {h}
          </option>
        ))}
      </select>
      <span style={{ fontWeight: 'bold', color: '#64748b' }}>:</span>
      <select
        value={minute}
        onChange={handleMinuteChange}
        disabled={disabled}
        className="edit-time-input"
        style={{
          flex: 1,
          textAlign: 'center',
          cursor: disabled ? 'not-allowed' : 'pointer',
          backgroundColor: disabled ? '#f1f5f9' : '#fff',
        }}
      >
        {minutes.map((m) => (
          <option key={m} value={m}>
            {m}
          </option>
        ))}
      </select>
    </div>
  );
};
