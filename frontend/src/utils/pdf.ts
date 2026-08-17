export interface LocationQrExportData {
  id: string;
  code: string;
  name: string;
  qrCode?: string;
  description?: string;
  totalPartTypes?: number;
  totalQuantity?: number;
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
  presetSize: '50x40' | '60x40' | '70x50' | '70x30' | 'a4' | 'custom';
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
  printerDriver: 'system_default',
  printerDpi: 203,
  printMode: 'direct_thermal',
  printDarkness: 8,
  printSpeed: 4,
  template: 'mobile_standard',
  presetSize: '50x40',
  widthMm: 50,
  heightMm: 40,
  qrSizePx: 110,
  titleFontSize: 11,
  codeFontSize: 13,
  layoutOrder: 'qr_top',
  textAlign: 'center',
  paddingMm: 3,
  borderWidthPx: 1.5,
  borderRadiusPx: 8,
  showBorder: true,
  showName: true,
  showModel: true,
  showLocation: false,
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
 * Single location QR printing helper
 */
export function exportLocationQrPdf(location: LocationQrExportData, config?: QrPrintConfig): void {
  exportLocationQrPdfList([location], `Tem_QR_ViTri_${location.code}`, config);
}

/**
 * Export and print Location QR codes with custom size, template, and formatting.
 */
export function exportLocationQrPdfList(
  locations: LocationQrExportData[],
  filename = 'Danh_sach_tem_QR_vi_tri_kho',
  config: QrPrintConfig = DEFAULT_QR_PRINT_CONFIG
): void {
  if (!locations || locations.length === 0) return;

  const isGridMode = config.template === 'grid' || config.presetSize === 'a4';
  const isHorizontal = config.layoutOrder === 'horizontal' || config.template === 'horizontal';

  const cardsHtml = locations
    .map((loc) => {
      const qrCodeVal = loc.qrCode || loc.code || 'N/A';
      const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(qrCodeVal)}`;

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
            <img src="${qrUrl}" alt="QR Code" class="qr-image" />
          </div>
          <div class="qr-info-meta" style="align-items: ${alignItemCss}; text-align: ${textAlignCss};">
            ${
              config.showName && loc.name
                ? `<div class="qr-title">${escapeHtml(loc.name)}</div>`
                : ''
            }
            ${
              loc.description
                ? `<div class="qr-subtext">${escapeHtml(loc.description)}</div>`
                : ''
            }
            ${
              loc.totalPartTypes !== undefined
                ? `<div class="qr-subtext" style="font-size: 9px; color: #64748b;">${loc.totalPartTypes} loại linh kiện</div>`
                : ''
            }
            ${
              config.showCodeText
                ? `
                <div class="qr-code-box">
                  <span class="qr-code-label">MÃ VỊ TRÍ KHO:</span>
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
          ${
            isGridMode
              ? `size: A4 portrait; margin: 5mm;`
              : `size: ${config.widthMm}mm ${config.heightMm}mm; margin: 0mm;`
          }
        }
        * {
          box-sizing: border-box;
          margin: 0;
          padding: 0;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        html, body {
          background-color: #ffffff;
          color: #0f172a;
          padding: 0;
          margin: 0;
          width: ${isGridMode ? '210mm' : `${config.widthMm}mm`} !important;
          height: ${isGridMode ? '297mm' : `${config.heightMm}mm`} !important;
          overflow: hidden;
          -webkit-print-color-adjust: exact !important;
          print-color-adjust: exact !important;
        }
        .page-header {
          text-align: center;
          margin: 12px;
          padding: 12px;
          background: #ffffff;
          border-radius: 8px;
          border: 1px solid #cbd5e1;
        }
        .page-header h2 {
          font-size: 16px;
          color: #0f172a;
          text-transform: uppercase;
        }
        .page-header p {
          font-size: 12px;
          color: #64748b;
          margin-top: 4px;
        }
        .action-btns {
          margin-top: 10px;
          display: flex;
          gap: 10px;
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
                gap: 12px;
                padding: 10mm;
                justify-items: center;
              `
              : `
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 0;
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
          background: #ffffff;
          border: ${
            config.showBorder
              ? `${config.borderWidthPx}px solid #000000`
              : 'none'
          };
          border-radius: ${config.borderRadiusPx}px;
          display: flex;
          flex-direction: ${
            isHorizontal
              ? 'row'
              : config.layoutOrder === 'title_top'
              ? 'column-reverse'
              : 'column'
          };
          align-items: center;
          justify-content: center;
          gap: ${isHorizontal ? '10px' : '4px'};
          page-break-inside: avoid !important;
          page-break-after: ${locations.length > 1 && !isGridMode ? 'always' : 'auto'} !important;
          box-sizing: border-box !important;
          overflow: hidden !important;
        }

        .qr-image-wrapper {
          display: flex;
          justify-content: center;
          align-items: center;
        }

        .qr-image {
          width: ${config.qrSizePx}px;
          height: ${config.qrSizePx}px;
          object-fit: contain;
        }

        .qr-info-meta {
          display: flex;
          flex-direction: column;
          width: 100%;
          gap: 2px;
        }

        .qr-title {
          font-size: ${config.titleFontSize}px;
          font-weight: 800;
          color: #0f172a;
          line-height: 1.2;
          word-break: break-word;
        }

        .qr-subtext {
          font-size: ${Math.max(8, config.titleFontSize - 2)}px;
          color: #334155;
          line-height: 1.2;
        }

        .qr-code-box {
          display: flex;
          flex-direction: column;
          align-items: center;
          background: #f1f5f9 !important;
          border: 1px solid #000000;
          border-radius: 4px;
          padding: 3px 6px;
          margin-top: 3px;
          width: 100%;
          box-sizing: border-box;
          -webkit-print-color-adjust: exact !important;
          print-color-adjust: exact !important;
        }

        .qr-code-label {
          font-size: 8px;
          font-weight: 700;
          color: #475569;
          letter-spacing: 0.5px;
        }

        .qr-code-text {
          font-family: "Courier New", Courier, monospace;
          font-size: ${config.codeFontSize}px;
          font-weight: 800;
          color: #0f172a;
          letter-spacing: 0.8px;
          word-break: break-all;
          text-align: center;
        }

        @media print {
          @page {
            size: ${
              isGridMode
                ? 'A4 portrait;'
                : `${config.widthMm}mm ${config.heightMm}mm;`
            }
            margin: 0mm;
          }
          html, body {
            background: none !important;
            padding: 0 !important;
            margin: 0 !important;
            width: ${isGridMode ? '210mm' : `${config.widthMm}mm`} !important;
            height: ${isGridMode ? '297mm' : `${config.heightMm}mm`} !important;
          }
          .no-print {
            display: none !important;
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

  // All hardware/device/system drivers: Print directly via hidden iframe without opening new tab
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
  }, 250);
}

/**
 * Single board QR printing helper
 */
export function exportBoardQrPdf(board: BoardQrExportData, config?: QrPrintConfig): void {
  exportBoardQrPdfList([board], `Tem_QR_${board.qrCode || board.name}`, config);
}

/**
 * Export and print board QR codes (legacy compatibility)
 */
export function exportBoardQrPdfList(
  boards: BoardQrExportData[],
  filename = 'Danh_sach_tem_QR_bo_mach',
  config: QrPrintConfig = DEFAULT_QR_PRINT_CONFIG
): void {
  if (!boards || boards.length === 0) return;

  const isGridMode = config.template === 'grid' || config.presetSize === 'a4';
  const isHorizontal = config.layoutOrder === 'horizontal' || config.template === 'horizontal';

  const cardsHtml = boards
    .map((b) => {
      const qrCodeVal = b.qrCode || 'N/A';
      const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(qrCodeVal)}`;

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
            <img src="${qrUrl}" alt="QR Code" class="qr-image" />
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
          ${
            isGridMode
              ? `size: A4 portrait; margin: 5mm;`
              : `size: ${config.widthMm}mm ${config.heightMm}mm; margin: 0mm;`
          }
        }
        * {
          box-sizing: border-box;
          margin: 0;
          padding: 0;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        html, body {
          background-color: #ffffff;
          color: #0f172a;
          padding: 0;
          margin: 0;
          width: ${isGridMode ? '210mm' : `${config.widthMm}mm`} !important;
          height: ${isGridMode ? '297mm' : `${config.heightMm}mm`} !important;
          overflow: hidden;
          -webkit-print-color-adjust: exact !important;
          print-color-adjust: exact !important;
        }
        .page-header {
          text-align: center;
          margin: 12px;
          padding: 12px;
          background: #ffffff;
          border-radius: 8px;
          border: 1px solid #cbd5e1;
        }
        .page-header h2 {
          font-size: 16px;
          color: #0f172a;
          text-transform: uppercase;
        }
        .page-header p {
          font-size: 12px;
          color: #64748b;
          margin-top: 4px;
        }
        .action-btns {
          margin-top: 10px;
          display: flex;
          gap: 10px;
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
                gap: 12px;
                padding: 10mm;
                justify-items: center;
              `
              : `
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 0;
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
          background: #ffffff;
          border: ${
            config.showBorder
              ? `${config.borderWidthPx}px solid #000000`
              : 'none'
          };
          border-radius: ${config.borderRadiusPx}px;
          display: flex;
          flex-direction: ${
            isHorizontal
              ? 'row'
              : config.layoutOrder === 'title_top'
              ? 'column-reverse'
              : 'column'
          };
          align-items: center;
          justify-content: center;
          gap: ${isHorizontal ? '10px' : '4px'};
          page-break-inside: avoid !important;
          page-break-after: ${boards.length > 1 && !isGridMode ? 'always' : 'auto'} !important;
          box-sizing: border-box !important;
          overflow: hidden !important;
        }

        .qr-image-wrapper {
          display: flex;
          justify-content: center;
          align-items: center;
        }

        .qr-image {
          width: ${config.qrSizePx}px;
          height: ${config.qrSizePx}px;
          object-fit: contain;
        }

        .qr-info-meta {
          display: flex;
          flex-direction: column;
          width: 100%;
          gap: 2px;
        }

        .qr-title {
          font-size: ${config.titleFontSize}px;
          font-weight: 800;
          color: #0f172a;
          line-height: 1.2;
          word-break: break-word;
        }

        .qr-subtext {
          font-size: ${Math.max(8, config.titleFontSize - 2)}px;
          color: #334155;
          line-height: 1.2;
        }

        .qr-code-box {
          display: flex;
          flex-direction: column;
          align-items: center;
          background: #f1f5f9 !important;
          border: 1px solid #000000;
          border-radius: 4px;
          padding: 3px 6px;
          margin-top: 3px;
          width: 100%;
          box-sizing: border-box;
          -webkit-print-color-adjust: exact !important;
          print-color-adjust: exact !important;
        }

        .qr-code-label {
          font-size: 8px;
          font-weight: 700;
          color: #475569;
          letter-spacing: 0.5px;
        }

        .qr-code-text {
          font-family: "Courier New", Courier, monospace;
          font-size: ${config.codeFontSize}px;
          font-weight: 800;
          color: #0f172a;
          letter-spacing: 0.8px;
          word-break: break-all;
          text-align: center;
        }

        @media print {
          @page {
            size: ${
              isGridMode
                ? 'A4 portrait;'
                : `${config.widthMm}mm ${config.heightMm}mm;`
            }
            margin: 0mm;
          }
          html, body {
            background: none !important;
            padding: 0 !important;
            margin: 0 !important;
            width: ${isGridMode ? '210mm' : `${config.widthMm}mm`} !important;
            height: ${isGridMode ? '297mm' : `${config.heightMm}mm`} !important;
          }
          .no-print {
            display: none !important;
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
      <div class="page-header no-print">
        <h2>IN TEM NHÃN KHO BO MẠCH</h2>
        <p>Kích thước: <strong>${config.widthMm}mm x ${config.heightMm}mm</strong> | Driver: <strong>${escapeHtml(config.printerDriver || 'system_default')} (${config.printerDpi || 203} DPI)</strong> | Mẫu: <strong>${config.template}</strong></p>
        <div class="action-btns">
          <button class="btn-print" onclick="window.print()">
            🖨️ In Tem / Lưu PDF
          </button>
          <button class="btn-close" onclick="window.close()">
            Đóng
          </button>
        </div>
      </div>

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

  // All hardware/device/system drivers: Print directly via hidden iframe without opening new tab
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
  }, 250);
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
