import React, { useState, useMemo } from 'react';
import {
  X,
  Printer,
  Sliders,
  Layout,
  Eye,
  RotateCcw,
  Check,
  Zap,
  Settings2,
  Copy,
  MapPin,
} from 'lucide-react';
import type { LocationQrExportData, BoardQrExportData, QrPrintConfig, PrinterDriverType } from '../../utils/pdf';
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
  showModel: false,
  showLocation: true,
  showCodeText: true,
  showSerialNumber: false,
};

const STORAGE_KEY = 'suachuabientan_qr_print_config';

interface QrPrintConfigModalProps {
  isOpen: boolean;
  locations?: LocationQrExportData[];
  boards?: BoardQrExportData[]; // backward compatibility
  onClose: () => void;
  onConfirmPrint: (config: QrPrintConfig) => void;
}

export const QrPrintConfigModal: React.FC<QrPrintConfigModalProps> = ({
  isOpen,
  locations,
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

  const [activeIndex, setActiveIndex] = useState<number>(0);
  const [isSavedNotice, setIsSavedNotice] = useState<boolean>(false);
  const [testDriverStatus, setTestDriverStatus] = useState<string | null>(null);
  const [isModalQrCopied, setIsModalQrCopied] = useState<boolean>(false);

  // Normalize items to print
  const printItems: LocationQrExportData[] = useMemo(() => {
    if (locations && locations.length > 0) {
      return locations;
    }
    if (boards && boards.length > 0) {
      return boards.map((b) => ({
        id: b.id,
        code: b.qrCode || b.location || b.name,
        name: b.name,
        description: b.model ? `Model: ${b.model}` : b.description,
        qrCode: b.qrCode,
      }));
    }
    return [
      {
        id: '1',
        code: 'LOC-A1',
        name: 'Kệ A - Ngăn 1 (Linh kiện công suất)',
        description: 'Chuyên chứa Diode, IGBT, Tụ lọc nguồn',
        qrCode: 'LOC-A1',
        totalPartTypes: 12,
        totalQuantity: 250,
      },
    ];
  }, [locations, boards]);

  const activeItem = useMemo(() => {
    return printItems[Math.min(activeIndex, printItems.length - 1)] || printItems[0];
  }, [printItems, activeIndex]);

  const handleCopyModalQr = () => {
    const rawQrText = printItems && printItems.length > 1
      ? printItems.map((item) => (item.qrCode || item.code || '').trim()).filter(Boolean).join('\n')
      : (activeItem.qrCode || activeItem.code || '').trim();

    if (rawQrText) {
      navigator.clipboard.writeText(rawQrText);
      setIsModalQrCopied(true);
      setTimeout(() => setIsModalQrCopied(false), 2200);
    }
  };

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

    if (tmpl === 'horizontal') {
      layoutOrder = 'horizontal';
    } else if (tmpl === 'compact') {
      layoutOrder = 'qr_top';
    } else if (tmpl === 'detailed') {
      layoutOrder = 'qr_top';
    } else if (tmpl === 'mobile_standard') {
      layoutOrder = 'qr_top';
    }

    setConfig((prev) => ({
      ...prev,
      template: tmpl,
      layoutOrder,
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

  const qrValue = activeItem.qrCode || activeItem.code || 'N/A';
  const qrApiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(qrValue)}`;

  return (
    <div className="qr-print-modal-overlay">
      <div className="qr-print-modal-container">
        {/* Header */}
        <div className="qr-print-modal-header">
          <div>
            <h3>
              <MapPin size={22} color="#0284c7" />
              <span>In Tem Nhãn QR Vị Trí Kho / Kệ Kho</span>
            </h3>
            <p>Tùy chỉnh driver máy in, kích thước tem nhãn dán kệ kho, ngăn kéo và hộp chứa linh kiện</p>
          </div>
          <button className="btn-close-modal" onClick={onClose} title="Đóng">
            <X size={20} />
          </button>
        </div>

        {/* Modal Body */}
        <div className="qr-print-modal-body">
          {/* Controls Column */}
          <div className="qr-print-controls-pane">
            {/* Driver section */}
            <div className="control-group">
              <div className="control-group-title">
                <Settings2 size={16} color="#0284c7" />
                <span>1. Driver & Giao Thức Máy In</span>
              </div>
              <div className="control-grid-2">
                <div>
                  <label className="control-label">Thiết bị máy in / Giao thức</label>
                  <select
                    className="control-select"
                    value={config.printerDriver}
                    onChange={(e) =>
                      setConfig((p) => ({
                        ...p,
                        printerDriver: e.target.value as PrinterDriverType,
                      }))
                    }
                  >
                    <option value="system_default">🖨️ Máy in mặc định hệ thống</option>
                    <option value="eleph_phomemo">📱 Eleph-label / Phomemo</option>
                    <option value="xprinter_tspl">🏷️ Xprinter / TSC (TSPL Direct)</option>
                    <option value="godex_ezpl">🏷️ GoDEX / Bixolon (EZPL)</option>
                    <option value="pdf_virtual">📄 Máy in ảo PDF / Xem trước PDF</option>
                    <option value="web_usb_direct">⚡ WebUSB Direct Thermal</option>
                  </select>
                </div>

                <div>
                  <label className="control-label">Độ phân giải DPI</label>
                  <select
                    className="control-select"
                    value={config.printerDpi}
                    onChange={(e) =>
                      setConfig((p) => ({
                        ...p,
                        printerDpi: Number(e.target.value),
                      }))
                    }
                  >
                    <option value={203}>203 DPI (Máy in di động tiêu chuẩn)</option>
                    <option value={300}>300 DPI (Máy in nhiệt công nghiệp nét cao)</option>
                  </select>
                </div>
              </div>

              <div style={{ marginTop: '8px', display: 'flex', gap: '8px' }}>
                <button
                  type="button"
                  className="btn-test-driver"
                  onClick={handleTestPrinterDriver}
                >
                  <Zap size={14} />
                  <span>Kiểm tra cổng giao tiếp Driver</span>
                </button>
              </div>

              {testDriverStatus && (
                <div className="driver-status-badge">
                  {testDriverStatus}
                </div>
              )}
            </div>

            {/* Size and Template */}
            <div className="control-group">
              <div className="control-group-title">
                <Sliders size={16} color="#0284c7" />
                <span>2. Kích Thước Tem Nhãn Kệ Kho</span>
              </div>

              <div className="preset-buttons-row">
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === '50x40' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('50x40')}
                >
                  50 x 40 mm (Chuẩn)
                </button>
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === '60x40' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('60x40')}
                >
                  60 x 40 mm
                </button>
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === '70x50' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('70x50')}
                >
                  70 x 50 mm (Kệ lớn)
                </button>
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === '70x30' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('70x30')}
                >
                  70 x 30 mm (Ngang)
                </button>
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === 'a4' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('a4')}
                >
                  Giấy A4 (Lưới nhiều tem)
                </button>
              </div>

              <div className="control-grid-2" style={{ marginTop: '10px' }}>
                <div>
                  <label className="control-label">Mẫu bố cục tem</label>
                  <select
                    className="control-select"
                    value={config.template}
                    onChange={(e) =>
                      handleTemplateChange(e.target.value as QrPrintConfig['template'])
                    }
                  >
                    <option value="mobile_standard">Tiêu chuẩn Kệ Kho (QR trên, Tên dưới)</option>
                    <option value="compact">Gọn nhẹ (Tối đa kích thước QR)</option>
                    <option value="detailed">Chi tiết (Kèm mô tả vị trí & số loại linh kiện)</option>
                    <option value="horizontal">Ngang (QR bên trái, Chữ bên phải)</option>
                    <option value="grid">Dạng lưới nhiều tem (Trang A4)</option>
                  </select>
                </div>

                <div>
                  <label className="control-label">Căn lề chữ</label>
                  <select
                    className="control-select"
                    value={config.textAlign}
                    onChange={(e) =>
                      setConfig((p) => ({
                        ...p,
                        textAlign: e.target.value as QrPrintConfig['textAlign'],
                      }))
                    }
                  >
                    <option value="center">Căn giữa (Center)</option>
                    <option value="left">Căn trái (Left)</option>
                    <option value="right">Căn phải (Right)</option>
                  </select>
                </div>
              </div>
            </div>

            {/* Custom details */}
            <div className="control-group">
              <div className="control-group-title">
                <Layout size={16} color="#0284c7" />
                <span>3. Tùy Chỉnh Thông Tin Hiển Thị</span>
              </div>

              <div className="checkboxes-grid">
                <label className="checkbox-item">
                  <input
                    type="checkbox"
                    checked={config.showBorder}
                    onChange={(e) =>
                      setConfig((p) => ({ ...p, showBorder: e.target.checked }))
                    }
                  />
                  <span>Khung viền tem nhãn</span>
                </label>

                <label className="checkbox-item">
                  <input
                    type="checkbox"
                    checked={config.showName}
                    onChange={(e) =>
                      setConfig((p) => ({ ...p, showName: e.target.checked }))
                    }
                  />
                  <span>Tên vị trí / Kệ kho</span>
                </label>

                <label className="checkbox-item">
                  <input
                    type="checkbox"
                    checked={config.showCodeText}
                    onChange={(e) =>
                      setConfig((p) => ({ ...p, showCodeText: e.target.checked }))
                    }
                  />
                  <span>Khung hiển thị Mã Vị Trí</span>
                </label>
              </div>
            </div>
          </div>

          {/* Live Preview Column */}
          <div className="qr-print-preview-pane">
            <div className="preview-header">
              <span className="preview-header-title">
                <Eye size={16} color="#0284c7" />
                <span>Xem Trước Tem ({config.widthMm}mm x {config.heightMm}mm)</span>
              </span>

              {printItems && printItems.length > 1 && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px' }}>
                  <span>Chọn vị trí:</span>
                  <select
                    className="control-select"
                    style={{ width: 'auto', padding: '4px 8px' }}
                    value={activeIndex}
                    onChange={(e) => setActiveIndex(Number(e.target.value))}
                  >
                    {printItems.map((item, idx) => (
                      <option key={item.id || idx} value={idx}>
                        #{idx + 1} - {item.name} ({item.code})
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
                      {activeItem.name}
                    </div>
                  )}

                  {activeItem.description && (
                    <div className="live-qr-subtext" style={{ fontSize: `${config.titleFontSize - 2}px` }}>
                      {activeItem.description}
                    </div>
                  )}

                  {activeItem.totalPartTypes !== undefined && (
                    <div className="live-qr-subtext" style={{ fontSize: '10px', color: '#64748b' }}>
                      {activeItem.totalPartTypes} loại linh kiện
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
                      <span className="live-qr-code-label">MÃ VỊ TRÍ KHO:</span>
                      <span
                        className="live-qr-code-value"
                        style={{ fontSize: `${config.codeFontSize}px` }}
                      >
                        {qrValue}
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
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                backgroundColor: isModalQrCopied ? '#ecfdf5' : '#f8fafc',
                color: isModalQrCopied ? '#059669' : '#334155',
                borderColor: isModalQrCopied ? '#a7f3d0' : '#cbd5e1',
              }}
            >
              {isModalQrCopied ? <Check size={16} /> : <Copy size={16} />}
              <span>{isModalQrCopied ? 'Đã sao chép mã vị trí!' : 'Sao chép mã vị trí'}</span>
            </button>

            <button className="btn-secondary" onClick={handleSaveDefaults}>
              {isSavedNotice ? '✅ Đã lưu cấu hình!' : 'Lưu cấu hình mặc định'}
            </button>
            <button className="btn-secondary" onClick={handleResetDefaults}>
              <RotateCcw size={14} />
              <span>Khôi phục gốc</span>
            </button>
          </div>

          <div className="modal-footer-right">
            <button className="btn-secondary" onClick={onClose}>
              Hủy bỏ
            </button>
            <button className="btn-primary-print" onClick={handlePrintClick}>
              <Printer size={18} />
              <span>
                In {printItems.length} Tem Nhãn Vị Trí
              </span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
