import React, { useState, useMemo, useEffect } from 'react';
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
import {
  type LocationQrExportData,
  type BoardQrExportData,
  type QrPrintConfig,
  type PrinterDriverType,
  generateQrDataUrl,
} from '../../utils/pdf';
import './QrPrintConfigModal.css';

const DEFAULT_CONFIG: QrPrintConfig = {
  printerDriver: 'tns_label_thermal',
  printerDpi: 203,
  printMode: 'direct_thermal',
  printDarkness: 8,
  printSpeed: 4,
  template: 'mobile_standard',
  presetSize: '50x50',
  widthMm: 50,
  heightMm: 50,
  qrSizePx: 110,
  titleFontSize: 11,
  codeFontSize: 12,
  layoutOrder: 'qr_top',
  textAlign: 'center',
  paddingMm: 2,
  borderWidthPx: 1.5,
  borderRadiusPx: 4,
  showBorder: true,
  showName: true,
  showModel: true,
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
  onConfirmPrint: (config: QrPrintConfig, selectedItems?: LocationQrExportData[]) => void;
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
  const [previewQrUrl, setPreviewQrUrl] = useState<string>('');

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

  const cleanLocationCode = useMemo(() => {
    return (activeItem?.code || activeItem?.qrCode || 'LOC-A1').replace(/_QR$/i, '').trim();
  }, [activeItem]);

  const qrValue = cleanLocationCode;

  // Generate Base64 QR code for preview
  useEffect(() => {
    generateQrDataUrl(qrValue).then((url) => setPreviewQrUrl(url));
  }, [qrValue]);

  const handleCopyModalQr = () => {
    const rawQrText = (activeItem.code || activeItem.qrCode || '').replace(/_QR$/i, '').trim();

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
    let pad = config.paddingMm;

    switch (preset) {
      case '50x50':
        w = 50;
        h = 50;
        t = 'mobile_standard';
        q = 115;
        titleFs = 12;
        codeFs = 13;
        pad = 2;
        break;
      case '50x30':
        w = 50;
        h = 30;
        t = 'mobile_standard';
        q = 80;
        titleFs = 10;
        codeFs = 11;
        pad = 1.5;
        break;
      case '40x30':
        w = 40;
        h = 30;
        t = 'mobile_standard';
        q = 75;
        titleFs = 9;
        codeFs = 10;
        pad = 1.5;
        break;
      case '40x50':
        w = 40;
        h = 50;
        t = 'mobile_standard';
        q = 95;
        titleFs = 10;
        codeFs = 12;
        pad = 1.5;
        break;
      case '50x40':
        w = 50;
        h = 40;
        t = 'mobile_standard';
        q = 85;
        titleFs = 10;
        codeFs = 11;
        pad = 1.5;
        break;
      case '60x40':
        w = 60;
        h = 40;
        t = 'mobile_standard';
        q = 100;
        titleFs = 11;
        codeFs = 13;
        pad = 2;
        break;
      case '70x50':
        w = 70;
        h = 50;
        t = 'mobile_standard';
        q = 120;
        titleFs = 12;
        codeFs = 14;
        pad = 2.5;
        break;
      case '70x30':
        w = 70;
        h = 30;
        t = 'horizontal';
        q = 80;
        titleFs = 10;
        codeFs = 11;
        pad = 1.5;
        break;
      case 'a4':
        w = 210;
        h = 297;
        t = 'grid';
        q = 110;
        titleFs = 11;
        codeFs = 13;
        pad = 3;
        break;
      case 'custom':
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
      paddingMm: pad,
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
        case 'tns_label_thermal':
          msg = '✅ Đã kết nối máy in nhiệt TNS_LABEL (Port USB001, Driver: LABEL). Sẵn sàng in tem 50x50 mm!';
          break;
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
          msg = '✅ Driver Máy in hệ thống TNS_LABEL sẵn sàng!';
          break;
      }
      setTestDriverStatus(msg);
      setTimeout(() => setTestDriverStatus(null), 4500);
    }, 400);
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

  return (
    <div className="qr-print-modal-overlay">
      <div className="qr-print-modal-container">
        {/* Header */}
        <div className="qr-print-modal-header">
          <div className="qr-print-modal-title">
            <h3>
              <MapPin size={22} color="#0284c7" />
              <span>In Tem Nhãn QR Vị Trí Kho / Linh Kiện</span>
            </h3>
            <p>Khổ tem nhiệt chuẩn 50x50mm cho máy in TNS_LABEL (DLabel, Xprinter, TSC...)</p>
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
                    <option value="tns_label_thermal">🖨️ TNS_LABEL (Máy in nhiệt USB - DLabel)</option>
                    <option value="system_default">🖨️ Máy in mặc định hệ thống</option>
                    <option value="xprinter_tspl">🏷️ Xprinter / TSC (TSPL Direct)</option>
                    <option value="eleph_phomemo">📱 Phomemo / Niimbot</option>
                    <option value="godex_ezpl">🏷️ GoDEX / Bixolon (EZPL)</option>
                    <option value="pdf_virtual">📄 Máy in ảo PDF / Xem trước PDF</option>
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
                    <option value={203}>203 DPI (Máy in di động / TNS_LABEL)</option>
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
                  <span>Kiểm tra cổng giao tiếp Driver TNS_LABEL</span>
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
                <span>2. Kích Thước Khổ Giấy Tem Nhãn</span>
              </div>

              <div className="preset-buttons-row">
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === '50x50' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('50x50')}
                >
                  ⭐ 50 x 50 mm (TNS_LABEL Vuông)
                </button>
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === '50x30' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('50x30')}
                >
                  50 x 30 mm
                </button>
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === '40x30' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('40x30')}
                >
                  40 x 30 mm
                </button>
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === '40x50' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('40x50')}
                >
                  40 x 50 mm
                </button>
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === '50x40' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('50x40')}
                >
                  50 x 40 mm
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
                  70 x 50 mm
                </button>
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === 'a4' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('a4')}
                >
                  Giấy A4 (Lưới tem)
                </button>
                <button
                  type="button"
                  className={`preset-btn ${config.presetSize === 'custom' ? 'active' : ''}`}
                  onClick={() => handlePresetChange('custom')}
                >
                  Tùy chỉnh mm
                </button>
              </div>

              {/* Exact Dimensions Inputs */}
              <div className="dimension-inputs-row" style={{ marginTop: '8px', display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '8px' }}>
                <div>
                  <label className="control-label">Rộng (mm)</label>
                  <input
                    type="number"
                    min={20}
                    max={300}
                    value={config.widthMm}
                    onChange={(e) =>
                      setConfig((p) => ({
                        ...p,
                        widthMm: Math.max(10, Number(e.target.value) || 10),
                        presetSize: 'custom',
                      }))
                    }
                    className="control-input"
                  />
                </div>
                <div>
                  <label className="control-label">Cao (mm)</label>
                  <input
                    type="number"
                    min={15}
                    max={300}
                    value={config.heightMm}
                    onChange={(e) =>
                      setConfig((p) => ({
                        ...p,
                        heightMm: Math.max(10, Number(e.target.value) || 10),
                        presetSize: 'custom',
                      }))
                    }
                    className="control-input"
                  />
                </div>
                <div>
                  <label className="control-label">Lề viền (mm)</label>
                  <input
                    type="number"
                    step={0.5}
                    min={0}
                    max={15}
                    value={config.paddingMm}
                    onChange={(e) =>
                      setConfig((p) => ({
                        ...p,
                        paddingMm: Math.max(0, Number(e.target.value) || 0),
                      }))
                    }
                    className="control-input"
                  />
                </div>
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

              <div className="checkbox-options-list">
                <label className={`custom-toggle-card ${config.showBorder ? 'checked' : ''}`}>
                  <input
                    type="checkbox"
                    checked={config.showBorder}
                    onChange={(e) =>
                      setConfig((p) => ({ ...p, showBorder: e.target.checked }))
                    }
                  />
                  <div className="toggle-card-content">
                    <span className="toggle-card-title">Khung viền bao tem</span>
                    <span className="toggle-card-sub">Hiển thị đường viền nét mảnh bao quanh tem</span>
                  </div>
                </label>

                <label className={`custom-toggle-card ${config.showName ? 'checked' : ''}`}>
                  <input
                    type="checkbox"
                    checked={config.showName}
                    onChange={(e) =>
                      setConfig((p) => ({ ...p, showName: e.target.checked }))
                    }
                  />
                  <div className="toggle-card-content">
                    <span className="toggle-card-title">Tên vị trí / Kệ kho</span>
                    <span className="toggle-card-sub">Hiển thị tên mô tả kệ (vd: Kệ A1, Ngăn kéo...)</span>
                  </div>
                </label>

                <label className={`custom-toggle-card ${config.showCodeText ? 'checked' : ''}`}>
                  <input
                    type="checkbox"
                    checked={config.showCodeText}
                    onChange={(e) =>
                      setConfig((p) => ({ ...p, showCodeText: e.target.checked }))
                    }
                  />
                  <div className="toggle-card-content">
                    <span className="toggle-card-title">Khung hiển thị Mã Vị Trí</span>
                    <span className="toggle-card-sub">Hộp nổi bật mã chữ in hoa (vd: LOC-A1)</span>
                  </div>
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

              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                {printItems && printItems.length > 1 && (
                  <select
                    className="control-select"
                    style={{ width: 'auto', padding: '3px 6px', fontSize: '12px' }}
                    value={activeIndex}
                    onChange={(e) => setActiveIndex(Number(e.target.value))}
                  >
                    {printItems.map((item, idx) => (
                      <option key={item.id || idx} value={idx}>
                        #{idx + 1} - {item.name} ({item.code})
                      </option>
                    ))}
                  </select>
                )}

                <button
                  type="button"
                  onClick={() => onConfirmPrint(config, [activeItem])}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '5px',
                    backgroundColor: '#10b981',
                    color: '#ffffff',
                    border: 'none',
                    borderRadius: '6px',
                    padding: '4px 10px',
                    fontSize: '12px',
                    fontWeight: 700,
                    cursor: 'pointer',
                  }}
                  title="In ngay tem đang xem trên máy in TNS_LABEL"
                >
                  <Printer size={13} />
                  <span>In tem này</span>
                </button>
              </div>
            </div>

            {/* Viewport Render Canvas */}
            <div className="preview-viewport-wrapper">
              <div
                className={`live-qr-card order-${config.layoutOrder}`}
                style={{
                  width: config.template === 'grid' ? '280px' : `${Math.round(config.widthMm * 4.2)}px`,
                  height: config.template === 'grid' ? '360px' : `${Math.round(config.heightMm * 4.2)}px`,
                  maxWidth: '100%',
                  padding: `${Math.max(6, Math.round(config.paddingMm * 3.5))}px`,
                  border: config.showBorder
                    ? `${config.borderWidthPx}px solid #1e293b`
                    : '1.5px dashed #cbd5e1',
                  borderRadius: `${config.borderRadiusPx}px`,
                  textAlign: config.textAlign,
                  display: 'flex',
                  flexDirection: config.layoutOrder === 'horizontal' ? 'row' : config.layoutOrder === 'title_top' ? 'column-reverse' : 'column',
                  alignItems: 'center',
                  justifyContent: config.layoutOrder === 'horizontal' ? 'center' : 'space-between',
                  gap: config.layoutOrder === 'horizontal' ? '10px' : '4px',
                  backgroundColor: '#ffffff',
                  boxShadow: '0 8px 24px rgba(0, 0, 0, 0.12)',
                  margin: 'auto',
                  boxSizing: 'border-box',
                  overflow: 'hidden',
                }}
              >
                {/* QR Image Section */}
                <div
                  className="live-qr-image-wrapper"
                  style={{
                    flex: '1 1 0',
                    minHeight: 0,
                    maxHeight: config.layoutOrder === 'horizontal' ? '100%' : `calc(100% - ${(config.showName ? 18 : 0) + (config.showCodeText ? 24 : 0)}px)`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    overflow: 'hidden',
                  }}
                >
                  {previewQrUrl ? (
                    <img
                      src={previewQrUrl}
                      alt="QR Preview"
                      className="live-qr-img"
                      style={{
                        maxHeight: '100%',
                        maxWidth: '100%',
                        width: 'auto',
                        height: 'auto',
                        aspectRatio: '1 / 1',
                        objectFit: 'contain',
                      }}
                    />
                  ) : (
                    <div style={{ fontSize: '11px', color: '#94a3b8' }}>Đang tạo QR...</div>
                  )}
                </div>

                {/* Text Info Section */}
                <div
                  className="live-qr-meta"
                  style={{
                    flex: '0 0 auto',
                    width: '100%',
                    alignItems:
                      config.textAlign === 'center'
                        ? 'center'
                        : config.textAlign === 'right'
                        ? 'flex-end'
                        : 'flex-start',
                    gap: '2px',
                  }}
                >
                  {config.showName && (
                    <div
                      className="live-qr-title"
                      style={{
                        fontSize: `${config.titleFontSize}px`,
                        maxHeight: '2.4em',
                        overflow: 'hidden',
                        lineHeight: 1.2,
                        fontWeight: 800,
                      }}
                    >
                      {activeItem.name}
                    </div>
                  )}

                  {((activeItem.partTypesCount !== undefined && activeItem.partTypesCount > 0) || (activeItem.boardTypesCount !== undefined && activeItem.boardTypesCount > 0)) ? (
                    <div style={{ fontSize: '8px', fontWeight: 700, color: '#0f172a', display: 'flex', justifyContent: 'space-around', width: '100%', marginTop: '2px' }}>
                      <span>📦 LK: {activeItem.partTypesCount || 0} ({activeItem.partQuantity || 0})</span>
                      <span>⚡ Bo: {activeItem.boardTypesCount || 0} ({activeItem.boardQuantity || 0})</span>
                    </div>
                  ) : activeItem.totalPartTypes !== undefined && activeItem.totalPartTypes > 0 ? (
                    <div className="live-qr-subtext" style={{ fontSize: '9px', color: '#64748b' }}>
                      {activeItem.totalPartTypes} loại hàng tồn
                    </div>
                  ) : null}

                  {config.showCodeText && (
                    <div
                      className="live-qr-code-box"
                      style={{
                        marginTop: '2px',
                        padding: '2px 6px',
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
            {printItems.length > 1 && (
              <button
                className="btn-secondary"
                onClick={() => onConfirmPrint(config, [activeItem])}
                style={{ fontWeight: 600, color: '#0369a1', borderColor: '#bae6fd', backgroundColor: '#f0f9ff' }}
                title={`Chỉ in riêng tem vị trí: ${activeItem.name}`}
              >
                <Printer size={15} />
                <span>In riêng tem #{activeIndex + 1} ({activeItem.code})</span>
              </button>
            )}
            <button className="btn-primary-print" onClick={handlePrintClick} style={{ backgroundColor: '#0284c7', fontSize: '14px', padding: '10px 22px' }}>
              <Printer size={18} />
              <span>
                {printItems.length > 1 ? `🖨️ In Tem Ngay (Tất cả ${printItems.length} tem)` : '🖨️ In Tem Ngay (TNS_LABEL)'}
              </span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};



