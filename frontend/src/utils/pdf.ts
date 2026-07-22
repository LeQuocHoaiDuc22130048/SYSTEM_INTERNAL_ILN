export interface BoardQrExportData {
  id: string;
  name: string;
  qrCode: string;
  model?: string;
  location?: string;
  serialNumber?: string;
  description?: string;
}

/**
 * Utility to generate and print/export PDF for board identification QR codes.
 * Contains the QR code image and the text code of the QR code.
 */
export function exportBoardQrPdf(board: BoardQrExportData): void {
  exportBoardQrPdfList([board], `Tem_QR_${board.qrCode || board.name}`);
}

export function exportBoardQrPdfList(boards: BoardQrExportData[], filename = 'Danh_sach_tem_QR_bo_mach'): void {
  if (!boards || boards.length === 0) return;

  const isSingle = boards.length === 1;

  const printWindow = window.open('', '_blank');
  if (!printWindow) {
    alert('Vui lòng cho phép popup trình duyệt để mở cửa sổ xuất PDF');
    return;
  }

  const cardsHtml = boards
    .map((b) => {
      const qrCodeVal = b.qrCode || 'N/A';
      const qrSize = isSingle ? '500x500' : '250x250';
      const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=${qrSize}&data=${encodeURIComponent(qrCodeVal)}`;
      return `
        <div class="qr-card">
          <img src="${qrUrl}" alt="QR Code" class="qr-image" />
          <div class="qr-code-box">
            <span class="qr-code-label">MÃ CODE QR:</span>
            <span class="qr-code-text">${escapeHtml(qrCodeVal)}</span>
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
        ${isSingle ? `
          @page {
            size: auto;
            margin: 0mm;
          }
          body {
            background-color: #f8fafc;
            padding: 0;
            margin: 0;
          }
        ` : `
          @page {
            size: A4 portrait;
            margin: 10mm;
          }
          body {
            background-color: #f8fafc;
            padding: 16px;
            margin: 0;
          }
        `}
        * {
          box-sizing: border-box;
          margin: 0;
          padding: 0;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        body {
          color: #1e293b;
        }
        .page-header {
          text-align: center;
          margin: 16px;
          padding: 16px;
          background: #ffffff;
          border-radius: 8px;
          border: 1px solid #cbd5e1;
          box-shadow: 0 1px 3px rgba(0,0,0,0.05);
        }
        .page-header h2 {
          font-size: 18px;
          color: #0f172a;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }
        .page-header p {
          font-size: 13px;
          color: #64748b;
          margin-top: 4px;
        }
        .action-btns {
          margin-top: 12px;
          display: flex;
          gap: 10px;
          justify-content: center;
        }
        .btn-print {
          background: #0284c7;
          color: white;
          border: none;
          padding: 9px 22px;
          font-size: 14px;
          font-weight: 600;
          border-radius: 6px;
          cursor: pointer;
          transition: background 0.2s;
          display: inline-flex;
          align-items: center;
          gap: 6px;
        }
        .btn-print:hover {
          background: #0369a1;
        }
        .btn-close {
          background: #64748b;
          color: white;
          border: none;
          padding: 9px 18px;
          font-size: 14px;
          border-radius: 6px;
          cursor: pointer;
        }
        .cards-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(60mm, 1fr));
          gap: 16px;
          justify-items: center;
          padding: 0 16px;
        }
        .qr-card {
          width: 60mm;
          background: #ffffff;
          border: 1.5px solid #cbd5e1;
          border-radius: 8px;
          padding: 12px;
          box-shadow: 0 1px 3px rgba(0,0,0,0.05);
          page-break-inside: avoid;
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 10px;
        }
        .qr-image {
          width: 140px;
          height: 140px;
          object-fit: contain;
          border: 1.5px solid #cbd5e1;
          border-radius: 8px;
          padding: 6px;
          background: #ffffff;
        }
        .qr-code-box {
          display: flex;
          flex-direction: column;
          align-items: center;
          background: #f1f5f9;
          padding: 8px 12px;
          border-radius: 8px;
          border: 1.5px solid #cbd5e1;
          width: 100%;
          box-sizing: border-box;
        }
        .qr-code-label {
          font-size: 10px;
          font-weight: 700;
          color: #475569;
          letter-spacing: 0.5px;
          margin-bottom: 2px;
        }
        .qr-code-text {
          font-family: "Courier New", Courier, monospace;
          font-size: 16px;
          font-weight: 800;
          color: #0f172a;
          letter-spacing: 1px;
          word-break: break-all;
          text-align: center;
        }

        /* Styling overrides for single QR Code page */
        .cards-grid.single-card {
          display: flex;
          justify-content: center;
          align-items: center;
          width: 100%;
          min-height: calc(100vh - 140px);
          padding: 24px;
        }
        .cards-grid.single-card .qr-card {
          width: 100%;
          max-width: 130mm;
          min-height: 140mm;
          padding: 32px;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          gap: 24px;
          border-radius: 16px;
          box-shadow: 0 4px 12px rgba(0,0,0,0.08);
          border: 2px solid #cbd5e1;
        }
        .cards-grid.single-card .qr-image {
          width: 80%;
          max-width: 320px;
          height: auto;
          aspect-ratio: 1;
          padding: 12px;
          border-radius: 12px;
          border: 2px solid #cbd5e1;
        }
        .cards-grid.single-card .qr-code-box {
          padding: 16px 24px;
          border-radius: 12px;
          border: 2px solid #cbd5e1;
          width: 80%;
          max-width: 320px;
        }
        .cards-grid.single-card .qr-code-label {
          font-size: 12px;
          margin-bottom: 4px;
        }
        .cards-grid.single-card .qr-code-text {
          font-size: 26px;
        }
        
        @media print {
          body {
            background: none;
            padding: 0;
          }
          .no-print {
            display: none !important;
          }
          
          ${isSingle ? `
            .cards-grid.single-card {
              width: 100vw;
              height: 100vh;
              display: flex;
              justify-content: center;
              align-items: center;
              padding: 0;
              margin: 0;
            }
            .cards-grid.single-card .qr-card {
              width: 90vw;
              height: 90vh;
              max-width: none;
              min-height: 0;
              border: 3.5px solid #000000;
              border-radius: 28px;
              padding: 48px;
              justify-content: center;
              box-shadow: none;
              gap: 40px;
            }
            .cards-grid.single-card .qr-image {
              width: 58vh;
              height: 58vh;
              max-width: 80vw;
              max-height: 80vw;
              padding: 24px;
              border: 3.5px solid #000000;
              border-radius: 24px;
            }
            .cards-grid.single-card .qr-code-box {
              width: 80%;
              max-width: 58vh;
              border: 3.5px solid #000000;
              border-radius: 18px;
              padding: 20px;
              background: #f1f5f9 !important;
              -webkit-print-color-adjust: exact;
              print-color-adjust: exact;
            }
            .cards-grid.single-card .qr-code-label {
              font-size: 16px;
              margin-bottom: 6px;
            }
            .cards-grid.single-card .qr-code-text {
              font-size: 34px;
            }
          ` : `
            .cards-grid {
              grid-template-columns: repeat(3, 1fr);
              gap: 10px;
              padding: 0;
            }
            .qr-card {
              box-shadow: none;
              border: 1.5px solid #000000;
            }
            .qr-image {
              border: 1.5px solid #000000;
            }
            .qr-code-box {
              border: 1.5px solid #000000;
              background: #f1f5f9 !important;
              -webkit-print-color-adjust: exact;
              print-color-adjust: exact;
            }
          `}
        }
      </style>
    </head>
    <body>
      <div class="page-header no-print">
        <h2>XUẤT TEM QR CODE ĐỊNH DANH BO MẠCH</h2>
        <p>Bấm <strong>"In / Lưu PDF"</strong> để lưu thành file PDF hoặc in tem nhãn trực tiếp (Mã QR &amp; Mã Code QR)</p>
        <div class="action-btns">
          <button class="btn-print" onclick="window.print()">
            🖨️ In / Lưu PDF
          </button>
          <button class="btn-close" onclick="window.close()">
            Đóng
          </button>
        </div>
      </div>

      <div class="cards-grid ${isSingle ? 'single-card' : ''}">
        ${cardsHtml}
      </div>

      <script>
        window.addEventListener('load', () => {
          setTimeout(() => {
            window.print();
          }, 500);
        });
      </script>
    </body>
    </html>
  `;

  printWindow.document.open();
  printWindow.document.write(htmlContent);
  printWindow.document.close();
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
