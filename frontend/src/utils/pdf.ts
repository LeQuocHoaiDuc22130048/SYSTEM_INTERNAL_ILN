import QRCode from 'qrcode';

export interface LocationQrExportData {
  id: string;
  code: string;
  name: string;
  qrCode?: string;
  description?: string;
  totalPartTypes?: number;
  totalQuantity?: number;
  partTypesCount?: number;
  partQuantity?: number;
  boardTypesCount?: number;
  boardQuantity?: number;
}

export interface BoardQrExportData {
  id: string;
  name: string;
  qrCode: string;
  model?: string;
  location?: string;
  serialNumber?: string;
  description?: string;
}

export type PrinterDriverType =
  | 'tns_label_thermal'
  | 'system_default'
  | 'eleph_phomemo'
  | 'xprinter_tspl'
  | 'godex_ezpl'
  | 'pdf_virtual'
  | 'web_usb_direct';

export interface QrPrintConfig {
  printerDriver: PrinterDriverType;
  printerDpi: number;
  printMode: 'direct_thermal' | 'thermal_transfer' | 'die_cut' | 'continuous';
  printDarkness: number;
  printSpeed: number;
  template: 'mobile_standard' | 'compact' | 'detailed' | 'horizontal' | 'grid';
  presetSize: '50x50' | '50x30' | '40x30' | '50x40' | '40x50' | '40x40' | '60x40' | '70x50' | '70x30' | 'a4' | 'custom';
  widthMm: number;
  heightMm: number;
  qrSizePx: number;
  titleFontSize: number;
  codeFontSize: number;
  layoutOrder: 'qr_top' | 'title_top' | 'horizontal';
  textAlign: 'center' | 'left' | 'right';
  paddingMm: number;
  borderWidthPx: number;
  borderRadiusPx: number;
  showBorder: boolean;
  showName: boolean;
  showModel: boolean;
  showLocation: boolean;
  showCodeText: boolean;
  showSerialNumber: boolean;
  customHeaderTitle?: string;
}

export const DEFAULT_QR_PRINT_CONFIG: QrPrintConfig = {
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

/**
 * Returns raw QR code key identifier string for clipboard copying
 */
export function formatBoardTextForCopy(
  board: BoardQrExportData
): string {
  if (!board) return '';
  return (board.qrCode || board.id || board.name || '').trim();
}

/**
 * Helper creating invisible print iframe for direct page printing without new tab
 */
function getOrCreatePrintIframe(): HTMLIFrameElement {
  let iframe = document.getElementById('hidden-qr-print-iframe') as HTMLIFrameElement;
  if (!iframe) {
    iframe = document.createElement('iframe');
    iframe.id = 'hidden-qr-print-iframe';
    iframe.style.position = 'fixed';
    iframe.style.right = '0';
    iframe.style.bottom = '0';
    iframe.style.width = '0px';
    iframe.style.height = '0px';
    iframe.style.border = '0px';
    iframe.style.opacity = '0';
    iframe.style.pointerEvents = 'none';
    iframe.style.zIndex = '-9999';
    document.body.appendChild(iframe);
  }
  return iframe;
}

/**
 * Generate QR code as pure Vector SVG string
 */
export async function generateQrSvg(value: string): Promise<string> {
  try {
    const rawSvg = await QRCode.toString(value, {
      type: 'svg',
      errorCorrectionLevel: 'M',
      margin: 1,
      color: {
        dark: '#000000',
        light: '#ffffff',
      },
    });
    return rawSvg.replace(
      '<svg ',
      '<svg class="qr-svg-item" style="width: 100%; height: 100%; max-height: 100%; max-width: 100%; aspect-ratio: 1/1; object-fit: contain;" '
    );
  } catch (err) {
    console.error('Lỗi tạo QR SVG:', err);
    return `<img src="https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(value)}" class="qr-image" style="max-width: 100%; max-height: 100%; object-fit: contain;" />`;
  }
}

/**
 * Generate QR code as Base64 Data URL (for preview)
 */
export async function generateQrDataUrl(value: string): Promise<string> {
  try {
    return await QRCode.toDataURL(value, {
      errorCorrectionLevel: 'M',
      margin: 1,
      width: 320,
      color: {
        dark: '#000000',
        light: '#ffffff',
      },
    });
  } catch (err) {
    console.error('Lỗi tạo QR Data URL:', err);
    return `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(value)}`;
  }
}

/**
 * Single location QR printing helper
 */
export async function exportLocationQrPdf(location: LocationQrExportData, config?: QrPrintConfig): Promise<void> {
  await exportLocationQrPdfList([location], `Tem_QR_ViTri_${location.code}`, config);
}

/**
 * Export and print Location QR codes with custom size, template, and formatting.
 */
export async function exportLocationQrPdfList(
  locations: LocationQrExportData[],
  filename = 'Danh_sach_tem_QR_vi_tri_kho',
  config: QrPrintConfig = DEFAULT_QR_PRINT_CONFIG
): Promise<void> {
  if (!locations || locations.length === 0) return;

  const isGridMode = config.template === 'grid' || config.presetSize === 'a4';
  const isHorizontal = config.layoutOrder === 'horizontal' || config.template === 'horizontal';

  // Generate Vector SVGs with clean location code (no _QR suffix)
  const qrSvgs = await Promise.all(
    locations.map((loc) => {
      const cleanCode = (loc.code || loc.qrCode || 'N/A').replace(/_QR$/i, '').trim();
      return generateQrSvg(cleanCode);
    })
  );

  const cardsHtml = locations
    .map((loc, index) => {
      const cleanCode = (loc.code || loc.qrCode || 'N/A').replace(/_QR$/i, '').trim();
      const qrSvg = qrSvgs[index];

      const textAlignCss = config.textAlign;
      const alignItemCss =
        textAlignCss === 'center'
          ? 'center'
          : textAlignCss === 'right'
          ? 'flex-end'
          : 'flex-start';

      return `
        <div class="qr-card">
          ${
            config.showName && loc.name
              ? `<div class="qr-title">${escapeHtml(loc.name)}</div>`
              : ''
          }
          <div class="qr-image-wrapper">
            ${qrSvg}
          </div>
          <div class="qr-info-meta" style="align-items: ${alignItemCss}; text-align: ${textAlignCss};">
            ${
              config.showCodeText
                ? `
                <div class="qr-code-box">
                  <span class="qr-code-label">VỊ TRÍ KHO:</span>
                  <span class="qr-code-text">${escapeHtml(cleanCode)}</span>
                </div>
              `
                : ''
            }
            ${
              (loc.partTypesCount !== undefined && loc.partTypesCount > 0) || (loc.boardTypesCount !== undefined && loc.boardTypesCount > 0)
                ? `<div class="qr-stats-row" style="font-size: 8px; font-weight: 700; color: #000; display: flex; justify-content: space-around; width: 100%; margin-top: 1px;">
                    <span>📦 LK: ${loc.partTypesCount || 0} (${loc.partQuantity || 0})</span>
                    <span>⚡ Bo: ${loc.boardTypesCount || 0} (${loc.boardQuantity || 0})</span>
                  </div>`
                : loc.totalPartTypes !== undefined && loc.totalPartTypes > 0
                ? `<div class="qr-subtext" style="font-size: 8px; color: #000; font-weight: 600;">${loc.totalPartTypes} loại hàng tồn</div>`
                : ''
            }
          </div>
        </div>
      `;
    })
    .join('');

  const htmlContent = `
    <!DOCTYPE html>
    <html lang="vi">
    <head>
      <meta charset="UTF-8">
      <title>${escapeHtml(filename)}</title>
      <style>
        @page {
          size: ${isGridMode ? 'A4 portrait' : `${config.widthMm}mm ${config.heightMm}mm`};
          margin: 0mm !important;
        }
        *, *::before, *::after {
          box-sizing: border-box !important;
          margin: 0;
          padding: 0;
          -webkit-print-color-adjust: exact !important;
          print-color-adjust: exact !important;
        }
        html, body {
          background: #ffffff !important;
          color: #0f172a !important;
          margin: 0 !important;
          padding: 0 !important;
          width: 100% !important;
          height: 100% !important;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
          overflow: hidden !important;
        }
        .page-header {
          text-align: center;
          margin: 10px;
          padding: 10px;
          background: #f8fafc;
          border-radius: 8px;
          border: 1px solid #cbd5e1;
        }
        .page-header h2 {
          font-size: 15px;
          color: #0f172a;
          text-transform: uppercase;
        }
        .page-header p {
          font-size: 12px;
          color: #64748b;
          margin-top: 4px;
        }
        .action-btns {
          margin-top: 8px;
          display: flex;
          gap: 8px;
          justify-content: center;
        }
        .btn-print {
          background: #0284c7;
          color: white;
          border: none;
          padding: 8px 18px;
          font-size: 13px;
          font-weight: 600;
          border-radius: 6px;
          cursor: pointer;
        }
        .btn-close {
          background: #64748b;
          color: white;
          border: none;
          padding: 8px 16px;
          font-size: 13px;
          border-radius: 6px;
          cursor: pointer;
        }

        .cards-container {
          ${
            isGridMode
              ? `
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(60mm, 1fr));
                gap: 8px;
                padding: 8mm;
                justify-items: center;
              `
              : `
                display: block;
                padding: 0;
                margin: 0;
                width: 100%;
                height: 100%;
              `
          }
        }

        .qr-card {
          width: ${isGridMode ? '60mm' : `${config.widthMm}mm`} !important;
          height: ${isGridMode ? 'auto' : `${config.heightMm}mm`} !important;
          max-width: ${isGridMode ? 'none' : `${config.widthMm}mm`} !important;
          max-height: ${isGridMode ? 'none' : `${config.heightMm}mm`} !important;
          padding: ${config.paddingMm}mm !important;
          background: #ffffff !important;
          border: ${
            config.showBorder
              ? `${config.borderWidthPx}px solid #000000`
              : 'none'
          } !important;
          border-radius: ${config.borderRadiusPx}px !important;
          display: flex !important;
          flex-direction: ${
            isHorizontal
              ? 'row'
              : config.layoutOrder === 'title_top'
              ? 'column-reverse'
              : 'column'
          } !important;
          align-items: center !important;
          justify-content: ${isHorizontal ? 'center' : 'space-between'} !important;
          gap: ${isHorizontal ? '6px' : '2px'} !important;
          page-break-inside: avoid !important;
          break-inside: avoid !important;
          page-break-after: avoid !important;
          break-after: avoid !important;
          box-sizing: border-box !important;
          overflow: hidden !important;
          margin: 0 auto !important;
        }

        .qr-card + .qr-card {
          page-break-before: always !important;
          break-before: page !important;
        }

        .qr-image-wrapper {
          display: flex !important;
          justify-content: center !important;
          align-items: center !important;
          flex: 1 1 0 !important;
          min-height: 0 !important;
          min-width: 0 !important;
          width: 100% !important;
          height: 0 !important;
          overflow: hidden !important;
        }

        .qr-svg-item {
          width: 100% !important;
          height: 100% !important;
          max-width: 100% !important;
          max-height: 100% !important;
          aspect-ratio: 1 / 1 !important;
          object-fit: contain !important;
          display: block !important;
        }

        .qr-info-meta {
          display: flex !important;
          flex-direction: column !important;
          width: 100% !important;
          flex: 0 0 auto !important;
          gap: 1px !important;
        }

        .qr-title {
          font-size: ${config.titleFontSize}px !important;
          font-weight: 800 !important;
          color: #000000 !important;
          line-height: 1.15 !important;
          word-break: break-word !important;
          max-height: 2.3em !important;
          overflow: hidden !important;
        }

        .qr-subtext {
          font-size: ${Math.max(7, config.titleFontSize - 3)}px !important;
          color: #1e293b !important;
          line-height: 1.1 !important;
          white-space: nowrap !important;
          text-overflow: ellipsis !important;
          overflow: hidden !important;
        }

        .qr-code-box {
          display: flex !important;
          flex-direction: column !important;
          align-items: center !important;
          justify-content: center !important;
          background: #f8fafc !important;
          border: 1px solid #000000 !important;
          border-radius: 3px !important;
          padding: 1px 4px !important;
          margin-top: 1px !important;
          width: 100% !important;
          box-sizing: border-box !important;
        }

        .qr-code-label {
          font-size: 7px !important;
          font-weight: 700 !important;
          color: #475569 !important;
          letter-spacing: 0.3px !important;
          line-height: 1 !important;
        }

        .qr-code-text {
          font-family: "Courier New", Courier, monospace !important;
          font-size: ${config.codeFontSize}px !important;
          font-weight: 900 !important;
          color: #000000 !important;
          letter-spacing: 0.5px !important;
          line-height: 1.1 !important;
          word-break: break-all !important;
          text-align: center !important;
        }

        @media print {
          .no-print {
            display: none !important;
          }
          html, body {
            background: #ffffff !important;
            padding: 0 !important;
            margin: 0 !important;
            width: ${isGridMode ? '210mm' : `${config.widthMm}mm`} !important;
            height: ${isGridMode ? 'auto' : `${config.heightMm}mm`} !important;
            overflow: hidden !important;
          }
          .cards-container {
            padding: 0 !important;
            margin: 0 !important;
          }
          .qr-card {
            box-shadow: none !important;
          }
        }
      </style>
    </head>
    <body>
      ${
        config.printerDriver === 'pdf_virtual'
          ? `
        <div class="page-header no-print">
          <h2>IN TEM NHÃN QR VỊ TRÍ KHO</h2>
          <p>Kích thước: <strong>${config.widthMm}mm x ${config.heightMm}mm</strong> | Mẫu: <strong>${config.template}</strong></p>
          <div class="action-btns">
            <button class="btn-print" onclick="window.print()">
              🖨️ In Tem / Lưu PDF
            </button>
            <button class="btn-close" onclick="window.close()">
              Đóng
            </button>
          </div>
        </div>
      `
          : ''
      }

      <div class="cards-container">
        ${cardsHtml}
      </div>
    </body>
    </html>
  `;

  // Virtual PDF Driver: Open window if requested
  if (config.printerDriver === 'pdf_virtual') {
    const printWindow = window.open('', '_blank');
    if (!printWindow) {
      alert('Vui lòng cho phép popup trình duyệt để xem file PDF tem nhãn');
      return;
    }
    printWindow.document.open();
    printWindow.document.write(htmlContent);
    printWindow.document.close();
    return;
  }

  // Hardware/device/system drivers: Print directly via hidden iframe without opening new tab
  const iframe = getOrCreatePrintIframe();
  const doc = iframe.contentWindow?.document || iframe.contentDocument;
  if (!doc) return;

  doc.open();
  doc.write(htmlContent);
  doc.close();

  setTimeout(() => {
    try {
      iframe.contentWindow?.focus();
      iframe.contentWindow?.print();
    } catch (e) {
      console.error('Lỗi khi kích hoạt lệnh in trực tiếp:', e);
    }
  }, 300);
}

/**
 * Single board QR printing helper
 */
export async function exportBoardQrPdf(board: BoardQrExportData, config?: QrPrintConfig): Promise<void> {
  await exportBoardQrPdfList([board], `Tem_QR_${board.qrCode || board.name}`, config);
}

/**
 * Export and print board QR codes (legacy compatibility)
 */
export async function exportBoardQrPdfList(
  boards: BoardQrExportData[],
  filename = 'Danh_sach_tem_QR_bo_mach',
  config: QrPrintConfig = DEFAULT_QR_PRINT_CONFIG
): Promise<void> {
  if (!boards || boards.length === 0) return;

  const isGridMode = config.template === 'grid' || config.presetSize === 'a4';
  const isHorizontal = config.layoutOrder === 'horizontal' || config.template === 'horizontal';

  // Generate Vector SVGs
  const qrSvgs = await Promise.all(
    boards.map((b) => generateQrSvg(b.qrCode || b.id || b.name || 'N/A'))
  );

  const cardsHtml = boards
    .map((b, index) => {
      const qrCodeVal = b.qrCode || 'N/A';
      const qrSvg = qrSvgs[index];

      const textAlignCss = config.textAlign;
      const alignItemCss =
        textAlignCss === 'center'
          ? 'center'
          : textAlignCss === 'right'
          ? 'flex-end'
          : 'flex-start';

      return `
        <div class="qr-card">
          <div class="qr-image-wrapper">
            ${qrSvg}
          </div>
          <div class="qr-info-meta" style="align-items: ${alignItemCss}; text-align: ${textAlignCss};">
            ${
              config.showName && b.name
                ? `<div class="qr-title">${escapeHtml(b.name)}</div>`
                : ''
            }
            ${
              config.showModel && b.model
                ? `<div class="qr-subtext">Model: <strong>${escapeHtml(b.model)}</strong></div>`
                : ''
            }
            ${
              config.showLocation && b.location
                ? `<div class="qr-subtext">Vị trí: <strong>${escapeHtml(b.location)}</strong></div>`
                : ''
            }
            ${
              config.showSerialNumber && b.serialNumber
                ? `<div class="qr-subtext">S/N: ${escapeHtml(b.serialNumber)}</div>`
                : ''
            }
            ${
              config.showCodeText
                ? `
                <div class="qr-code-box">
                  <span class="qr-code-label">MÃ CODE QR:</span>
                  <span class="qr-code-text">${escapeHtml(qrCodeVal)}</span>
                </div>
              `
                : ''
            }
          </div>
        </div>
      `;
    })
    .join('');

  const htmlContent = `
    <!DOCTYPE html>
    <html lang="vi">
    <head>
      <meta charset="UTF-8">
      <title>${escapeHtml(filename)}</title>
      <style>
        @page {
          size: ${isGridMode ? 'A4 portrait' : `${config.widthMm}mm ${config.heightMm}mm`};
          margin: 0mm !important;
        }
        *, *::before, *::after {
          box-sizing: border-box !important;
          margin: 0;
          padding: 0;
          -webkit-print-color-adjust: exact !important;
          print-color-adjust: exact !important;
        }
        html, body {
          background: #ffffff !important;
          color: #0f172a !important;
          margin: 0 !important;
          padding: 0 !important;
          width: 100% !important;
          height: 100% !important;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
          overflow: hidden !important;
        }
        .page-header {
          text-align: center;
          margin: 10px;
          padding: 10px;
          background: #f8fafc;
          border-radius: 8px;
          border: 1px solid #cbd5e1;
        }
        .page-header h2 {
          font-size: 15px;
          color: #0f172a;
          text-transform: uppercase;
        }
        .page-header p {
          font-size: 12px;
          color: #64748b;
          margin-top: 4px;
        }
        .action-btns {
          margin-top: 8px;
          display: flex;
          gap: 8px;
          justify-content: center;
        }
        .btn-print {
          background: #0284c7;
          color: white;
          border: none;
          padding: 8px 18px;
          font-size: 13px;
          font-weight: 600;
          border-radius: 6px;
          cursor: pointer;
        }
        .btn-close {
          background: #64748b;
          color: white;
          border: none;
          padding: 8px 16px;
          font-size: 13px;
          border-radius: 6px;
          cursor: pointer;
        }

        .cards-container {
          ${
            isGridMode
              ? `
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(60mm, 1fr));
                gap: 8px;
                padding: 8mm;
                justify-items: center;
              `
              : `
                display: block;
                padding: 0;
                margin: 0;
                width: 100%;
                height: 100%;
              `
          }
        }

        .qr-card {
          width: ${isGridMode ? '60mm' : `${config.widthMm}mm`} !important;
          height: ${isGridMode ? 'auto' : `${config.heightMm}mm`} !important;
          max-width: ${isGridMode ? 'none' : `${config.widthMm}mm`} !important;
          max-height: ${isGridMode ? 'none' : `${config.heightMm}mm`} !important;
          padding: ${config.paddingMm}mm !important;
          background: #ffffff !important;
          border: ${
            config.showBorder
              ? `${config.borderWidthPx}px solid #000000`
              : 'none'
          } !important;
          border-radius: ${config.borderRadiusPx}px !important;
          display: flex !important;
          flex-direction: ${
            isHorizontal
              ? 'row'
              : config.layoutOrder === 'title_top'
              ? 'column-reverse'
              : 'column'
          } !important;
          align-items: center !important;
          justify-content: ${isHorizontal ? 'center' : 'space-between'} !important;
          gap: ${isHorizontal ? '6px' : '2px'} !important;
          page-break-inside: avoid !important;
          break-inside: avoid !important;
          page-break-after: avoid !important;
          break-after: avoid !important;
          box-sizing: border-box !important;
          overflow: hidden !important;
          margin: 0 auto !important;
        }

        .qr-card + .qr-card {
          page-break-before: always !important;
          break-before: page !important;
        }

        .qr-image-wrapper {
          display: flex !important;
          justify-content: center !important;
          align-items: center !important;
          flex: 1 1 0 !important;
          min-height: 0 !important;
          min-width: 0 !important;
          width: 100% !important;
          height: 0 !important;
          overflow: hidden !important;
        }

        .qr-svg-item {
          width: 100% !important;
          height: 100% !important;
          max-width: 100% !important;
          max-height: 100% !important;
          aspect-ratio: 1 / 1 !important;
          object-fit: contain !important;
          display: block !important;
        }

        .qr-info-meta {
          display: flex !important;
          flex-direction: column !important;
          width: 100% !important;
          flex: 0 0 auto !important;
          gap: 1px !important;
        }

        .qr-title {
          font-size: ${config.titleFontSize}px !important;
          font-weight: 800 !important;
          color: #000000 !important;
          line-height: 1.15 !important;
          word-break: break-word !important;
          max-height: 2.3em !important;
          overflow: hidden !important;
        }

        .qr-subtext {
          font-size: ${Math.max(7, config.titleFontSize - 3)}px !important;
          color: #1e293b !important;
          line-height: 1.1 !important;
          white-space: nowrap !important;
          text-overflow: ellipsis !important;
          overflow: hidden !important;
        }

        .qr-code-box {
          display: flex !important;
          flex-direction: column !important;
          align-items: center !important;
          justify-content: center !important;
          background: #f8fafc !important;
          border: 1px solid #000000 !important;
          border-radius: 3px !important;
          padding: 1px 4px !important;
          margin-top: 1px !important;
          width: 100% !important;
          box-sizing: border-box !important;
        }

        .qr-code-label {
          font-size: 7px !important;
          font-weight: 700 !important;
          color: #475569 !important;
          letter-spacing: 0.3px !important;
          line-height: 1 !important;
        }

        .qr-code-text {
          font-family: "Courier New", Courier, monospace !important;
          font-size: ${config.codeFontSize}px !important;
          font-weight: 900 !important;
          color: #000000 !important;
          letter-spacing: 0.5px !important;
          line-height: 1.1 !important;
          word-break: break-all !important;
          text-align: center !important;
        }

        @media print {
          .no-print {
            display: none !important;
          }
          html, body {
            background: #ffffff !important;
            padding: 0 !important;
            margin: 0 !important;
            width: ${isGridMode ? '210mm' : `${config.widthMm}mm`} !important;
            height: ${isGridMode ? 'auto' : `${config.heightMm}mm`} !important;
            overflow: hidden !important;
          }
          .cards-container {
            padding: 0 !important;
            margin: 0 !important;
          }
          .qr-card {
            box-shadow: none !important;
          }
        }
      </style>
    </head>
    <body>
      ${
        config.printerDriver === 'pdf_virtual'
          ? `
        <div class="page-header no-print">
          <h2>IN TEM NHÃN KHO BO MẠCH</h2>
          <p>Kích thước: <strong>${config.widthMm}mm x ${config.heightMm}mm</strong> | Mẫu: <strong>${config.template}</strong></p>
          <div class="action-btns">
            <button class="btn-print" onclick="window.print()">
              🖨️ In Tem / Lưu PDF
            </button>
            <button class="btn-close" onclick="window.close()">
              Đóng
            </button>
          </div>
        </div>
      `
          : ''
      }

      <div class="cards-container">
        ${cardsHtml}
      </div>
    </body>
    </html>
  `;


  // Virtual PDF Driver: Open window if requested
  if (config.printerDriver === 'pdf_virtual') {
    const printWindow = window.open('', '_blank');
    if (!printWindow) {
      alert('Vui lòng cho phép popup trình duyệt để xem file PDF tem nhãn');
      return;
    }
    printWindow.document.open();
    printWindow.document.write(htmlContent);
    printWindow.document.close();
    return;
  }

  // Hardware/device/system drivers: Print directly via hidden iframe without opening new tab
  const iframe = getOrCreatePrintIframe();
  const doc = iframe.contentWindow?.document || iframe.contentDocument;
  if (!doc) return;

  doc.open();
  doc.write(htmlContent);
  doc.close();

  setTimeout(() => {
    try {
      iframe.contentWindow?.focus();
      iframe.contentWindow?.print();
    } catch (e) {
      console.error('Lỗi khi kích hoạt lệnh in trực tiếp:', e);
    }
  }, 300);
}

function escapeHtml(str: string): string {
  if (!str) return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}


