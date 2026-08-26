import React, { useState, useEffect, useCallback } from 'react';
import {
  X,
  Cpu,
  Boxes,
  QrCode,
} from 'lucide-react';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import { exportLocationQrPdfList, type LocationQrExportData, type QrPrintConfig } from '../utils/pdf';
import type { Board, BoardHistoryItem, Part, PartLot, PartCheckoutHistoryItem, WarehouseTabProps } from '../types/warehouse';

import { BoardListPanel } from './warehouse/BoardListPanel';
import { PartListPanel } from './warehouse/PartListPanel';
import { BoardDetailPanel } from './warehouse/BoardDetailPanel';
import { PartDetailPanel } from './warehouse/PartDetailPanel';
import { QrPrintConfigModal } from './warehouse/QrPrintConfigModal';
import { PartCheckoutHistoryPanel } from './warehouse/PartCheckoutHistoryPanel';
import { LocationQrScanModal } from './warehouse/LocationQrScanModal';
import { LocationManagementModal } from './warehouse/LocationManagementModal';
import { LocationListPanel } from './warehouse/LocationListPanel';
import { PartCheckoutModal } from './warehouse/PartCheckoutModal';
import { PartReturnModal } from './warehouse/PartReturnModal';
import { PartBulkImportModal } from './warehouse/PartBulkImportModal';
import { UnifiedListPanel } from './warehouse/UnifiedListPanel';
import './WarehouseTab.css';


export const WarehouseTab: React.FC<WarehouseTabProps> = ({ showToast, initialMode }) => {
  const [boards, setBoards] = useState<Board[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');

  // Selected Board Details
  const [selectedBoard, setSelectedBoard] = useState<Board | null>(null);
  const [boardHistory, setBoardHistory] = useState<BoardHistoryItem[]>([]);
  const [loadingHistory, setLoadingHistory] = useState<boolean>(false);

  // Modals
  const [isAddEditModalOpen, setIsAddEditModalOpen] = useState<boolean>(false);
  const [isCheckoutModalOpen, setIsCheckoutModalOpen] = useState<boolean>(false);
  const [isReturnModalOpen, setIsReturnModalOpen] = useState<boolean>(false);

  // Form states
  const [editingBoard, setEditingBoard] = useState<Board | null>(null);
  const [boardName, setBoardName] = useState<string>('');
  const [boardModel, setBoardModel] = useState<string>('');
  const [boardLocation, setBoardLocation] = useState<string>('');
  const [boardSerial, setBoardSerial] = useState<string>('');
  const [boardPartId, setBoardPartId] = useState<string>('');
  const [boardLocationId, setBoardLocationId] = useState<string>('');
  const [boardDesc, setBoardDesc] = useState<string>('');
  const [boardStatus, setBoardStatus] = useState<string>('AVAILABLE');
  const [boardQuantity, setBoardQuantity] = useState<number>(1);
  const [boardMinQuantity, setBoardMinQuantity] = useState<number>(0);
  const [boardRemovedParts, setBoardRemovedParts] = useState<string>('');

  // Checkout form states
  const [checkoutNote, setCheckoutNote] = useState<string>('');
  const [checkoutQuantity, setCheckoutQuantity] = useState<number>(1);

  // Warehouse Mode: ALL, BOARDS, PARTS, LOCATIONS, or PART_LOGS
  const [warehouseMode, setWarehouseMode] = useState<'ALL' | 'BOARDS' | 'PARTS' | 'LOCATIONS' | 'PART_LOGS'>(
    initialMode || 'ALL'
  );

  useEffect(() => {
    if (initialMode) {
      setWarehouseMode(initialMode);
    }
  }, [initialMode]);
  const [unifiedTypeFilter, setUnifiedTypeFilter] = useState<'ALL' | 'BOARDS' | 'PARTS'>('ALL');
  const [unifiedStockFilter, setUnifiedStockFilter] = useState<'ALL' | 'IN_STOCK' | 'LOW_STOCK' | 'OUT_OF_STOCK'>('ALL');

  // New Part Modals & QR Scan states
  const [isLocationQrScanModalOpen, setIsLocationQrScanModalOpen] = useState<boolean>(false);
  const [locationScanInitialCode, setLocationScanInitialCode] = useState<string>('');
  const [isPartCheckoutModalOpen, setIsPartCheckoutModalOpen] = useState<boolean>(false);
  const [checkoutInitialLot, setCheckoutInitialLot] = useState<PartLot | null>(null);
  const [isPartReturnModalOpen, setIsPartReturnModalOpen] = useState<boolean>(false);
  const [checkoutHistoryItemToReturn, setCheckoutHistoryItemToReturn] = useState<PartCheckoutHistoryItem | null>(null);


  // Parts state
  const [parts, setParts] = useState<Part[]>([]);
  const [selectedPart, setSelectedPart] = useState<Part | null>(null);
  const [loadingParts, setLoadingParts] = useState<boolean>(false);
  const [partSearchTerm, setPartSearchTerm] = useState<string>('');
  const [partCategoryFilter, setPartCategoryFilter] = useState<string>('ALL');
  const [partStockFilter, setPartStockFilter] = useState<'ALL' | 'IN_STOCK' | 'LOW_STOCK' | 'OUT_OF_STOCK'>('ALL');

  // Part Modals
  const [isPartAddEditModalOpen, setIsPartAddEditModalOpen] = useState<boolean>(false);
  const [isPartBulkImportModalOpen, setIsPartBulkImportModalOpen] = useState<boolean>(false);
  const [isAdjustStockModalOpen, setIsAdjustStockModalOpen] = useState<boolean>(false);

  // Part Form states
  const [editingPart, setEditingPart] = useState<Part | null>(null);
  const [partIpn, setPartIpn] = useState<string>('');
  const [partName, setPartName] = useState<string>('');
  const [partDescription, setPartDescription] = useState<string>('');
  const [partMinAmount, setPartMinAmount] = useState<string>('0');
  const [partCategoryName, setPartCategoryName] = useState<string>('');
  const [partCategoryId, setPartCategoryId] = useState<string>('');
  const [partInitialLocationCode, setPartInitialLocationCode] = useState<string>('');
  const [partInitialQuantity, setPartInitialQuantity] = useState<string>('');

  // Stock Adjustment Form states
  const [adjustLocationCode, setAdjustLocationCode] = useState<string>('');
  const [adjustAmount, setAdjustAmount] = useState<string>('0');
  const [adjustNote, setAdjustNote] = useState<string>('');

  // Autocomplete lists
  const [categories, setCategories] = useState<Array<{ id: string; name: string }>>([]);
  const [locations, setLocations] = useState<Array<{ id: string; code: string; name: string; description?: string; qrCode?: string; totalPartTypes?: number; totalQuantity?: number }>>([]);

  // Location Management Modal States
  const [isLocationManagementModalOpen, setIsLocationManagementModalOpen] = useState<boolean>(false);

  // Add Location Modal States
  const [isAddLocationModalOpen, setIsAddLocationModalOpen] = useState<boolean>(false);
  const [newLocationCode, setNewLocationCode] = useState<string>('');
  const [newLocationName, setNewLocationName] = useState<string>('');
  const [newLocationDesc, setNewLocationDesc] = useState<string>('');
  const [newLocationQr, setNewLocationQr] = useState<string>('');

  // Return form states
  const [returnNote, setReturnNote] = useState<string>('');
  const [returnType, setReturnType] = useState<'FULL' | 'PARTIAL'>('FULL');
  const [returnQuantity, setReturnQuantity] = useState<number>(1);
  const [returnReason, setReturnReason] = useState<string>('');

  // Location QR Print Config Modal States
  const [isQrConfigModalOpen, setIsQrConfigModalOpen] = useState<boolean>(false);
  const [locationsForQrPrint, setLocationsForQrPrint] = useState<LocationQrExportData[]>([]);

  const handleOpenLocationQrPrint = useCallback((locList?: LocationQrExportData[]) => {
    if (locList && locList.length > 0) {
      setLocationsForQrPrint(locList);
    } else {
      setLocationsForQrPrint(
        locations.map((l) => {
          const cleanCode = (l.code || l.qrCode || '').replace(/_QR$/i, '').trim();
          return {
            id: l.id,
            code: cleanCode,
            name: l.name,
            qrCode: cleanCode,
            description: l.description,
            totalPartTypes: l.totalPartTypes,
            totalQuantity: l.totalQuantity,
          };
        })
      );
    }
    setIsQrConfigModalOpen(true);
  }, [locations]);

  const handleSaveLocation = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newLocationCode.trim() || !newLocationName.trim()) {
      showToast('Vui lòng nhập đầy đủ mã và tên vị trí kho');
      return;
    }

    const createdCode = newLocationCode.trim();

    try {
      const response = await fetch('/api/v1/parts/locations', {
        method: 'POST',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({
          code: createdCode,
          name: newLocationName.trim(),
          description: newLocationDesc.trim() || undefined,
          qrCode: newLocationQr.trim() || createdCode,
        }),
      });

      if (response.ok) {
        showToast(`Đã thêm vị trí kho ${createdCode} thành công!`);
        setIsAddLocationModalOpen(false);
        fetchLocations();
        // Auto select in forms
        setPartInitialLocationCode(createdCode);
        setBoardLocation(createdCode);
        setAdjustLocationCode(createdCode);
      } else {
        const err = await response.json().catch(() => ({}));
        showToast(`Lỗi: ${err.message || 'Không thể tạo vị trí kho'}`);
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi tạo vị trí kho');
    }
  };

  // Fetch Boards
  const fetchBoards = useCallback(async () => {
    setLoading(true);
    try {
      const response = await fetch('/api/v1/boards?size=200', {
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        let fetchedBoards: Board[] = [];

        // Backend response wrapper check
        if (result?.data?.content) {
          fetchedBoards = result.data.content;
        } else if (Array.isArray(result?.data)) {
          fetchedBoards = result.data;
        }

        // Map backend properties to model properties if they differ
        const mapped = fetchedBoards.map((b: any) => {
          const checkout = b.activeCheckoutInfo;
          return {
            id: b.id?.toString() || '',
            name: b.name?.toString() || '',
            qrCode: b.qrCode?.toString() || '',
            model: b.model?.toString() || b.category?.toString() || '',
            boardType: b.boardType?.toString() || '',
            firmware: b.firmware?.toString() || '',
            removedParts: b.removedParts?.toString() || '',
            receivedDate: b.receivedDate?.toString() || '',
            note: b.note?.toString() || '',
            location: b.currentLocationCode?.toString() || b.location?.toString() || '',
            status: b.status || 'AVAILABLE',
            checkedOutBy: checkout ? checkout.takenByName : undefined,
            checkedOutAt: checkout ? checkout.takenAt : undefined,
            currentRepairOrder: checkout ? checkout.orderCode : undefined,
            description: b.description,
            serialNumber: b.serialNumber,
            partId: b.partId,
            partIpn: b.partIpn,
            currentLocationId: b.currentLocationId,
            currentLocationCode: b.currentLocationCode,
            quantity: b.quantity || 1,

            activeCheckoutInfo: checkout ? {
              checkoutId: checkout.checkoutId || checkout.id,
              takenBy: checkout.takenBy,
              takenByName: checkout.takenByName,
              takenByEmployeeCode: checkout.takenByEmployeeCode,
              takenAt: checkout.takenAt,
              repairOrderId: checkout.repairOrderId,
              orderCode: checkout.orderCode,
              quantity: checkout.quantity,
              repairBrand: checkout.repairBrand,
            } : undefined,
          };
        });

        setBoards(mapped);
      } else {
        showToast('Không tải được danh sách bo mạch');
      }
    } catch (e) {
      console.error(e);
      showToast('Lỗi kết nối server');
    } finally {
      setLoading(false);
    }
  }, [showToast]);



  const fetchParts = useCallback(async () => {
    setLoadingParts(true);
    try {
      const response = await fetch('/api/v1/parts?size=200', {
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        let fetchedParts: Part[] = [];
        if (result?.data?.content) {
          fetchedParts = result.data.content;
        } else if (Array.isArray(result?.data)) {
          fetchedParts = result.data;
        }
        setParts(fetchedParts);
      } else {
        showToast('Không tải được danh sách linh kiện');
      }
    } catch (e) {
      console.error(e);
      showToast('Lỗi kết nối khi tải linh kiện');
    } finally {
      setLoadingParts(false);
    }
  }, [showToast]);

  const fetchCategories = useCallback(async () => {
    try {
      const response = await fetch('/api/v1/parts/categories', {
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data) {
          setCategories(result.data);
        }
      }
    } catch (e) {
      console.error(e);
    }
  }, []);

  const fetchLocations = useCallback(async () => {
    try {
      const response = await fetch('/api/v1/parts/locations', {
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data) {
          setLocations(result.data);
        }
      }
    } catch (e) {
      console.error(e);
    }
  }, []);

  // Synchronize selectedBoard state with updated data in boards list
  useEffect(() => {
    if (selectedBoard) {
      const updatedSelected = boards.find((b) => b.id === selectedBoard.id);
      if (updatedSelected) {
        if (
          updatedSelected.status !== selectedBoard.status ||
          updatedSelected.checkedOutBy !== selectedBoard.checkedOutBy ||
          updatedSelected.location !== selectedBoard.location ||
          updatedSelected.name !== selectedBoard.name ||
          updatedSelected.quantity !== selectedBoard.quantity
        ) {
          setSelectedBoard(updatedSelected);
        }
      }
    }
  }, [boards, selectedBoard]);

  // Synchronize selectedPart state with updated data in parts list
  useEffect(() => {
    if (selectedPart) {
      const updatedSelected = parts.find((p) => p.id === selectedPart.id);
      if (updatedSelected) {
        setSelectedPart(updatedSelected);
      }
    }
  }, [parts, selectedPart]);

  useEffect(() => {
    fetchBoards();
    fetchParts();
    fetchCategories();
    fetchLocations();
  }, [fetchBoards, fetchParts, fetchCategories, fetchLocations]);

  // Fetch Board History logs
  const fetchBoardHistory = async (boardId: string) => {
    setLoadingHistory(true);
    try {
      const response = await fetch(`/api/v1/boards/${boardId}/history`, {
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        let historyData = result?.data || [];
        if (result?.data?.content) {
          historyData = result.data.content;
        }

        const mappedHistory = historyData.map((h: any) => ({
          id: h.checkoutId?.toString() || h.id?.toString() || '',
          boardId: h.boardItemId?.toString() || h.boardId?.toString() || '',
          boardName: h.boardName?.toString() || '',
          qrCode: h.qrCode?.toString() || '',
          takenBy: h.takenBy?.toString() || '',
          takenByName: h.takenByName?.toString() || 'Không xác định',
          takenAt: h.takenAt,
          returnedAt: h.returnAt || h.returnedAt,
          repairOrderId: h.repairOrderId?.toString(),
          notes: h.note || h.notes,
        }));

        setBoardHistory(mappedHistory);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoadingHistory(false);
    }
  };

  const handleSelectBoard = (board: Board) => {
    setSelectedBoard(board);
    fetchBoardHistory(board.id);
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'AVAILABLE':
        return 'Sẵn sàng';
      case 'CHECKED_OUT':
      case 'IN_USE':
        return 'Đang dùng';
      case 'IN_REPAIR':
        return 'Đang sửa';
      case 'DAMAGED':
        return 'Hỏng';
      case 'LOST':
        return 'Mất';
      case 'ARCHIVED':
      case 'RETIRED':
        return 'Lưu trữ';
      case 'MAINTENANCE':
        return 'Bảo trì';
      default:
        return status;
    }
  };

  const getStatusColorClass = (status: string) => {
    switch (status) {
      case 'AVAILABLE':
        return 'board-available';
      case 'CHECKED_OUT':
      case 'IN_USE':
        return 'board-checkedout';
      case 'IN_REPAIR':
        return 'board-inrepair';
      case 'DAMAGED':
        return 'board-damaged';
      case 'LOST':
        return 'board-lost';
      case 'ARCHIVED':
      case 'RETIRED':
        return 'board-archived';
      case 'MAINTENANCE':
        return 'board-maintenance';
      default:
        return '';
    }
  };

  // Filters
  const filteredBoards = boards.filter((board) => {
    let term = searchTerm.trim().toLowerCase();
    
    // Extract QR code if user pasted a formatted block like "MÃ QR: BM-2026-YAS-001"
    const qrMatch = term.match(/mã qr:\s*([^\n\r]+)/i);
    if (qrMatch && qrMatch[1]) {
      term = qrMatch[1].trim().toLowerCase();
    }

    const matchesSearch =
      board.name.toLowerCase().includes(term) ||
      board.qrCode.toLowerCase().includes(term) ||
      board.model.toLowerCase().includes(term) ||
      board.location.toLowerCase().includes(term) ||
      (board.serialNumber && board.serialNumber.toLowerCase().includes(term)) ||
      (board.partIpn && board.partIpn.toLowerCase().includes(term));

    const matchesStatus = statusFilter === 'ALL' || board.status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  // Open Create/Edit modal
  const openAddEditModal = (board: Board | null = null) => {
    setEditingBoard(board);
    if (board) {
      setBoardName(board.name);
      setBoardModel(board.model);
      setBoardLocation(board.location);
      setBoardSerial(board.serialNumber || '');
      setBoardPartId(board.partId || board.partIpn || '');
      setBoardLocationId(board.currentLocationId || board.currentLocationCode || '');
      setBoardDesc(board.description || '');
      setBoardStatus(board.status);
      setBoardQuantity(board.quantity || 1);
      setBoardMinQuantity(board.minQuantity || 0);
      setBoardRemovedParts(board.removedParts || '');
    } else {
      setBoardName('');
      setBoardModel('');
      setBoardLocation('');
      setBoardSerial('');
      setBoardPartId('');
      setBoardLocationId('');
      setBoardDesc('');
      setBoardStatus('AVAILABLE');
      setBoardQuantity(1);
      setBoardMinQuantity(0);
      setBoardRemovedParts('');
    }
    setIsAddEditModalOpen(true);
  };

  // Submit Add/Edit API
  const handleSaveBoard = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!boardName.trim()) {
      showToast('Vui lòng nhập tên bo mạch');
      return;
    }

    const payload: Record<string, any> = {
      name: boardName.trim(),
      category: boardModel.trim(),
      location: boardLocation.trim(),
      description: boardDesc.trim(),
      serialNumber: boardSerial.trim() || null,
      status: boardStatus,
      quantity: boardQuantity,
      minQuantity: boardMinQuantity,
      removedParts: boardRemovedParts.trim() || null,
    };

    if (boardPartId.trim()) {
      payload.partId = boardPartId.trim();
    }
    if (boardLocationId.trim()) {
      payload.currentLocationId = boardLocationId.trim();
    }

    try {
      let response;
      if (editingBoard) {
        response = await fetch(`/api/v1/boards/${editingBoard.id}`, {
          method: 'PATCH',
          headers: getJsonAuthHeaders(),
          body: JSON.stringify(payload),
        });
      } else {
        response = await fetch('/api/v1/boards', {
          method: 'POST',
          headers: getJsonAuthHeaders(),
          body: JSON.stringify(payload),
        });
      }

      if (response.ok) {
        showToast(editingBoard ? 'Cập nhật bo mạch thành công!' : 'Thêm bo mạch thành công!');
        setIsAddEditModalOpen(false);
        fetchBoards();
      } else {
        const errData = await response.json();
        showToast(`Lỗi: ${errData.message || 'Không thể lưu bo mạch'}`);
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối lưu bo mạch');
    }
  };

  // Delete Board API
  const handleDeleteBoard = async () => {
    if (!selectedBoard) return;
    if (!confirm(`Bạn có chắc chắn muốn xóa bo mạch ${selectedBoard.name}?`)) return;

    try {
      const response = await fetch(`/api/v1/boards/${selectedBoard.id}`, {
        method: 'DELETE',
        headers: getAuthHeaders(),
      });

      if (response.ok) {
        showToast('Xóa bo mạch thành công!');
        setSelectedBoard(null);
        fetchBoards();
      } else {
        showToast('Xóa bo mạch thất bại');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối xóa bo mạch');
    }
  };

  // Open Part Add/Edit modal
  const openAddEditPartModal = (part: Part | null = null) => {
    setEditingPart(part);
    if (part) {
      setPartIpn(part.ipn);
      setPartName(part.name);
      setPartDescription(part.description || '');
      setPartMinAmount(part.minAmount.toString());
      setPartCategoryName(part.categoryName || '');
      setPartCategoryId(part.categoryId || '');
      setPartInitialLocationCode(part.lots?.[0]?.storeLocationCode || '');
      setPartInitialQuantity(part.totalQuantity ? part.totalQuantity.toString() : '');
    } else {
      setPartIpn('');
      setPartName('');
      setPartDescription('');
      setPartMinAmount('0');
      setPartCategoryName('');
      setPartCategoryId('');
      setPartInitialLocationCode(locations.length > 0 ? locations[0].code : '');
      setPartInitialQuantity('');
    }
    setIsPartAddEditModalOpen(true);
  };

  // Submit Part Add/Edit API
  const handleSavePart = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!partIpn.trim()) {
      showToast('Vui lòng nhập mã IPN');
      return;
    }
    if (!partName.trim()) {
      showToast('Vui lòng nhập tên linh kiện');
      return;
    }

    const payload: Record<string, any> = {
      ipn: partIpn.trim(),
      name: partName.trim(),
      description: partDescription.trim(),
      minAmount: parseFloat(partMinAmount) || 0,
    };

    if (partCategoryId) {
      payload.categoryId = partCategoryId;
    } else if (partCategoryName.trim()) {
      payload.categoryName = partCategoryName.trim();
    }

    try {
      let response;
      if (editingPart) {
        response = await fetch(`/api/v1/parts/${editingPart.id}`, {
          method: 'PATCH',
          headers: getJsonAuthHeaders(),
          body: JSON.stringify(payload),
        });
      } else {
        response = await fetch('/api/v1/parts', {
          method: 'POST',
          headers: getJsonAuthHeaders(),
          body: JSON.stringify(payload),
        });
      }

      if (response.ok) {
        const resData = await response.json().catch(() => ({}));
        const createdPart = resData?.data;

        // If creating new part and initial location & quantity are provided, adjust stock immediately
        if (!editingPart && createdPart?.id && partInitialLocationCode && parseFloat(partInitialQuantity) > 0) {
          try {
            await fetch(`/api/v1/parts/${createdPart.id}/adjust-stock`, {
              method: 'POST',
              headers: getJsonAuthHeaders(),
              body: JSON.stringify({
                locationCode: partInitialLocationCode.trim(),
                quantity: parseFloat(partInitialQuantity),
                note: 'Khởi tạo vị trí & số lượng kho ban đầu',
              }),
            });
          } catch (err) {
            console.error('Error setting initial stock for part:', err);
          }
        }

        showToast(editingPart ? 'Cập nhật linh kiện thành công!' : 'Thêm linh kiện thành công!');
        setIsPartAddEditModalOpen(false);
        fetchParts();
        fetchCategories();
        fetchLocations();
        if (editingPart && selectedPart && selectedPart.id === editingPart.id) {
          const updatedResp = await fetch(`/api/v1/parts/${editingPart.id}`, {
            headers: getAuthHeaders(),
          });
          if (updatedResp.ok) {
            const updatedPart = await updatedResp.json();
            setSelectedPart(updatedPart.data);
          }
        }
      } else {
        const errData = await response.json();
        showToast(`Lỗi: ${errData.message || 'Không thể lưu linh kiện'}`);
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối lưu linh kiện');
    }
  };

  // Delete Part API
  const handleDeletePart = async () => {
    if (!selectedPart) return;
    if (!confirm(`Bạn có chắc chắn muốn xóa linh kiện ${selectedPart.name}?`)) return;

    try {
      const response = await fetch(`/api/v1/parts/${selectedPart.id}`, {
        method: 'DELETE',
        headers: getAuthHeaders(),
      });

      if (response.ok) {
        showToast('Xóa linh kiện thành công!');
        setSelectedPart(null);
        fetchParts();
      } else {
        const errData = await response.json();
        showToast(`Lỗi: ${errData.message || 'Xóa linh kiện thất bại'}`);
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối xóa linh kiện');
    }
  };

  // Open Adjust Stock Modal
  const openAdjustStockModal = () => {
    setAdjustLocationCode('');
    setAdjustAmount('0');
    setAdjustNote('');
    setIsAdjustStockModalOpen(true);
  };

  // Submit Adjust Stock API
  const handleAdjustStock = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedPart) return;
    if (!adjustLocationCode.trim()) {
      showToast('Vui lòng nhập vị trí kho');
      return;
    }

    try {
      const response = await fetch(`/api/v1/parts/${selectedPart.id}/adjust-stock`, {
        method: 'POST',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({
          storeLocationCode: adjustLocationCode.trim(),
          amount: parseFloat(adjustAmount) || 0,
          note: adjustNote.trim() || undefined,
        }),
      });

      if (response.ok) {
        showToast('Điều chỉnh số lượng tồn kho thành công!');
        setIsAdjustStockModalOpen(false);
        fetchParts();
        fetchLocations();
        
        const updatedResp = await fetch(`/api/v1/parts/${selectedPart.id}`, {
          headers: getAuthHeaders(),
        });
        if (updatedResp.ok) {
          const updatedPart = await updatedResp.json();
          setSelectedPart(updatedPart.data);
        }
      } else {
        const errData = await response.json();
        showToast(`Lỗi: ${errData.message || 'Điều chỉnh kho thất bại'}`);
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối điều chỉnh kho');
    }
  };

  // Filtered Parts
  const filteredParts = parts.filter((part) => {
    const term = partSearchTerm.toLowerCase().trim();
    const matchesSearch = !term || (
      part.name.toLowerCase().includes(term) ||
      part.ipn.toLowerCase().includes(term) ||
      (part.categoryName && part.categoryName.toLowerCase().includes(term)) ||
      (part.description && part.description.toLowerCase().includes(term)) ||
      (part.lots && part.lots.some(l =>
        (l.storeLocationCode && l.storeLocationCode.toLowerCase().includes(term)) ||
        (l.storeLocationName && l.storeLocationName.toLowerCase().includes(term))
      ))
    );

    const matchesCategory = partCategoryFilter === 'ALL' ||
      part.categoryName === partCategoryFilter ||
      part.categoryId === partCategoryFilter;

    let matchesStock = true;
    if (partStockFilter === 'IN_STOCK') {
      matchesStock = part.totalQuantity > 0;
    } else if (partStockFilter === 'LOW_STOCK') {
      matchesStock = part.totalQuantity < part.minAmount && part.totalQuantity > 0;
    } else if (partStockFilter === 'OUT_OF_STOCK') {
      matchesStock = part.totalQuantity === 0;
    }

    return matchesSearch && matchesCategory && matchesStock;
  });

  // Open Checkout Modal
  const openCheckoutModal = () => {
    setCheckoutNote('');
    setCheckoutQuantity(1);
    setIsCheckoutModalOpen(true);
  };

  // Checkout API
  const handleCheckoutBoard = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedBoard) return;

    const availableStock = selectedBoard.quantity || 0;
    if (checkoutQuantity > availableStock) {
      showToast(`Không đủ số lượng! Tồn kho: ${availableStock}, yêu cầu: ${checkoutQuantity}`);
      return;
    }

    try {
      const response = await fetch(`/api/v1/boards/${selectedBoard.id}/checkout`, {
        method: 'POST',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({
          note: checkoutNote.trim() || undefined,
          quantity: checkoutQuantity || 1,
        }),
      });

      if (response.ok) {
        showToast(`Đã lấy ${checkoutQuantity} linh kiện thành công!`);
        setIsCheckoutModalOpen(false);
        fetchBoards();
        fetchBoardHistory(selectedBoard.id);
      } else {
        const errData = await response.json().catch(() => ({}));
        showToast(`Lấy bo mạch thất bại: ${errData.message || 'Lỗi không xác định'}`);
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi checkout');
    }
  };

  // Open Return Modal
  const openReturnModal = () => {
    setReturnNote('');
    setReturnType('FULL');
    setReturnQuantity(1);
    setReturnReason('');
    setIsReturnModalOpen(true);
  };

  // Return API
  const handleReturnBoard = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedBoard) return;

    // Validation: partial return requires a quantity
    if (returnType === 'PARTIAL' && (!returnQuantity || returnQuantity < 1)) {
      showToast('Vui lòng nhập số lượng trả lại hợp lệ');
      return;
    }

    const payload: Record<string, any> = {
      checkoutId: selectedBoard.activeCheckoutInfo?.checkoutId,
      returnType,
      notes: returnNote.trim() || undefined,
      reason: returnReason.trim() || undefined,
    };
    if (returnType === 'PARTIAL') {
      payload.returnQuantity = returnQuantity;
    }

    try {
      const response = await fetch(`/api/v1/boards/${selectedBoard.id}/return`, {
        method: 'PATCH',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify(payload),
      });

      if (response.ok) {
        const isPartial = returnType === 'PARTIAL';
        showToast(isPartial ? `Đã ghi nhận trả ${returnQuantity} linh kiện (một phần).` : 'Trả bo mạch về kho thành công!');
        setIsReturnModalOpen(false);
        fetchBoards();
        fetchBoardHistory(selectedBoard.id);
      } else {
        const errData = await response.json().catch(() => ({}));
        showToast(`Trả bo mạch thất bại: ${errData.message || 'Lỗi không xác định'}`);
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi trả board');
    }
  };

  return (
    <div className="warehouse-container">
      {/* Top Header Mode Switcher & Quick QR Scan Bar */}
      <div className="warehouse-header-bar">
        <div style={{ display: 'flex', gap: '6px', backgroundColor: 'var(--color-bg, #f1f5f9)', padding: '4px', borderRadius: '10px', border: '1px solid var(--color-border, #e2e8f0)' }}>
          <button
            type="button"
            className={`warehouse-mode-btn ${warehouseMode === 'ALL' ? 'active' : ''}`}
            onClick={() => {
              setWarehouseMode('ALL');
              setSelectedBoard(null);
              setSelectedPart(null);
            }}
          >
            🏢 Tất Cả Kho ({boards.length + parts.length})
          </button>
          <button
            type="button"
            className={`warehouse-mode-btn ${warehouseMode === 'PARTS' ? 'active' : ''}`}
            onClick={() => {
              setWarehouseMode('PARTS');
              setSelectedBoard(null);
            }}
          >
            🧱 Kho Linh Kiện ({parts.length})
          </button>
          <button
            type="button"
            className={`warehouse-mode-btn ${warehouseMode === 'BOARDS' ? 'active' : ''}`}
            onClick={() => {
              setWarehouseMode('BOARDS');
              setSelectedPart(null);
            }}
          >
            📱 Bo Mạch ({boards.length})
          </button>
          <button
            type="button"
            className={`warehouse-mode-btn ${warehouseMode === 'LOCATIONS' ? 'active' : ''}`}
            onClick={() => {
              setWarehouseMode('LOCATIONS');
              setSelectedBoard(null);
              setSelectedPart(null);
            }}
          >
            📍 Vị Trí Kho ({locations.length})
          </button>
          <button
            type="button"
            className={`warehouse-mode-btn ${warehouseMode === 'PART_LOGS' ? 'active' : ''}`}
            onClick={() => setWarehouseMode('PART_LOGS')}
          >
            📜 Nhật Ký Lấy/Trả
          </button>
        </div>

        {warehouseMode !== 'LOCATIONS' && (
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <button
              type="button"
              onClick={() => {
                setLocationScanInitialCode('');
                setIsLocationQrScanModalOpen(true);
              }}
              style={{ backgroundColor: '#2563eb', color: '#ffffff', border: 'none', padding: '8px 16px', borderRadius: '8px', fontWeight: 600, fontSize: '0.88rem', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '6px' }}
            >
              <QrCode size={16} />
              Quét QR Vị Trí
            </button>

            <button
              type="button"
              onClick={() => handleOpenLocationQrPrint()}
              style={{ backgroundColor: '#ffffff', color: '#2563eb', border: '1.5px solid #bfdbfe', padding: '8px 14px', borderRadius: '8px', fontWeight: 600, fontSize: '0.88rem', cursor: 'pointer' }}
            >
              🏷️ In Tem QR
            </button>
          </div>
        )}
      </div>

      {warehouseMode === 'LOCATIONS' ? (
        <div style={{ flex: 1, minHeight: '550px' }}>
          <LocationListPanel
            locations={locations}
            onRefreshLocations={fetchLocations}
            onPrintLocationQr={(loc) => {
              handleOpenLocationQrPrint([
                {
                  id: loc.id,
                  code: loc.code,
                  name: loc.name,
                  qrCode: loc.qrCode || loc.code,
                  description: loc.description,
                  totalPartTypes: loc.totalPartTypes,
                  totalQuantity: loc.totalQuantity,
                },
              ]);
            }}
            onPrintAllLocationsQr={() => handleOpenLocationQrPrint()}
            onScanLocationQr={() => {
              setLocationScanInitialCode('');
              setIsLocationQrScanModalOpen(true);
            }}
            onViewLocationParts={(locCode) => {
              setWarehouseMode('PARTS');
              setPartSearchTerm(locCode);
            }}
            showToast={showToast}
          />
        </div>
      ) : warehouseMode === 'PART_LOGS' ? (
        <div style={{ flex: 1, minHeight: '550px' }}>
          <PartCheckoutHistoryPanel
            showToast={showToast}
            onReturnClick={(item) => {
              setCheckoutHistoryItemToReturn(item);
              setIsPartReturnModalOpen(true);
            }}
          />
        </div>
      ) : (
        <div className="warehouse-layout">
          {/* Left Column: Stats, Filter & Grid */}
          <div className="warehouse-main-panel">
            {warehouseMode === 'ALL' ? (
              <UnifiedListPanel
                boards={boards}
                parts={parts}
                loading={loading || loadingParts}
                searchTerm={searchTerm}
                setSearchTerm={setSearchTerm}
                typeFilter={unifiedTypeFilter}
                setTypeFilter={setUnifiedTypeFilter}
                stockFilter={unifiedStockFilter}
                setStockFilter={setUnifiedStockFilter}
                onSelectBoard={(b) => {
                  setSelectedPart(null);
                  handleSelectBoard(b);
                }}
                onSelectPart={(p) => {
                  setSelectedBoard(null);
                  setSelectedPart(p);
                }}
                onAddBoard={() => openAddEditModal(null)}
                onAddPart={() => openAddEditPartModal(null)}
                onQuickCheckoutPart={(p, lot) => {
                  setSelectedPart(p);
                  setCheckoutInitialLot(lot || (p.lots && p.lots.length > 0 ? p.lots[0] : null));
                  setIsPartCheckoutModalOpen(true);
                }}
                onQuickCheckoutBoard={(b) => {
                  setSelectedBoard(b);
                  setCheckoutQuantity(1);
                  setCheckoutNote('');
                  setIsCheckoutModalOpen(true);
                }}
                onScanLocationQr={() => {
                  setLocationScanInitialCode('');
                  setIsLocationQrScanModalOpen(true);
                }}
                onOpenLocationManagement={() => setIsLocationManagementModalOpen(true)}
              />
            ) : warehouseMode === 'BOARDS' ? (
              <BoardListPanel
                boards={boards}
                loading={loading}
                searchTerm={searchTerm}
                setSearchTerm={setSearchTerm}
                statusFilter={statusFilter}
                setStatusFilter={setStatusFilter}
                filteredBoards={filteredBoards}
                selectedBoard={selectedBoard}
                handleSelectBoard={handleSelectBoard}
                openAddEditModal={openAddEditModal}
                openAddLocationModal={() => {
                  setNewLocationCode('');
                  setNewLocationName('');
                  setNewLocationDesc('');
                  setNewLocationQr('');
                  setIsAddLocationModalOpen(true);
                }}
                getStatusLabel={getStatusLabel}
                getStatusColorClass={getStatusColorClass}
              />
            ) : (
              <PartListPanel
                parts={parts}
                loadingParts={loadingParts}
                partSearchTerm={partSearchTerm}
                setPartSearchTerm={setPartSearchTerm}
                filteredParts={filteredParts}
                selectedPart={selectedPart}
                setSelectedPart={setSelectedPart}
                categories={categories}
                partCategoryFilter={partCategoryFilter}
                setPartCategoryFilter={setPartCategoryFilter}
                partStockFilter={partStockFilter}
                setPartStockFilter={setPartStockFilter}
                openAddEditPartModal={openAddEditPartModal}
                openBulkImportModal={() => setIsPartBulkImportModalOpen(true)}
                openAddLocationModal={() => {
                  setNewLocationCode('');
                  setNewLocationName('');
                  setNewLocationDesc('');
                  setNewLocationQr('');
                  setIsAddLocationModalOpen(true);
                }}
                openLocationQrScanModal={(code) => {
                  setLocationScanInitialCode(code || '');
                  setIsLocationQrScanModalOpen(true);
                }}
                openLocationQrPrintModal={handleOpenLocationQrPrint}
                onQuickCheckoutPart={(part) => {
                  setSelectedPart(part);
                  setIsPartCheckoutModalOpen(true);
                }}
              />
            )}
          </div>

          {/* Right Column: Spec Detail Pane */}
          <div className="warehouse-detail-panel">
            {warehouseMode === 'BOARDS' ? (
              selectedBoard ? (
                <BoardDetailPanel
                  selectedBoard={selectedBoard}
                  getStatusLabel={getStatusLabel}
                  getStatusColorClass={getStatusColorClass}
                  openAddEditModal={openAddEditModal}
                  handleDeleteBoard={handleDeleteBoard}
                  openCheckoutModal={openCheckoutModal}
                  openReturnModal={openReturnModal}
                  loadingHistory={loadingHistory}
                  boardHistory={boardHistory}
                  onOpenLocationScan={(loc) => {
                    setLocationScanInitialCode(loc);
                    setIsLocationQrScanModalOpen(true);
                  }}
                />
              ) : (
                <div className="detail-empty-state">
                  <Cpu size={48} className="empty-icon" />
                  <h3>Chọn một bo mạch</h3>
                  <p>Chọn bo mạch từ danh sách kho để xem thông số kỹ thuật, lịch sử chuyển dịch và mượn trả.</p>
                </div>
              )
            ) : (
              selectedPart ? (
                <PartDetailPanel
                  selectedPart={selectedPart}
                  openAddEditPartModal={openAddEditPartModal}
                  handleDeletePart={handleDeletePart}
                  openAdjustStockModal={openAdjustStockModal}
                  openPartCheckoutModal={() => setIsPartCheckoutModalOpen(true)}
                  onOpenLocationScan={(loc) => {
                    setLocationScanInitialCode(loc);
                    setIsLocationQrScanModalOpen(true);
                  }}
                />
              ) : (
                <div className="detail-empty-state">
                  <Boxes size={48} className="empty-icon" />
                  <h3>Chọn một linh kiện</h3>
                  <p>Chọn linh kiện từ danh mục để xem định mức, vị trí kho, lấy linh kiện out kho và điều chỉnh số lượng tồn kho.</p>
                </div>
              )
            )}
          </div>
        </div>
      )}


      {/* ADD / EDIT BOARD DIALOG */}
      {isAddEditModalOpen && (
        <div className="w-modal-overlay">
          <div className="w-modal-card">
            <div className="modal-header">
              <h3>{editingBoard ? 'Chỉnh sửa bo mạch' : 'Thêm bo mạch mới'}</h3>
              <button className="close-modal-btn" onClick={() => setIsAddEditModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleSaveBoard} className="modal-form">
              <div className="form-group">
                <label>Tên bo mạch *</label>
                <input
                  type="text"
                  required
                  value={boardName}
                  onChange={(e) => setBoardName(e.target.value)}
                  placeholder="Bo mạch điều khiển biến tần Delta"
                />
              </div>

              <div className="form-row-grid">
                <div className="form-group">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' }}>
                    <label style={{ margin: 0 }}>Vị trí lưu kho có sẵn</label>
                    <button
                      type="button"
                      onClick={() => {
                        setNewLocationCode('');
                        setNewLocationName('');
                        setNewLocationDesc('');
                        setNewLocationQr('');
                        setIsAddLocationModalOpen(true);
                      }}
                      style={{ background: 'none', border: 'none', color: '#2563eb', fontSize: '0.8rem', cursor: 'pointer', padding: 0, fontWeight: 600 }}
                    >
                      + Thêm vị trí mới
                    </button>
                  </div>
                  <select
                    value={boardLocation}
                    onChange={(e) => setBoardLocation(e.target.value)}
                    className="w-status-select"
                    style={{ width: '100%' }}
                  >
                    <option value="">-- Chọn vị trí kho có sẵn --</option>
                    {locations.map((loc) => (
                      <option key={loc.id} value={loc.code}>
                        {loc.code} {loc.name ? `(${loc.name})` : ''}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label>Số lượng *</label>
                  <input
                    type="number"
                    required
                    min="1"
                    value={boardQuantity}
                    onChange={(e) => setBoardQuantity(parseInt(e.target.value) || 1)}
                    placeholder="1"
                  />
                </div>
                <div className="form-group">
                  <label>Định mức tối thiểu (Min stock)</label>
                  <input
                    type="number"
                    min="0"
                    value={boardMinQuantity}
                    onChange={(e) => setBoardMinQuantity(parseInt(e.target.value) || 0)}
                    placeholder="0"
                  />
                </div>
              </div>

              <div className="form-group">
                <label>Linh kiện đã rã / tháo (Bo xác)</label>
                <input
                  type="text"
                  value={boardRemovedParts}
                  onChange={(e) => setBoardRemovedParts(e.target.value)}
                  placeholder="VD: IC nguồn U1, Diode D4, Tụ C12..."
                />
              </div>

              {editingBoard && (
                <div className="form-group">
                  <label>Trạng thái bo mạch *</label>
                  <select
                    value={boardStatus}
                    onChange={(e) => setBoardStatus(e.target.value)}
                    required
                  >
                    <option value="AVAILABLE">Sẵn sàng</option>
                    <option value="CHECKED_OUT">Đang dùng</option>
                    <option value="IN_REPAIR">Đang sửa</option>
                    <option value="DAMAGED">Hỏng</option>
                    <option value="LOST">Mất</option>
                    <option value="ARCHIVED">Lưu trữ</option>
                    <option value="MAINTENANCE">Bảo trì</option>
                  </select>
                </div>
              )}

              <div className="form-group">
                <label>Mô tả bo mạch</label>
                <textarea
                  value={boardDesc}
                  onChange={(e) => setBoardDesc(e.target.value)}
                  placeholder="Thông tin tình trạng board, lỗi linh kiện đi kèm..."
                  rows={3}
                />
              </div>

              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsAddEditModalOpen(false)}>
                  Hủy
                </button>
                <button type="submit" className="btn-submit">
                  {editingBoard ? 'Lưu thay đổi' : 'Thêm bo mạch'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* CHECKOUT BOARD MODAL */}
      {isCheckoutModalOpen && (
        <div className="w-modal-overlay">
          <div className="w-modal-card small">
            <div className="modal-header">
              <h3>Mượn bo mạch / Checkout</h3>
              <button className="close-modal-btn" onClick={() => setIsCheckoutModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleCheckoutBoard} className="modal-form">

              {/* Stock info banner */}
              <div className="checkout-stock-banner">
                <span className="stock-label">Tồn kho hiện tại:</span>
                <span className={`stock-value ${(selectedBoard?.quantity || 0) > 0 ? 'ok' : 'empty'}`}>
                  {selectedBoard?.quantity || 0} cái
                </span>
              </div>

              <div className="form-group">
                <label>Số lượng lấy *</label>
                <input
                  type="number"
                  min={1}
                  max={selectedBoard?.quantity || 1}
                  value={checkoutQuantity}
                  onChange={(e) => setCheckoutQuantity(parseInt(e.target.value) || 1)}
                  required
                />
                {checkoutQuantity > (selectedBoard?.quantity || 0) && (
                  <span className="field-error-msg">
                    &#9888; Không đủ số lượng! Tồn kho: {selectedBoard?.quantity || 0}
                  </span>
                )}
              </div>

              <div className="form-group">
                <label>Ghi chú (sử dụng cho hãng nào)</label>
                <textarea
                  value={checkoutNote}
                  onChange={(e) => setCheckoutNote(e.target.value)}
                  placeholder="Nhập hãng sử dụng hoặc ghi chú khác (ví dụ: Mitsubishi, Siemens, Omron...)"
                  rows={3}
                />
              </div>

              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsCheckoutModalOpen(false)}>
                  Hủy
                </button>
                <button
                  type="submit"
                  className="btn-submit"
                  disabled={checkoutQuantity > (selectedBoard?.quantity || 0)}
                >
                  Xác nhận mượn
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* RETURN BOARD MODAL */}
      {isReturnModalOpen && (
        <div className="w-modal-overlay">
          <div className="w-modal-card small">
            <div className="modal-header">
              <h3>Trả bo mạch về kho</h3>
              <button className="close-modal-btn" onClick={() => setIsReturnModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleReturnBoard} className="modal-form">

              {/* Return type selection */}
              <div className="form-group">
                <label>Chọn hình thức trả *</label>
                <div className="return-type-options">
                  <div
                    className={`return-type-card ${returnType === 'FULL' ? 'selected' : ''}`}
                    onClick={() => setReturnType('FULL')}
                  >
                    <div className="return-type-icon">✅</div>
                    <div className="return-type-text">
                      <strong>Trả lại hết</strong>
                      <span>Trả toàn bộ số lượng đã lấy ra. Nếu thiếu, hãy ghi rõ lý do.</span>
                    </div>
                  </div>
                  <div
                    className={`return-type-card ${returnType === 'PARTIAL' ? 'selected' : ''}`}
                    onClick={() => setReturnType('PARTIAL')}
                  >
                    <div className="return-type-icon">📦</div>
                    <div className="return-type-text">
                      <strong>Trả lại một phần</strong>
                      <span>Chỉ trả lại một phần, bo mạch vẫn đang được sử dụng.</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Partial quantity input */}
              {returnType === 'PARTIAL' && (
                <div className="form-group">
                  <label>Số lượng trả lại *</label>
                  <input
                    type="number"
                    min={1}
                    value={returnQuantity}
                    onChange={(e) => setReturnQuantity(parseInt(e.target.value) || 1)}
                    required
                    placeholder="Nhập số lượng trả lại..."
                  />
                </div>
              )}

              {/* Reason / shortage explanation */}
              <div className="form-group">
                <label>
                  {returnType === 'FULL'
                    ? 'Lý do bị thiếu (nếu không đủ số lượng lấy ra)'
                    : 'Lý do trả một phần'}
                </label>
                <textarea
                  value={returnReason}
                  onChange={(e) => setReturnReason(e.target.value)}
                  placeholder={returnType === 'FULL'
                    ? 'Ví dụ: Mất 2 linh kiện trong quá trình sửa, hỏng không dùng được...'
                    : 'Ví dụ: Chỉ dùng xong một phần, phần còn lại tiếp tục dùng...'}
                  rows={2}
                />
              </div>

              <div className="form-group">
                <label>Ghi chú sau sửa chữa</label>
                <textarea
                  value={returnNote}
                  onChange={(e) => setReturnNote(e.target.value)}
                  placeholder="Ghi chú thêm về trạng thái board sau khi sử dụng..."
                  rows={2}
                />
              </div>

              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsReturnModalOpen(false)}>
                  Hủy
                </button>
                <button type="submit" className="btn-submit">
                  {returnType === 'FULL' ? 'Xác nhận trả hết' : 'Xác nhận trả một phần'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ADD / EDIT PART DIALOG */}
      {isPartAddEditModalOpen && (
        <div className="w-modal-overlay">
          <div className="w-modal-card">
            <div className="modal-header">
              <h3>{editingPart ? 'Chỉnh sửa linh kiện' : 'Thêm linh kiện mới'}</h3>
              <button className="close-modal-btn" onClick={() => setIsPartAddEditModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleSavePart} className="modal-form">
              <div className="form-row-grid">
                <div className="form-group">
                  <label>Mã IPN *</label>
                  <input
                    type="text"
                    required
                    value={partIpn}
                    onChange={(e) => setPartIpn(e.target.value)}
                    placeholder="VD: IPN-001, CAP-10UF-50V..."
                  />
                </div>
                <div className="form-group">
                  <label>Tên linh kiện *</label>
                  <input
                    type="text"
                    required
                    value={partName}
                    onChange={(e) => setPartName(e.target.value)}
                    placeholder="VD: Tụ điện 10uF 50V"
                  />
                </div>
              </div>

              <div className="form-row-grid">
                <div className="form-group">
                  <label>Định mức tối thiểu (để báo sắp hết)</label>
                  <input
                    type="number"
                    min="0"
                    step="0.0001"
                    value={partMinAmount}
                    onChange={(e) => setPartMinAmount(e.target.value)}
                    placeholder="0"
                  />
                </div>
                <div className="form-group">
                  <label>Danh mục / Phân loại</label>
                  <input
                    type="text"
                    value={partCategoryName}
                    onChange={(e) => setPartCategoryName(e.target.value)}
                    placeholder="VD: Tụ điện, Điện trở..."
                    list="category-suggestions"
                  />
                  <datalist id="category-suggestions">
                    {categories.map((cat) => (
                      <option key={cat.id} value={cat.name} />
                    ))}
                  </datalist>
                </div>
              </div>

              <div className="form-group">
                <label>Mô tả linh kiện</label>
                <textarea
                  value={partDescription}
                  onChange={(e) => setPartDescription(e.target.value)}
                  placeholder="Nhập thông số kỹ thuật, hãng sản xuất, ghi chú..."
                  rows={2}
                />
              </div>

              {!editingPart && (
                <div className="form-row-grid" style={{ backgroundColor: '#f8fafc', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', marginBottom: '14px' }}>
                  <div className="form-group" style={{ marginBottom: 0 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' }}>
                      <label style={{ margin: 0, fontWeight: 600, color: '#334155' }}>Vị trí lưu kho có sẵn</label>
                      <button
                        type="button"
                        onClick={() => {
                          setNewLocationCode('');
                          setNewLocationName('');
                          setNewLocationDesc('');
                          setNewLocationQr('');
                          setIsAddLocationModalOpen(true);
                        }}
                        style={{ background: 'none', border: 'none', color: '#2563eb', fontSize: '0.8rem', cursor: 'pointer', padding: 0, fontWeight: 600 }}
                      >
                        + Thêm vị trí mới
                      </button>
                    </div>
                    <select
                      value={partInitialLocationCode}
                      onChange={(e) => setPartInitialLocationCode(e.target.value)}
                      className="w-status-select"
                      style={{ width: '100%' }}
                    >
                      <option value="">-- Chọn vị trí kho có sẵn --</option>
                      {locations.map((loc) => (
                        <option key={loc.id} value={loc.code}>
                          {loc.code} {loc.name ? `(${loc.name})` : ''}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group" style={{ marginBottom: 0 }}>
                    <label style={{ fontWeight: 600, color: '#334155' }}>Số lượng nhập kho ban đầu</label>
                    <input
                      type="number"
                      min="0"
                      step="0.0001"
                      value={partInitialQuantity}
                      onChange={(e) => setPartInitialQuantity(e.target.value)}
                      placeholder="0 (Nhập số lượng nếu có)"
                    />
                  </div>
                </div>
              )}

              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsPartAddEditModalOpen(false)}>
                  Hủy
                </button>
                <button type="submit" className="btn-submit">
                  {editingPart ? 'Lưu thay đổi' : 'Thêm linh kiện'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ADJUST STOCK DIALOG */}
      {isAdjustStockModalOpen && (
        <div className="w-modal-overlay">
          <div className="w-modal-card small">
            <div className="modal-header">
              <h3>Điều chỉnh số lượng tồn kho</h3>
              <button className="close-modal-btn" onClick={() => setIsAdjustStockModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleAdjustStock} className="modal-form">
              <div className="form-group">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' }}>
                  <label style={{ margin: 0 }}>Vị trí lưu kho có sẵn *</label>
                  <button
                    type="button"
                    onClick={() => {
                      setNewLocationCode('');
                      setNewLocationName('');
                      setNewLocationDesc('');
                      setNewLocationQr('');
                      setIsAddLocationModalOpen(true);
                    }}
                    style={{ background: 'none', border: 'none', color: '#2563eb', fontSize: '0.8rem', cursor: 'pointer', padding: 0, fontWeight: 600 }}
                  >
                    + Thêm vị trí mới
                  </button>
                </div>
                <select
                  required
                  value={adjustLocationCode}
                  onChange={(e) => setAdjustLocationCode(e.target.value)}
                  className="w-status-select"
                  style={{ width: '100%' }}
                >
                  <option value="">-- Chọn vị trí kho có sẵn --</option>
                  {locations.map((loc) => (
                    <option key={loc.id} value={loc.code}>
                      {loc.code} {loc.name ? `(${loc.name})` : ''}
                    </option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label>Số lượng tồn kho mới *</label>
                <input
                  type="number"
                  required
                  min="0"
                  step="0.0001"
                  value={adjustAmount}
                  onChange={(e) => setAdjustAmount(e.target.value)}
                  placeholder="0"
                />
              </div>

              <div className="form-group">
                <label>Ghi chú lý do điều chỉnh</label>
                <textarea
                  value={adjustNote}
                  onChange={(e) => setAdjustNote(e.target.value)}
                  placeholder="VD: Nhập thêm hàng, Kiểm kho định kỳ..."
                  rows={3}
                />
              </div>

              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsAdjustStockModalOpen(false)}>
                  Hủy
                </button>
                <button type="submit" className="btn-submit">
                  Xác nhận điều chỉnh
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ADD LOCATION MODAL */}
      {isAddLocationModalOpen && (
        <div className="w-modal-overlay">
          <div className="w-modal-card small">
            <div className="modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <QrCode size={20} className="text-primary" />
                <h3 style={{ margin: 0 }}>Thêm Vị Trí Kho / Kệ Mới</h3>
              </div>
              <button className="close-modal-btn" onClick={() => setIsAddLocationModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleSaveLocation} className="modal-form">
              <div className="form-group">
                <label>Mã vị trí kho (Kệ / Ngăn) *</label>
                <input
                  type="text"
                  required
                  value={newLocationCode}
                  onChange={(e) => {
                    setNewLocationCode(e.target.value);
                    if (!newLocationQr || newLocationQr === newLocationCode) {
                      setNewLocationQr(e.target.value);
                    }
                  }}
                  placeholder="VD: LOC-A1, KE-01, KHAY-B2..."
                />
              </div>

              <div className="form-group">
                <label>Tên mô tả vị trí *</label>
                <input
                  type="text"
                  required
                  value={newLocationName}
                  onChange={(e) => setNewLocationName(e.target.value)}
                  placeholder="VD: Kệ A - Tầng 1 - Hộp 02..."
                />
              </div>

              <div className="form-group">
                <label>Mã QR gán cho vị trí (mặc định = Mã vị trí)</label>
                <input
                  type="text"
                  value={newLocationQr}
                  onChange={(e) => setNewLocationQr(e.target.value)}
                  placeholder="Để trống sẽ tự động lấy Mã vị trí làm mã QR"
                />
              </div>

              <div className="form-group">
                <label>Ghi chú chi tiết vị trí</label>
                <textarea
                  value={newLocationDesc}
                  onChange={(e) => setNewLocationDesc(e.target.value)}
                  placeholder="VD: Chuyên chứa IC nguồn và tụ điện cao áp..."
                  rows={2}
                />
              </div>

              {newLocationCode.trim() && (
                <div style={{ padding: '12px', background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: '8px', display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '14px' }}>
                  <img
                    src={`https://api.qrserver.com/v1/create-qr-code/?size=80x80&data=${encodeURIComponent(newLocationQr.trim() || newLocationCode.trim())}`}
                    alt="QR Preview"
                    style={{ width: '60px', height: '60px', borderRadius: '4px', border: '1px solid #cbd5e1' }}
                  />
                  <div>
                    <div style={{ fontSize: '0.8rem', color: '#64748b' }}>Mã QR sẽ tạo cho vị trí này:</div>
                    <div style={{ fontWeight: 700, fontFamily: 'monospace', color: '#0f172a', fontSize: '0.95rem' }}>
                      {newLocationQr.trim() || newLocationCode.trim()}
                    </div>
                  </div>
                </div>
              )}

              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsAddLocationModalOpen(false)}>
                  Hủy
                </button>
                <button type="submit" className="btn-submit">
                  Tạo Vị Trí & Cấp QR
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* QR Print Config & Live Preview Modal for Warehouse Locations */}
      <QrPrintConfigModal
        isOpen={isQrConfigModalOpen}
        locations={locationsForQrPrint}
        onClose={() => setIsQrConfigModalOpen(false)}
        onConfirmPrint={(config: QrPrintConfig) => {
          setIsQrConfigModalOpen(false);
          const filename =
            locationsForQrPrint.length === 1
              ? `Tem_QR_ViTri_${locationsForQrPrint[0].code}`
              : 'Danh_sach_tem_QR_vi_tri_kho';
          exportLocationQrPdfList(locationsForQrPrint, filename, config);
        }}
      />

      {/* Location QR Code Scan Modal */}
      <LocationQrScanModal
        isOpen={isLocationQrScanModalOpen}
        initialCode={locationScanInitialCode}
        availableLocations={locations}
        onClose={() => setIsLocationQrScanModalOpen(false)}
        onSelectPartForCheckout={(partItem) => {
          const matchedPart = parts.find((p) => p.id === partItem.partId);
          if (matchedPart) {
            setSelectedPart(matchedPart);
            const matchedLot = matchedPart.lots?.find((l) => l.id === partItem.partLotId);
            setCheckoutInitialLot(matchedLot || null);
          }
          setIsPartCheckoutModalOpen(true);
        }}
        onPrintLocationQr={(locData) => {
          const cleanCode = (locData.code || locData.qrCode || '').replace(/_QR$/i, '').trim();
          setLocationsForQrPrint([
            {
              id: locData.locationId || locData.code,
              code: cleanCode,
              name: locData.name,
              qrCode: cleanCode,
              description: locData.description,
              totalPartTypes: locData.totalPartTypes,
              totalQuantity: locData.totalQuantity,
            },
          ]);
          setIsQrConfigModalOpen(true);
        }}
        onRefreshLocations={fetchLocations}
        showToast={showToast}
      />

      {/* Location Management (Quản Lý Vị Trí Lưu Kho) Modal */}
      <LocationManagementModal
        isOpen={isLocationManagementModalOpen}
        onClose={() => setIsLocationManagementModalOpen(false)}
        locations={locations}
        onRefreshLocations={fetchLocations}
        onPrintLocationQr={(loc) => {
          if (loc) {
            handleOpenLocationQrPrint([
              {
                id: loc.id,
                code: loc.code,
                name: loc.name,
                qrCode: loc.qrCode || loc.code,
                description: loc.description,
                totalPartTypes: loc.totalPartTypes,
                totalQuantity: loc.totalQuantity,
              },
            ]);
          }
        }}
        onPrintAllLocationsQr={() => handleOpenLocationQrPrint()}
        showToast={showToast}
      />

      {/* Part Checkout (Lấy Linh Kiện) Modal */}
      <PartCheckoutModal
        isOpen={isPartCheckoutModalOpen}
        onClose={() => {
          setIsPartCheckoutModalOpen(false);
          setCheckoutInitialLot(null);
        }}
        part={selectedPart}
        initialLot={checkoutInitialLot}
        onSuccess={() => {
          fetchParts();
        }}
        showToast={showToast}
      />

      {/* Part Return (Trả Linh Kiện) Modal */}
      <PartReturnModal
        isOpen={isPartReturnModalOpen}
        onClose={() => setIsPartReturnModalOpen(false)}
        checkoutItem={checkoutHistoryItemToReturn}
        onSuccess={() => {
          fetchParts();
        }}
        showToast={showToast}
      />

      {/* Part Bulk Import (Nhập linh kiện Excel/CSV) Modal */}
      <PartBulkImportModal
        isOpen={isPartBulkImportModalOpen}
        onClose={() => setIsPartBulkImportModalOpen(false)}
        existingParts={parts}
        onSuccess={() => {
          fetchParts();
        }}
        showToast={showToast}
      />
    </div>
  );
};

