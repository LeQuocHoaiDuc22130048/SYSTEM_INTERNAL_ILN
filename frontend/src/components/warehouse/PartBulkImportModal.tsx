import React, { useState, useRef } from 'react';
import {
  X,
  FileSpreadsheet,
  Upload,
  Download,
  CheckCircle2,
  AlertTriangle,
  AlertCircle,
  Loader2,
  Trash2,
  Info,
} from 'lucide-react';
import ExcelJS from 'exceljs';
import { getJsonAuthHeaders } from '../../utils/auth';
import type { Part, BulkImportPartItem } from '../../types/warehouse';

interface ParsedRowItem extends BulkImportPartItem {
  id: string;
  rowNumber: number;
  status: 'VALID' | 'WARNING' | 'ERROR';
  errorMessage?: string;
}

interface PartBulkImportModalProps {
  isOpen: boolean;
  onClose: () => void;
  existingParts: Part[];
  onSuccess: () => void;
  showToast: (msg: string) => void;
}

export const PartBulkImportModal: React.FC<PartBulkImportModalProps> = ({
  isOpen,
  onClose,
  existingParts,
  onSuccess,
  showToast,
}) => {
  const [parsedRows, setParsedRows] = useState<ParsedRowItem[]>([]);
  const [fileName, setFileName] = useState<string>('');
  const [updateIfExists, setUpdateIfExists] = useState<boolean>(true);
  const [isParsing, setIsParsing] = useState<boolean>(false);
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);
  const [filterStatus, setFilterStatus] = useState<'ALL' | 'VALID' | 'WARNING' | 'ERROR'>('ALL');
  const [importResult, setImportResult] = useState<{
    successCount: number;
    updatedCount: number;
    failedCount: number;
    errors: { rowNumber: number; ipn: string; errorMessage: string }[];
  } | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);

  if (!isOpen) return null;

  // ── 1. Sinh file Excel Mẫu (.xlsx) với ExcelJS ──────────────────────
  const handleDownloadTemplate = async () => {
    try {
      const workbook = new ExcelJS.Workbook();
      workbook.creator = 'System Internal Warehouse';
      workbook.created = new Date();

      const worksheet = workbook.addWorksheet('Danh_Sach_Linh_Kien', {
        views: [{ state: 'frozen', ySplit: 1 }],
      });

      // Cột tiêu đề
      worksheet.columns = [
        { header: 'Mã IPN (*)', key: 'ipn', width: 20 },
        { header: 'Tên linh kiện (*)', key: 'name', width: 32 },
        { header: 'Danh mục', key: 'categoryName', width: 20 },
        { header: 'Mô tả / Thông số', key: 'description', width: 30 },
        { header: 'Kiểu chân (Footprint)', key: 'footprint', width: 22 },
        { header: 'Vị trí kho', key: 'storeLocationCode', width: 16 },
        { header: 'Số lượng nhập', key: 'quantity', width: 16 },
        { header: 'Tồn tối thiểu (Min)', key: 'minAmount', width: 18 },
        { header: 'Tồn tối đa (Max)', key: 'maxAmount', width: 18 },
        { header: 'Giá nhập (VNĐ)', key: 'purchasePrice', width: 18 },
        { header: 'Giá bán (VNĐ)', key: 'salePrice', width: 18 },
        { header: 'Thông số (JSON/Text)', key: 'parameters', width: 25 },
        { header: 'Ghi chú kỹ thuật', key: 'note', width: 25 },
      ];

      // Format Header Row
      const headerRow = worksheet.getRow(1);
      headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' }, size: 11 };
      headerRow.alignment = { vertical: 'middle', horizontal: 'center' };
      headerRow.height = 28;

      headerRow.eachCell((cell) => {
        cell.fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: 'FF1E293B' }, // Dark slate blue
        };
        cell.border = {
          top: { style: 'thin', color: { argb: 'FF475569' } },
          left: { style: 'thin', color: { argb: 'FF475569' } },
          bottom: { style: 'medium', color: { argb: 'FF0F172A' } },
          right: { style: 'thin', color: { argb: 'FF475569' } },
        };
      });

      // Dữ liệu mẫu minh họa
      const sampleData = [
        {
          ipn: 'UCC23513',
          name: 'IC Driver cách ly UCC23513 SOP-8',
          categoryName: 'IC Driver',
          description: 'Optocoupler Driver cách ly 5kVrms',
          footprint: 'SOP-8',
          storeLocationCode: 'A-01-02',
          quantity: 100,
          minAmount: 10,
          maxAmount: 500,
          purchasePrice: 45000,
          salePrice: 75000,
          parameters: 'Vcc=33V, Iout=5A',
          note: 'Hàng chính hãng TI nguyên đai nguyên kiện',
        },
        {
          ipn: 'IRFP460',
          name: 'MOSFET N-CH 500V 20A IRFP460',
          categoryName: 'MOSFET & Transistor',
          description: 'MOSFET công suất chịu dòng cao',
          footprint: 'TO-247',
          storeLocationCode: 'B-02-05',
          quantity: 50,
          minAmount: 5,
          maxAmount: 200,
          purchasePrice: 28000,
          salePrice: 48000,
          parameters: 'Vds=500V, Id=20A, Rds=0.27ohm',
          note: 'Dùng cho khối công suất Inverter Sungrow',
        },
        {
          ipn: 'CAP-10UF-50V',
          name: 'Tụ hóa nhôm 10uF 50V SMD',
          categoryName: 'Tụ điện',
          description: 'Tụ phân cực 105 độ C',
          footprint: 'SMD 6.3x5.4',
          storeLocationCode: 'C-01-01',
          quantity: 200,
          minAmount: 20,
          maxAmount: 1000,
          purchasePrice: 2500,
          salePrice: 5000,
          parameters: '10uF, 50V, 105C',
          note: 'Tụ lọc nguồn DC',
        },
      ];

      sampleData.forEach((item) => {
        const row = worksheet.addRow(item);
        row.alignment = { vertical: 'middle' };
        row.height = 22;
      });

      // Xuất file
      const buffer = await workbook.xlsx.writeBuffer();
      const blob = new Blob([buffer], {
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      });
      const url = window.URL.createObjectURL(blob);
      const anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = 'Template_Import_Linh_Kien.xlsx';
      anchor.click();
      window.URL.revokeObjectURL(url);
      showToast('Đã tải xuống file mẫu Template_Import_Linh_Kien.xlsx');
    } catch (err) {
      console.error('Lỗi sinh file mẫu Excel:', err);
      showToast('Không thể tạo file mẫu Excel');
    }
  };

  // ── 2. Đọc file Excel / CSV bằng ExcelJS ─────────────────────────────
  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setFileName(file.name);
    setIsParsing(true);
    setImportResult(null);

    try {
      const workbook = new ExcelJS.Workbook();
      const arrayBuffer = await file.arrayBuffer();

      if (file.name.endsWith('.csv')) {
        const text = new TextDecoder('utf-8').decode(arrayBuffer);
        await parseCsvContent(text);
      } else {
        await workbook.xlsx.load(arrayBuffer);
        const worksheet = workbook.worksheets[0];
        if (!worksheet) {
          throw new Error('File không chứa sheet dữ liệu nào');
        }

        const rows: ParsedRowItem[] = [];
        const existingIpnSet = new Set(existingParts.map((p) => p.ipn.toLowerCase().trim()));
        const payloadIpnCount = new Map<string, number>();

        // Duyệt từng dòng (bỏ qua dòng tiêu đề 1)
        worksheet.eachRow((row, rowNumber) => {
          if (rowNumber === 1) return; // Bỏ header

          const ipnRaw = row.getCell(1).text || '';
          const nameRaw = row.getCell(2).text || '';
          const categoryName = row.getCell(3).text || '';
          const description = row.getCell(4).text || '';
          const footprint = row.getCell(5).text || '';
          const storeLocationCode = row.getCell(6).text || '';
          const quantityVal = row.getCell(7).value;
          const minAmountVal = row.getCell(8).value;
          const maxAmountVal = row.getCell(9).value;
          const purchasePriceVal = row.getCell(10).value;
          const salePriceVal = row.getCell(11).value;
          const parameters = row.getCell(12).text || '';
          const note = row.getCell(13).text || '';

          const ipn = ipnRaw.trim();
          const name = nameRaw.trim();

          // Bỏ qua dòng trống hoàn toàn
          if (!ipn && !name) return;

          const quantity = parseNumber(quantityVal);
          const minAmount = parseNumber(minAmountVal);
          const maxAmount = parseNumber(maxAmountVal);
          const purchasePrice = parseNumber(purchasePriceVal);
          const salePrice = parseNumber(salePriceVal);

          let status: 'VALID' | 'WARNING' | 'ERROR' = 'VALID';
          let errorMessage = '';

          if (!ipn) {
            status = 'ERROR';
            errorMessage = 'Thiếu mã IPN';
          } else if (!name) {
            status = 'ERROR';
            errorMessage = 'Thiếu tên linh kiện';
          } else if (quantity < 0) {
            status = 'ERROR';
            errorMessage = 'Số lượng không được âm';
          } else {
            const lowerIpn = ipn.toLowerCase();
            const count = (payloadIpnCount.get(lowerIpn) || 0) + 1;
            payloadIpnCount.set(lowerIpn, count);

            if (count > 1) {
              status = 'WARNING';
              errorMessage = `Trùng mã IPN trong file (dòng ${rowNumber})`;
            } else if (existingIpnSet.has(lowerIpn)) {
              status = 'WARNING';
              errorMessage = 'Mã IPN đã tồn tại trong kho (sẽ cập nhật/cộng dồn)';
            }
          }

          rows.push({
            id: `row-${rowNumber}-${Date.now()}`,
            rowNumber,
            ipn,
            name,
            categoryName: categoryName.trim() || undefined,
            description: description.trim() || undefined,
            footprint: footprint.trim() || undefined,
            storeLocationCode: storeLocationCode.trim() || undefined,
            quantity: quantity > 0 ? quantity : undefined,
            minAmount: minAmount > 0 ? minAmount : undefined,
            maxAmount: maxAmount > 0 ? maxAmount : undefined,
            purchasePrice: purchasePrice > 0 ? purchasePrice : undefined,
            salePrice: salePrice > 0 ? salePrice : undefined,
            parameters: parameters.trim() || undefined,
            note: note.trim() || undefined,
            status,
            errorMessage,
          });
        });

        setParsedRows(rows);
      }
    } catch (err: any) {
      console.error('Lỗi đọc file:', err);
      showToast(err.message || 'Lỗi đọc file Excel. Vui lòng kiểm tra lại định dạng');
    } finally {
      setIsParsing(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const parseCsvContent = async (csvText: string) => {
    const lines = csvText.split(/\r?\n/).filter((l) => l.trim().length > 0);
    if (lines.length <= 1) {
      setParsedRows([]);
      return;
    }

    const rows: ParsedRowItem[] = [];
    const existingIpnSet = new Set(existingParts.map((p) => p.ipn.toLowerCase().trim()));

    for (let i = 1; i < lines.length; i++) {
      const cols = lines[i].split(',').map((c) => c.replace(/^"|"$/g, '').trim());
      const ipn = cols[0] || '';
      const name = cols[1] || '';
      if (!ipn && !name) continue;

      const categoryName = cols[2] || '';
      const description = cols[3] || '';
      const footprint = cols[4] || '';
      const storeLocationCode = cols[5] || '';
      const quantity = parseFloat(cols[6]) || 0;
      const minAmount = parseFloat(cols[7]) || 0;
      const purchasePrice = parseFloat(cols[8]) || 0;
      const salePrice = parseFloat(cols[9]) || 0;
      const note = cols[10] || '';

      let status: 'VALID' | 'WARNING' | 'ERROR' = 'VALID';
      let errorMessage = '';

      if (!ipn) {
        status = 'ERROR';
        errorMessage = 'Thiếu mã IPN';
      } else if (!name) {
        status = 'ERROR';
        errorMessage = 'Thiếu tên linh kiện';
      } else if (existingIpnSet.has(ipn.toLowerCase())) {
        status = 'WARNING';
        errorMessage = 'Mã IPN đã có trong hệ thống (sẽ cập nhật)';
      }

      rows.push({
        id: `csv-${i}-${Date.now()}`,
        rowNumber: i + 1,
        ipn,
        name,
        categoryName: categoryName || undefined,
        description: description || undefined,
        footprint: footprint || undefined,
        storeLocationCode: storeLocationCode || undefined,
        quantity: quantity > 0 ? quantity : undefined,
        minAmount: minAmount > 0 ? minAmount : undefined,
        purchasePrice: purchasePrice > 0 ? purchasePrice : undefined,
        salePrice: salePrice > 0 ? salePrice : undefined,
        note: note || undefined,
        status,
        errorMessage,
      });
    }

    setParsedRows(rows);
  };

  const parseNumber = (val: any): number => {
    if (val === null || val === undefined) return 0;
    if (typeof val === 'number') return isNaN(val) ? 0 : val;
    if (typeof val === 'string') {
      const clean = val.replace(/[^0-9.-]+/g, '');
      const parsed = parseFloat(clean);
      return isNaN(parsed) ? 0 : parsed;
    }
    return 0;
  };

  // ── 3. Thống kê số lượng dòng ───────────────────────────────────────
  const validRows = parsedRows.filter((r) => r.status === 'VALID');
  const warningRows = parsedRows.filter((r) => r.status === 'WARNING');
  const errorRows = parsedRows.filter((r) => r.status === 'ERROR');

  const filteredDisplayRows = parsedRows.filter((r) => {
    if (filterStatus === 'ALL') return true;
    return r.status === filterStatus;
  });

  // ── 4. Gửi Payload lên Backend API ───────────────────────────────────
  const handleSubmitImport = async () => {
    const importableRows = parsedRows.filter((r) => r.status !== 'ERROR');
    if (importableRows.length === 0) {
      showToast('Không có dòng dữ liệu hợp lệ nào để nhập kho');
      return;
    }

    setIsSubmitting(true);
    setImportResult(null);

    try {
      const payload = {
        items: importableRows.map((r) => ({
          ipn: r.ipn,
          name: r.name,
          categoryName: r.categoryName,
          description: r.description,
          footprint: r.footprint,
          storeLocationCode: r.storeLocationCode,
          quantity: r.quantity,
          minAmount: r.minAmount,
          maxAmount: r.maxAmount,
          purchasePrice: r.purchasePrice,
          salePrice: r.salePrice,
          parameters: r.parameters,
          note: r.note,
        })),
        updateIfExists,
      };

      const res = await fetch('/api/v1/parts/bulk-import', {
        method: 'POST',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        const errorData = await res.json().catch(() => ({}));
        throw new Error(errorData.message || 'Lỗi nhập dữ liệu từ máy chủ');
      }

      const resData = await res.json();
      const result = resData.data;

      setImportResult({
        successCount: result.successCount,
        updatedCount: result.updatedCount,
        failedCount: result.failedCount,
        errors: result.errors || [],
      });

      showToast(
        `Nhập thành công ${result.successCount} mới, ${result.updatedCount} cập nhật!`
      );
      onSuccess();
    } catch (err: any) {
      console.error('Lỗi gửi API bulk-import:', err);
      showToast(err.message || 'Không thể nhập dữ liệu vào kho');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleClear = () => {
    setParsedRows([]);
    setFileName('');
    setImportResult(null);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl shadow-2xl w-full max-w-5xl max-h-[90vh] flex flex-col overflow-hidden text-slate-800 dark:text-slate-100">
        
        {/* Modal Header */}
        <div className="px-6 py-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50/80 dark:bg-slate-800/50">
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-emerald-100 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400 rounded-xl">
              <FileSpreadsheet className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold">Nhập linh kiện hàng loạt (Excel / CSV)</h2>
              <p className="text-xs text-slate-500 dark:text-slate-400">
                Tự động tạo linh kiện, vị trí lưu kho, cập nhật số lượng và ghi nhận lịch sử biến động
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Body */}
        <div className="flex-1 overflow-y-auto p-6 space-y-5">
          
          {/* Top Actions: Template Download & Upload Area */}
          {parsedRows.length === 0 ? (
            <div className="space-y-4">
              <div className="flex flex-col sm:flex-row items-center justify-between gap-3 p-4 bg-blue-50/70 dark:bg-blue-950/30 border border-blue-200 dark:border-blue-800/50 rounded-xl text-blue-900 dark:text-blue-200">
                <div className="flex items-center gap-3">
                  <Info className="w-5 h-5 text-blue-600 dark:text-blue-400 shrink-0" />
                  <div className="text-xs leading-relaxed">
                    Chưa có file mẫu chuẩn? Tải file Excel mẫu có định dạng và dòng ví dụ minh họa sẵn.
                  </div>
                </div>
                <button
                  onClick={handleDownloadTemplate}
                  className="flex items-center gap-2 px-3.5 py-2 text-xs font-semibold text-white bg-blue-600 hover:bg-blue-700 active:bg-blue-800 rounded-lg shadow-sm hover:shadow transition-all shrink-0"
                >
                  <Download className="w-4 h-4" />
                  Tải file Excel mẫu (.xlsx)
                </button>
              </div>

              {/* Upload Dropzone */}
              <div
                onClick={() => fileInputRef.current?.click()}
                className="border-2 border-dashed border-slate-300 dark:border-slate-700 hover:border-emerald-500 dark:hover:border-emerald-500 bg-slate-50 dark:bg-slate-800/30 hover:bg-emerald-50/40 dark:hover:bg-emerald-950/20 rounded-2xl p-10 text-center cursor-pointer transition-all flex flex-col items-center justify-center gap-3"
              >
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".xlsx,.xls,.csv"
                  className="hidden"
                  onChange={handleFileChange}
                />
                <div className="p-4 bg-emerald-100 dark:bg-emerald-900/40 text-emerald-600 dark:text-emerald-400 rounded-full">
                  <Upload className="w-7 h-7" />
                </div>
                <div>
                  <p className="text-sm font-semibold text-slate-700 dark:text-slate-200">
                    Bấm để chọn file hoặc kéo thả file vào đây
                  </p>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">
                    Hỗ trợ định dạng Microsoft Excel (.xlsx, .xls) hoặc CSV (.csv)
                  </p>
                </div>
              </div>
            </div>
          ) : (
            <div className="space-y-4">
              
              {/* Header Bar when file is loaded */}
              <div className="flex flex-wrap items-center justify-between gap-3 p-3.5 bg-slate-100 dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 text-xs">
                <div className="flex items-center gap-2">
                  <FileSpreadsheet className="w-4 h-4 text-emerald-600 dark:text-emerald-400" />
                  <span className="font-semibold text-slate-700 dark:text-slate-200 truncate max-w-xs">
                    {fileName}
                  </span>
                  <span className="text-slate-400">({parsedRows.length} dòng dữ liệu)</span>
                </div>

                <div className="flex items-center gap-2">
                  <button
                    onClick={handleClear}
                    className="flex items-center gap-1.5 px-2.5 py-1.5 text-slate-600 dark:text-slate-300 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-950/30 rounded-lg transition-colors"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                    Chọn file khác
                  </button>
                  <button
                    onClick={handleDownloadTemplate}
                    className="flex items-center gap-1.5 px-2.5 py-1.5 text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-950/30 rounded-lg transition-colors"
                  >
                    <Download className="w-3.5 h-3.5" />
                    File mẫu
                  </button>
                </div>
              </div>

              {/* Status Badges Filter Bar */}
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="flex items-center gap-1.5 bg-slate-100 dark:bg-slate-800 p-1 rounded-lg">
                  <button
                    onClick={() => setFilterStatus('ALL')}
                    className={`px-3 py-1 text-xs rounded-md font-medium transition-all ${
                      filterStatus === 'ALL'
                        ? 'bg-white dark:bg-slate-700 text-slate-800 dark:text-slate-100 shadow-sm'
                        : 'text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
                    }`}
                  >
                    Tất cả ({parsedRows.length})
                  </button>
                  <button
                    onClick={() => setFilterStatus('VALID')}
                    className={`flex items-center gap-1 px-3 py-1 text-xs rounded-md font-medium transition-all ${
                      filterStatus === 'VALID'
                        ? 'bg-emerald-600 text-white shadow-sm'
                        : 'text-emerald-600 dark:text-emerald-400 hover:bg-emerald-50 dark:hover:bg-emerald-950/30'
                    }`}
                  >
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    Hợp lệ ({validRows.length})
                  </button>
                  {warningRows.length > 0 && (
                    <button
                      onClick={() => setFilterStatus('WARNING')}
                      className={`flex items-center gap-1 px-3 py-1 text-xs rounded-md font-medium transition-all ${
                        filterStatus === 'WARNING'
                          ? 'bg-amber-600 text-white shadow-sm'
                          : 'text-amber-600 dark:text-amber-400 hover:bg-amber-50 dark:hover:bg-amber-950/30'
                      }`}
                    >
                      <AlertTriangle className="w-3.5 h-3.5" />
                      Cảnh báo trùng ({warningRows.length})
                    </button>
                  )}
                  {errorRows.length > 0 && (
                    <button
                      onClick={() => setFilterStatus('ERROR')}
                      className={`flex items-center gap-1 px-3 py-1 text-xs rounded-md font-medium transition-all ${
                        filterStatus === 'ERROR'
                          ? 'bg-red-600 text-white shadow-sm'
                          : 'text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/30'
                      }`}
                    >
                      <AlertCircle className="w-3.5 h-3.5" />
                      Lỗi ({errorRows.length})
                    </button>
                  )}
                </div>

                {/* Update if exists toggle */}
                <label className="flex items-center gap-2 text-xs font-medium cursor-pointer text-slate-700 dark:text-slate-300">
                  <input
                    type="checkbox"
                    checked={updateIfExists}
                    onChange={(e) => setUpdateIfExists(e.target.checked)}
                    className="w-4 h-4 rounded text-emerald-600 focus:ring-emerald-500 border-slate-300 dark:border-slate-600 dark:bg-slate-800"
                  />
                  <span>Nếu mã IPN đã có: Cập nhật thông tin & Cộng dồn tồn kho</span>
                </label>
              </div>

              {/* Data Preview Table */}
              <div className="border border-slate-200 dark:border-slate-800 rounded-xl overflow-hidden shadow-sm">
                <div className="overflow-x-auto max-h-80">
                  <table className="w-full text-left text-xs border-collapse">
                    <thead className="bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 sticky top-0 z-10">
                      <tr>
                        <th className="py-2.5 px-3 font-semibold border-b border-slate-200 dark:border-slate-700 w-12 text-center">STT</th>
                        <th className="py-2.5 px-3 font-semibold border-b border-slate-200 dark:border-slate-700 w-24">Trạng thái</th>
                        <th className="py-2.5 px-3 font-semibold border-b border-slate-200 dark:border-slate-700">Mã IPN</th>
                        <th className="py-2.5 px-3 font-semibold border-b border-slate-200 dark:border-slate-700">Tên linh kiện</th>
                        <th className="py-2.5 px-3 font-semibold border-b border-slate-200 dark:border-slate-700">Danh mục</th>
                        <th className="py-2.5 px-3 font-semibold border-b border-slate-200 dark:border-slate-700">Vị trí kho</th>
                        <th className="py-2.5 px-3 font-semibold border-b border-slate-200 dark:border-slate-700 text-right">Số lượng</th>
                        <th className="py-2.5 px-3 font-semibold border-b border-slate-200 dark:border-slate-700 text-right">Giá nhập</th>
                        <th className="py-2.5 px-3 font-semibold border-b border-slate-200 dark:border-slate-700">Ghi chú / Chi tiết</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800 bg-white dark:bg-slate-900 font-mono text-[11px]">
                      {filteredDisplayRows.map((row) => (
                        <tr
                          key={row.id}
                          className={`hover:bg-slate-50/80 dark:hover:bg-slate-800/40 transition-colors ${
                            row.status === 'ERROR'
                              ? 'bg-red-50/50 dark:bg-red-950/20'
                              : row.status === 'WARNING'
                              ? 'bg-amber-50/40 dark:bg-amber-950/10'
                              : ''
                          }`}
                        >
                          <td className="py-2 px-3 text-center text-slate-400 font-sans">{row.rowNumber}</td>
                          <td className="py-2 px-3">
                            {row.status === 'VALID' && (
                              <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-emerald-100 dark:bg-emerald-950/60 text-emerald-700 dark:text-emerald-300 font-sans text-[10px] font-medium">
                                <CheckCircle2 className="w-3 h-3" /> Hợp lệ
                              </span>
                            )}
                            {row.status === 'WARNING' && (
                              <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-amber-100 dark:bg-amber-950/60 text-amber-700 dark:text-amber-300 font-sans text-[10px] font-medium" title={row.errorMessage}>
                                <AlertTriangle className="w-3 h-3" /> Cảnh báo
                              </span>
                            )}
                            {row.status === 'ERROR' && (
                              <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-red-100 dark:bg-red-950/60 text-red-700 dark:text-red-300 font-sans text-[10px] font-medium" title={row.errorMessage}>
                                <AlertCircle className="w-3 h-3" /> Lỗi
                              </span>
                            )}
                          </td>
                          <td className="py-2 px-3 font-semibold text-slate-800 dark:text-slate-100">{row.ipn || '—'}</td>
                          <td className="py-2 px-3 font-sans text-slate-700 dark:text-slate-300 truncate max-w-[200px]" title={row.name}>
                            {row.name || '—'}
                          </td>
                          <td className="py-2 px-3 font-sans text-slate-500">{row.categoryName || 'Mặc định'}</td>
                          <td className="py-2 px-3 text-blue-600 dark:text-blue-400">{row.storeLocationCode || '—'}</td>
                          <td className="py-2 px-3 text-right font-semibold text-emerald-600 dark:text-emerald-400">
                            {row.quantity !== undefined ? row.quantity.toLocaleString('vi-VN') : '0'}
                          </td>
                          <td className="py-2 px-3 text-right text-slate-500">
                            {row.purchasePrice ? `${row.purchasePrice.toLocaleString('vi-VN')} đ` : '—'}
                          </td>
                          <td className="py-2 px-3 font-sans text-slate-500 truncate max-w-[150px]">
                            {row.errorMessage ? (
                              <span className="text-red-500 font-medium">{row.errorMessage}</span>
                            ) : (
                              row.note || row.description || '—'
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Import Result Summary Alert (if finished) */}
              {importResult && (
                <div className="p-4 bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800 rounded-xl space-y-2 text-xs">
                  <div className="flex items-center gap-2 font-bold text-emerald-800 dark:text-emerald-300 text-sm">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                    Kết quả nhập kho thành công
                  </div>
                  <div className="flex flex-wrap gap-4 text-slate-700 dark:text-slate-300">
                    <div>Tạo mới: <strong className="text-emerald-600">{importResult.successCount}</strong></div>
                    <div>Cập nhật: <strong className="text-blue-600">{importResult.updatedCount}</strong></div>
                    {importResult.failedCount > 0 && (
                      <div>Lỗi bỏ qua: <strong className="text-red-600">{importResult.failedCount}</strong></div>
                    )}
                  </div>
                </div>
              )}
            </div>
          )}

        </div>

        {/* Modal Footer */}
        <div className="px-6 py-4 border-t border-slate-200 dark:border-slate-800 flex items-center justify-between bg-slate-50/80 dark:bg-slate-800/50">
          <button
            onClick={onClose}
            className="px-4 py-2 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-xl transition-colors"
          >
            Đóng
          </button>

          {parsedRows.length > 0 && (
            <div className="flex items-center gap-3">
              <button
                onClick={handleSubmitImport}
                disabled={isSubmitting || isParsing || (validRows.length === 0 && warningRows.length === 0)}
                className="flex items-center gap-2 px-5 py-2.5 text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 disabled:opacity-50 disabled:cursor-not-allowed rounded-xl shadow-md hover:shadow-lg transition-all"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    Đang xử lý nhập kho...
                  </>
                ) : (
                  <>
                    <CheckCircle2 className="w-4 h-4" />
                    Xác nhận nhập {validRows.length + warningRows.length} linh kiện
                  </>
                )}
              </button>
            </div>
          )}
        </div>

      </div>
    </div>
  );
};
