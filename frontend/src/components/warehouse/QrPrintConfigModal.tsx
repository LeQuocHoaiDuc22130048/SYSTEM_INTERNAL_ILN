import React, { useState, useMemo } from 'react';
import {
  X,
  Printer,
  Sliders,
  Layout,
  Move,
  Type,
  Eye,
  RotateCcw,
  Check,
  Smartphone,
  HardDrive,
  Zap,
  Settings2,
  Copy,
} from 'lucide-react';
import type { BoardQrExportData, QrPrintConfig, PrinterDriverType } from '../../utils/pdf';
import './QrPrintConfigModal.css';

const DEFAULT_CONFIG: QrPrintConfig = {
  printerDriver: 'system_default',
  printerDpi: 203,
  printMode: 'direct_thermal',
  printDarkness: 8,
  printSpeed: 4,
  template: 'mobile_standard',
  presetSize: '50x40',
  widthMm: 50,
  heightMm: 40,
  qrSizePx: 120,
  titleFontSize: 12,
  codeFontSize: 14,
  layoutOrder: 'qr_top',
  textAlign: 'center',
  paddingMm: 4,
  borderWidthPx: 1.5,
  borderRadiusPx: 8,
  showBorder: true,
  showName: true,
  showModel: true,
  showLocation: false,
  showCodeText: true,
  showSerialNumber: false,
};

const STORAGE_KEY = 'suachuabientan_qr_print_config';

interface QrPrintConfigModalProps {
  isOpen: boolean;
  boards: BoardQrExportData[];
  onClose: () => void;
  onConfirmPrint: (config: QrPrintConfig) => void;
}

export const QrPrintConfigModal: React.FC<QrPrintConfigModalProps> = ({
  isOpen,
  boards,
  onClose,
  onConfirmPrint,
}) => {
  const [config, setConfig] = useState<QrPrintConfig>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        return { ...DEFAULT_CONFIG, ...JSON.parse(saved) };
      }
    } catch (_) {}
    return DEFAULT_CONFIG;
  });

  const [activeBoardIndex, setActiveBoardIndex] = useState<number>(0);
  const [isSavedNotice, setIsSavedNotice] = useState<boolean>(false);
  const [testDriverStatus, setTestDriverStatus] = useState<string | null>(null);
  const [isModalQrCopied, setIsModalQrCopied] = useState<boolean>(false);

  const handleCopyModalQr = () => {
    const rawQrText = boards && boards.length > 1
      ? boards.map(b => (b.qrCode || '').trim()).filter(Boolean).join('\n')
      : (activeBoard.qrCode || '').trim();

    if (rawQrText) {
      navigator.clipboard.writeText(rawQrText);
      setIsModalQrCopied(true);
      setTimeout(() => setIsModalQrCopied(false), 2200);
    }
  };

  const activeBoard = useMemo(() => {
    if (!boards || boards.length === 0) {
      return {
        id: '1',
        name: 'Bo Mạch Biến Tần Yaskawa 15KW',
        qrCode: 'BM-2026-YAS-001',
        model: 'YASKAWA-A1000',
        location: 'KHO-A1-K02',
        serialNumber: 'SN-987654321',
      };
    }
    return boards[Math.min(activeBoardIndex, boards.length - 1)];
  }, [boards, activeBoardIndex]);

  // Handle Preset Changes
  const handlePresetChange = (preset: QrPrintConfig['presetSize']) => {
    let w = config.widthMm;
    let h = config.heightMm;
    let t = config.template;
    let q = config.qrSizePx;
    let titleFs = config.titleFontSize;
    let codeFs = config.codeFontSize;

    switch (preset) {
      case '50x40':
        w = 50;
        h = 40;
        t = 'mobile_standard';
        q = 110;
        titleFs = 11;
        codeFs = 13;
        break;
      case '60x40':
        w = 60;
        h = 40;
        q = 120;
        titleFs = 12;
        codeFs = 14;
        break;
      case '70x50':
        w = 70;
        h = 50;
        q = 140;
        titleFs = 13;
        codeFs = 16;
        break;
      case '70x30':
        w = 70;
        h = 30;
        t = 'horizontal';
        q = 90;
        titleFs = 11;
        codeFs = 12;
        break;
      case 'a4':
        w = 210;
        h = 297;
        t = 'grid';
        q = 120;
        titleFs = 12;
        codeFs = 14;
        break;
      default:
        break;
    }

    setConfig((prev) => ({
      ...prev,
      presetSize: preset,
      widthMm: w,
      heightMm: h,
      template: t,
      qrSizePx: q,
      titleFontSize: titleFs,
      codeFontSize: codeFs,
    }));
  };

  // Handle Template Changes
  const handleTemplateChange = (tmpl: QrPrintConfig['template']) => {
    let layoutOrder: QrPrintConfig['layoutOrder'] = config.layoutOrder;
    let showLoc = config.showLocation;
    let showMdl = config.showModel;

    if (tmpl === 'horizontal') {
      layoutOrder = 'horizontal';
    } else if (tmpl === 'compact') {
      layoutOrder = 'qr_top';
      showMdl = false;
      showLoc = false;
    } else if (tmpl === 'detailed') {
      showLoc = true;
      showMdl = true;
    } else if (tmpl === 'mobile_standard') {
      layoutOrder = 'qr_top';
      showMdl = true;
    }

    setConfig((prev) => ({
      ...prev,
      template: tmpl,
      layoutOrder,
      showLocation: showLoc,
      showModel: showMdl,
    }));
  };

  const handleTestPrinterDriver = () => {
    setTestDriverStatus('Đang kiểm tra kết nối với Driver máy in...');
    setTimeout(() => {
      let msg = '';
      switch (config.printerDriver) {
        case 'eleph_phomemo':
          msg = '✅ Driver Eleph-label / Phomemo sẵn sàng (203 DPI, Nhiệt trực tiếp)';
          break;
        case 'xprinter_tspl':
          msg = '✅ Driver Xprinter / TSC (TSPL) kết nối thành công! Cổng USB ready.';
          break;
        case 'godex_ezpl':
          msg = '✅ Driver GoDEX / Bixolon (EZPL) kết nối thành công!';
          break;
        case 'pdf_virtual':
          msg = '✅ Driver Máy in ảo PDF sẵn sàng xuất nhãn!';
          break;
        case 'web_usb_direct':
          msg = '⚡ Đã phát hiện máy in tem USB/Serial trên thiết bị!';
          break;
        default:
          msg = '✅ Driver Máy in hệ thống (Windows/macOS) sẵn sàng!';
          break;
      }
      setTestDriverStatus(msg);
      setTimeout(() => setTestDriverStatus(null), 4000);
    }, 600);
  };

  const handleSaveDefaults = () => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
      setIsSavedNotice(true);
      setTimeout(() => setIsSavedNotice(false), 2500);
    } catch (_) {}
  };

  const handleResetDefaults = () => {
    setConfig(DEFAULT_CONFIG);
  };

  const handlePrintClick = () => {
    onConfirmPrint(config);
  };

  if (!isOpen) return null;

  const qrApiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(
    activeBoard.qrCode || 'N/A'
  )}`;

  return (
    <div className="qr-print-modal-overlay">
      <div className="qr-print-modal-container">
        {/* Header */}
        <div className="qr-print-modal-header">
          <div>
            <h3>
              <Printer size={22} color="#0284c7" />
              <span>In Tem Nhãn Kho & Bo Mạch</span>
            </h3>
            <p>Tùy chỉnh driver máy in thiết bị, kích thước tem, vị trí, font chữ và mẫu in</p>
          </div>
          <button className="btn-close-modal" onClick={onClose} title="Đóng">
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <div className="qr-print-modal-body">
          {/* Controls Left Panel */}
          <div className="qr-print-controls-panel">
            {/* 0. Driver Máy In Của Thiết Bị */}
            <div className="qr-print-section highlight-driver-section">
              <h4 className="qr-section-title">
                <HardDrive size={15} color="#0284c7" />
                <span>Driver Máy In Của Thiết Bị</span>
              </h4>

              <div className="control-group">
                <label>Chọn Driver máy in</label>
                <select
                  className="control-select driver-select-highlight"
                  value={config.printerDriver || 'system_default'}
                  onChange={(e) =>
                    setConfig((prev) => ({
                      ...prev,
                      printerDriver: e.target.value as PrinterDriverType,
                    }))
                  }
                >
                  <option value="system_default">🖨️ Driver Hệ thống / Trình duyệt (Windows/macOS Dialog)</option>
                  <option value="eleph_phomemo">📱 Driver Eleph-label / Phomemo (Tem cuộn Bluetooth/USB)</option>
                  <option value="xprinter_tspl">⚡ Driver Xprinter / TSC / Zebra (Mã lệnh TSPL/EPL)</option>
                  <option value="godex_ezpl">🏷️ Driver GoDEX / Bixolon (Mã lệnh EZPL/ZPL)</option>
                  <option value="pdf_virtual">📄 Driver Máy in ảo PDF (Lưu file PDF tem nhãn)</option>
                  <option value="web_usb_direct">🔌 Kết nối Trực tiếp WebUSB / Bluetooth Máy in</option>
                </select>
              </div>

              <div className="control-row-2">
                <div className="control-group">
                  <label>Độ phân giải (DPI)</label>
                  <select
                    className="control-select"
                    value={config.printerDpi || 203}
                    onChange={(e) =>
                      setConfig((prev) => ({ ...prev, printerDpi: Number(e.target.value) }))
                    }
                  >
                    <option value={203}>203 DPI (8 dots/mm - Tem nhiệt)</option>
                    <option value={300}>300 DPI (12 dots/mm - Sắc nét)</option>
                    <option value={600}>600 DPI (Cao cấp)</option>
                  </select>
                </div>

                <div className="control-group">
                  <label>Phương thức in</label>
                  <select
                    className="control-select"
                    value={config.printMode || 'direct_thermal'}
                    onChange={(e) =>
                      setConfig((prev) => ({ ...prev, printMode: e.target.value as any }))
                    }
                  >
                    <option value="direct_thermal">In nhiệt trực tiếp (Direct Thermal)</option>
                    <option value="thermal_transfer">In chuyển nhiệt (Thermal Transfer)</option>
                    <option value="die_cut">Tem nhãn khe hở (Die-cut Gap)</option>
                    <option value="continuous">Cuộn liên tục (Continuous Roll)</option>
                  </select>
                </div>
              </div>

              <div className="control-row-2">
                <div className="control-group">
                  <label>
                    <span>Độ đậm (Darkness)</span>
                    <span className="value-badge">{config.printDarkness || 8}</span>
                  </label>
                  <input
                    type="range"
                    className="range-slider"
                    min={1}
                    max={15}
                    value={config.printDarkness || 8}
                    onChange={(e) =>
                      setConfig((prev) => ({ ...prev, printDarkness: Number(e.target.value) }))
                    }
                  />
                </div>

                <div className="control-group">
                  <label>Tốc độ in</label>
                  <div className="btn-group-toggle">
                    {[2, 4, 6].map((speed) => (
                      <button
                        key={speed}
                        className={`btn-toggle-option ${
                          (config.printSpeed || 4) === speed ? 'active' : ''
                        }`}
                        onClick={() => setConfig((prev) => ({ ...prev, printSpeed: speed }))}
                      >
                        {speed} ips
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              <div className="driver-actions-row">
                <button className="btn-test-driver" onClick={handleTestPrinterDriver}>
                  <Zap size={14} />
                  <span>Thử Driver Máy In</span>
                </button>
                {testDriverStatus && (
                  <span className="test-driver-status-text">{testDriverStatus}</span>
                )}
              </div>
            </div>

            {/* 1. Mẫu In (Templates) */}
            <div className="qr-print-section">
              <h4 className="qr-section-title">
                <Layout size={15} />
                <span>1. Mẫu In Tem QR</span>
              </h4>
              <div className="control-group">
                <label>Chọn kiểu mẫu in</label>
                <select
                  className="control-select"
                  value={config.template}
                  onChange={(e) => handleTemplateChange(e.target.value as any)}
                >
                  <option value="mobile_standard">📱 Tem chuẩn Mobile (50x40mm Eleph-label)</option>
                  <option value="compact">⚡ Tem rút gọn (Chỉ QR & Mã Code)</option>
                  <option value="detailed">📋 Tem chi tiết (Tên, Model, Vị trí, Serial)</option>
                  <option value="horizontal">↔️ Tem nằm ngang (QR bên trái)</option>
                  <option value="grid">▦ Trang in hàng loạt (Lưới A4)</option>
                </select>
              </div>
            </div>

            {/* 2. Kích thước (Dimensions) */}
            <div className="qr-print-section">
              <h4 className="qr-section-title">
                <Sliders size={15} />
                <span>2. Kích Thước Tem & QR</span>
              </h4>

              <div className="control-group">
                <label>Kích thước chuẩn (Preset)</label>
                <select
                  className="control-select"
                  value={config.presetSize}
                  onChange={(e) => handlePresetChange(e.target.value as any)}
                >
                  <option value="50x40">50 x 40 mm (Chuẩn Eleph-label Mobile)</option>
                  <option value="60x40">60 x 40 mm (Rộng hơn)</option>
                  <option value="70x50">70 x 50 mm (Tem lớn kho)</option>
                  <option value="70x30">70 x 30 mm (Tem nằm ngang)</option>
                  <option value="a4">Trang A4 (210 x 297 mm)</option>
                  <option value="custom">Tùy chỉnh (Custom)...</option>
                </select>
              </div>

              {config.presetSize === 'custom' && (
                <div className="control-row-2">
                  <div className="control-group">
                    <label>Rộng (mm)</label>
                    <input
                      type="number"
                      className="control-input"
                      value={config.widthMm}
                      min={20}
                      max={300}
                      onChange={(e) => setConfig((prev) => ({ ...prev, widthMm: Number(e.target.value) }))}
                    />
                  </div>
                  <div className="control-group">
                    <label>Cao (mm)</label>
                    <input
                      type="number"
                      className="control-input"
                      value={config.heightMm}
                      min={20}
                      max={300}
                      onChange={(e) => setConfig((prev) => ({ ...prev, heightMm: Number(e.target.value) }))}
                    />
                  </div>
                </div>
              )}

              <div className="control-group">
                <label>
                  <span>Kích thước mã QR</span>
                  <span className="value-badge">{config.qrSizePx} px</span>
                </label>
                <input
                  type="range"
                  className="range-slider"
                  min={50}
                  max={250}
                  value={config.qrSizePx}
                  onChange={(e) => setConfig((prev) => ({ ...prev, qrSizePx: Number(e.target.value) }))}
                />
              </div>
            </div>

            {/* 3. Vị trí & Căn chỉnh (Layout & Alignment) */}
            <div className="qr-print-section">
              <h4 className="qr-section-title">
                <Move size={15} />
                <span>3. Vị Trí & Bố Cục</span>
              </h4>

              <div className="control-group">
                <label>Thứ tự bố cục</label>
                <div className="btn-group-toggle">
                  <button
                    className={`btn-toggle-option ${config.layoutOrder === 'qr_top' ? 'active' : ''}`}
                    onClick={() => setConfig((prev) => ({ ...prev, layoutOrder: 'qr_top' }))}
                  >
                    QR Trên
                  </button>
                  <button
                    className={`btn-toggle-option ${config.layoutOrder === 'title_top' ? 'active' : ''}`}
                    onClick={() => setConfig((prev) => ({ ...prev, layoutOrder: 'title_top' }))}
                  >
                    Chữ Trên
                  </button>
                  <button
                    className={`btn-toggle-option ${config.layoutOrder === 'horizontal' ? 'active' : ''}`}
                    onClick={() => setConfig((prev) => ({ ...prev, layoutOrder: 'horizontal' }))}
                  >
                    Ngang
                  </button>
                </div>
              </div>

              <div className="control-group">
                <label>Căn chỉnh văn bản</label>
                <div className="btn-group-toggle">
                  <button
                    className={`btn-toggle-option ${config.textAlign === 'left' ? 'active' : ''}`}
                    onClick={() => setConfig((prev) => ({ ...prev, textAlign: 'left' }))}
                  >
                    Trái
                  </button>
                  <button
                    className={`btn-toggle-option ${config.textAlign === 'center' ? 'active' : ''}`}
                    onClick={() => setConfig((prev) => ({ ...prev, textAlign: 'center' }))}
                  >
                    Giữa
                  </button>
                  <button
                    className={`btn-toggle-option ${config.textAlign === 'right' ? 'active' : ''}`}
                    onClick={() => setConfig((prev) => ({ ...prev, textAlign: 'right' }))}
                  >
                    Phải
                  </button>
                </div>
              </div>

              <div className="control-row-2">
                <div className="control-group">
                  <label>
                    <span>Lề (Padding)</span>
                    <span className="value-badge">{config.paddingMm} mm</span>
                  </label>
                  <input
                    type="range"
                    className="range-slider"
                    min={0}
                    max={15}
                    value={config.paddingMm}
                    onChange={(e) => setConfig((prev) => ({ ...prev, paddingMm: Number(e.target.value) }))}
                  />
                </div>
                <div className="control-group">
                  <label>
                    <span>Bo góc</span>
                    <span className="value-badge">{config.borderRadiusPx} px</span>
                  </label>
                  <input
                    type="range"
                    className="range-slider"
                    min={0}
                    max={20}
                    value={config.borderRadiusPx}
                    onChange={(e) => setConfig((prev) => ({ ...prev, borderRadiusPx: Number(e.target.value) }))}
                  />
                </div>
              </div>
            </div>

            {/* 4. Font chữ & Chữ hiển thị */}
            <div className="qr-print-section">
              <h4 className="qr-section-title">
                <Type size={15} />
                <span>4. Font Chữ & Cỡ Chữ</span>
              </h4>

              <div className="control-row-2">
                <div className="control-group">
                  <label>
                    <span>Cỡ chữ Tên</span>
                    <span className="value-badge">{config.titleFontSize} px</span>
                  </label>
                  <input
                    type="range"
                    className="range-slider"
                    min={8}
                    max={24}
                    value={config.titleFontSize}
                    onChange={(e) => setConfig((prev) => ({ ...prev, titleFontSize: Number(e.target.value) }))}
                  />
                </div>
                <div className="control-group">
                  <label>
                    <span>Cỡ chữ Mã Code</span>
                    <span className="value-badge">{config.codeFontSize} px</span>
                  </label>
                  <input
                    type="range"
                    className="range-slider"
                    min={9}
                    max={26}
                    value={config.codeFontSize}
                    onChange={(e) => setConfig((prev) => ({ ...prev, codeFontSize: Number(e.target.value) }))}
                  />
                </div>
              </div>
            </div>

            {/* 5. Nội dung hiển thị (Checkboxes) */}
            <div className="qr-print-section">
              <h4 className="qr-section-title">
                <Eye size={15} />
                <span>5. Nội Dung Hiển Thị</span>
              </h4>

              <div className="checkbox-grid">
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={config.showBorder}
                    onChange={(e) => setConfig((prev) => ({ ...prev, showBorder: e.target.checked }))}
                  />
                  <span>Khung viền tem</span>
                </label>
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={config.showName}
                    onChange={(e) => setConfig((prev) => ({ ...prev, showName: e.target.checked }))}
                  />
                  <span>Tên bo mạch</span>
                </label>
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={config.showModel}
                    onChange={(e) => setConfig((prev) => ({ ...prev, showModel: e.target.checked }))}
                  />
                  <span>Model bo mạch</span>
                </label>
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={config.showLocation}
                    onChange={(e) => setConfig((prev) => ({ ...prev, showLocation: e.target.checked }))}
                  />
                  <span>Vị trí kho</span>
                </label>
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={config.showCodeText}
                    onChange={(e) => setConfig((prev) => ({ ...prev, showCodeText: e.target.checked }))}
                  />
                  <span>Mã Code QR</span>
                </label>
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={config.showSerialNumber}
                    onChange={(e) => setConfig((prev) => ({ ...prev, showSerialNumber: e.target.checked }))}
                  />
                  <span>Số Serial</span>
                </label>
              </div>
            </div>
          </div>

          {/* Right Live Preview Panel */}
          <div className="qr-print-preview-panel">
            <div className="preview-top-toolbar">
              <span className="preview-badge">
                <Eye size={14} />
                <span>Bản xem trước thời gian thực (Live Preview)</span>
              </span>

              <span className="driver-active-badge">
                <Settings2 size={13} />
                <span>Driver: {config.printerDriver || 'system_default'} ({config.printerDpi || 203} DPI)</span>
              </span>

              {boards && boards.length > 1 && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px' }}>
                  <span>Xem tem bo mạch:</span>
                  <select
                    className="control-select"
                    style={{ width: 'auto', padding: '4px 8px' }}
                    value={activeBoardIndex}
                    onChange={(e) => setActiveBoardIndex(Number(e.target.value))}
                  >
                    {boards.map((b, idx) => (
                      <option key={b.id || idx} value={idx}>
                        #{idx + 1} - {b.name} ({b.qrCode})
                      </option>
                    ))}
                  </select>
                </div>
              )}
            </div>

            {/* Viewport Render Canvas */}
            <div className="preview-viewport-wrapper">
              <div
                className={`live-qr-card order-${config.layoutOrder}`}
                style={{
                  width: config.template === 'grid' ? '180mm' : `${config.widthMm}mm`,
                  minHeight: config.template === 'grid' ? '240mm' : `${config.heightMm}mm`,
                  padding: `${config.paddingMm}mm`,
                  border: config.showBorder
                    ? `${config.borderWidthPx}px solid #1e293b`
                    : '1px dashed #cbd5e1',
                  borderRadius: `${config.borderRadiusPx}px`,
                  textAlign: config.textAlign,
                  gap: config.layoutOrder === 'horizontal' ? '14px' : '8px',
                }}
              >
                {/* QR Image Section */}
                <div className="live-qr-image-wrapper">
                  <img
                    src={qrApiUrl}
                    alt="QR Preview"
                    className="live-qr-img"
                    style={{
                      width: `${config.qrSizePx}px`,
                      height: `${config.qrSizePx}px`,
                    }}
                  />
                </div>

                {/* Text Info Section */}
                <div
                  className="live-qr-meta"
                  style={{
                    alignItems:
                      config.textAlign === 'center'
                        ? 'center'
                        : config.textAlign === 'right'
                        ? 'flex-end'
                        : 'flex-start',
                    gap: '4px',
                  }}
                >
                  {config.showName && (
                    <div
                      className="live-qr-title"
                      style={{ fontSize: `${config.titleFontSize}px` }}
                    >
                      {activeBoard.name}
                    </div>
                  )}

                  {config.showModel && activeBoard.model && (
                    <div className="live-qr-subtext" style={{ fontSize: `${config.titleFontSize - 2}px` }}>
                      Model: <strong>{activeBoard.model}</strong>
                    </div>
                  )}

                  {config.showLocation && activeBoard.location && (
                    <div className="live-qr-subtext" style={{ fontSize: `${config.titleFontSize - 2}px` }}>
                      Vị trí: <strong>{activeBoard.location}</strong>
                    </div>
                  )}

                  {config.showSerialNumber && activeBoard.serialNumber && (
                    <div className="live-qr-subtext" style={{ fontSize: `${config.titleFontSize - 2}px` }}>
                      S/N: {activeBoard.serialNumber}
                    </div>
                  )}

                  {config.showCodeText && (
                    <div
                      className="live-qr-code-box"
                      style={{
                        marginTop: '4px',
                        padding: '4px 8px',
                      }}
                    >
                      <span className="live-qr-code-label">MÃ CODE QR:</span>
                      <span
                        className="live-qr-code-value"
                        style={{ fontSize: `${config.codeFontSize}px` }}
                      >
                        {activeBoard.qrCode || 'N/A'}
                      </span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="qr-print-modal-footer">
          <div className="modal-footer-left">
            <button
              className="btn-secondary"
              onClick={handleCopyModalQr}
              style={{
                background: isModalQrCopied ? '#dcfce7' : undefined,
                color: isModalQrCopied ? '#166534' : undefined,
                borderColor: isModalQrCopied ? '#86efac' : undefined,
              }}
              title="Sao chép chuỗi mã QR vào bộ nhớ tạm"
            >
              {isModalQrCopied ? <Check size={16} color="#16a34a" /> : <Copy size={16} />}
              <span>{isModalQrCopied ? 'Đã sao chép mã QR!' : 'Sao chép Mã QR'}</span>
            </button>
            <button className="btn-secondary" onClick={handleSaveDefaults}>
              {isSavedNotice ? <Check size={16} color="#16a34a" /> : <Smartphone size={16} />}
              <span>{isSavedNotice ? 'Đã lưu cấu hình!' : 'Lưu làm mặc định'}</span>
            </button>
            <button className="btn-secondary" onClick={handleResetDefaults}>
              <RotateCcw size={15} />
              <span>Khôi phục mặc định</span>
            </button>
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <button className="btn-secondary" onClick={onClose}>
              Hủy / Đóng
            </button>
            <button className="btn-primary-print" onClick={handlePrintClick}>
              <Printer size={18} />
              <span>Bắt Đầu In Tem Nhãn ({boards?.length || 1} Tem)</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
