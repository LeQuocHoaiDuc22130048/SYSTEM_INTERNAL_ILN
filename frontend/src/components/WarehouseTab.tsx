import React, { useState, useEffect, useCallback } from 'react';
import {
  Search,
  Plus,
  Trash2,
  Edit2,
  X,
  Cpu,
  Boxes,
  History,
  CheckCircle,
  Layers,
  MapPin,
  Tag,
  Printer,
  FileText,
} from 'lucide-react';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import { exportBoardQrPdf, exportBoardQrPdfList } from '../utils/pdf';
import './WarehouseTab.css';

interface Board {
  id: string;
  name: string;
  qrCode: string;
  model: string;
  location: string;
  status: string;
  checkedOutBy?: string;
  checkedOutAt?: string;
  currentRepairOrder?: string;
  description?: string;
  serialNumber?: string;
  partId?: string;
  partIpn?: string;
  currentLocationId?: string;
  currentLocationCode?: string;
  quantity?: number;
  activeCheckoutInfo?: {
    checkoutId?: string;
    takenBy?: string;
    takenByName?: string;
    takenByEmployeeCode?: string;
    takenAt?: string;
    repairOrderId?: string;
    orderCode?: string;
    quantity?: number;
    repairBrand?: string;
  };
}

interface BoardHistoryItem {
  id: string;
  boardId: string;
  boardName: string;
  qrCode: string;
  takenBy: string;
  takenByName: string;
  takenAt?: string;
  returnedAt?: string;
  repairOrderId?: string;
  notes?: string;
}

interface PartLot {
  id: string;
  storeLocationId?: string;
  storeLocationCode: string;
  storeLocationName: string;
  amount: number;
  lotCode: string;
}

interface Part {
  id: string;
  ipn: string;
  name: string;
  description?: string;
  minAmount: number;
  manufacturingStatus: string;
  categoryId?: string;
  categoryName?: string;
  totalQuantity: number;
  lots: PartLot[];
  createdAt?: string;
}

interface WarehouseTabProps {
  showToast: (msg: string) => void;
}

export const WarehouseTab: React.FC<WarehouseTabProps> = ({ showToast }) => {
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

  // Checkout form states
  const [checkoutNote, setCheckoutNote] = useState<string>('');
  const [checkoutQuantity, setCheckoutQuantity] = useState<number>(1);

  // Warehouse Mode: BOARDS or PARTS (forced to BOARDS)
  const warehouseMode = 'BOARDS';

  // Parts state
  const [parts, setParts] = useState<Part[]>([]);
  const [selectedPart, setSelectedPart] = useState<Part | null>(null);
  const [loadingParts, setLoadingParts] = useState<boolean>(false);
  const [partSearchTerm, setPartSearchTerm] = useState<string>('');

  // Part Modals
  const [isPartAddEditModalOpen, setIsPartAddEditModalOpen] = useState<boolean>(false);
  const [isAdjustStockModalOpen, setIsAdjustStockModalOpen] = useState<boolean>(false);

  // Part Form states
  const [editingPart, setEditingPart] = useState<Part | null>(null);
  const [partIpn, setPartIpn] = useState<string>('');
  const [partName, setPartName] = useState<string>('');
  const [partDescription, setPartDescription] = useState<string>('');
  const [partMinAmount, setPartMinAmount] = useState<string>('0');
  const [partCategoryName, setPartCategoryName] = useState<string>('');
  const [partCategoryId, setPartCategoryId] = useState<string>('');

  // Stock Adjustment Form states
  const [adjustLocationCode, setAdjustLocationCode] = useState<string>('');
  const [adjustAmount, setAdjustAmount] = useState<string>('0');
  const [adjustNote, setAdjustNote] = useState<string>('');

  // Autocomplete lists
  const [categories, setCategories] = useState<Array<{ id: string; name: string }>>([]);
  const [locations, setLocations] = useState<Array<{ id: string; code: string; name: string }>>([]);

  // Return form states
  const [returnNote, setReturnNote] = useState<string>('');
  const [returnType, setReturnType] = useState<'FULL' | 'PARTIAL'>('FULL');
  const [returnQuantity, setReturnQuantity] = useState<number>(1);
  const [returnReason, setReturnReason] = useState<string>('');

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
            model: b.category?.toString() || b.model?.toString() || '',
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
    const term = searchTerm.toLowerCase();
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
    } else {
      setPartIpn('');
      setPartName('');
      setPartDescription('');
      setPartMinAmount('0');
      setPartCategoryName('');
      setPartCategoryId('');
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
        showToast(editingPart ? 'Cập nhật linh kiện thành công!' : 'Thêm linh kiện thành công!');
        setIsPartAddEditModalOpen(false);
        fetchParts();
        fetchCategories();
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
    const term = partSearchTerm.toLowerCase();
    return (
      part.name.toLowerCase().includes(term) ||
      part.ipn.toLowerCase().includes(term) ||
      (part.categoryName && part.categoryName.toLowerCase().includes(term)) ||
      (part.description && part.description.toLowerCase().includes(term))
    );
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

  // QR Code generator URL helper
  const getQRCodeUrl = (code: string) => {
    return `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(code)}`;
  };

  return (
    <div className="warehouse-container">
      <div className="warehouse-layout">
        {/* Left Column: Stats, Filter & Grid */}
        <div className="warehouse-main-panel">
          {warehouseMode === 'BOARDS' ? (
            <>
              {/* Stats Bar */}
              <div className="warehouse-stats-row">
                <div className="w-stat-card">
                  <Boxes size={24} className="stat-icon total" />
                  <div className="stat-text">
                    <span className="stat-val">{boards.length}</span>
                    <span className="stat-lbl">Tổng bo mạch</span>
                  </div>
                </div>
                <div className="w-stat-card">
                  <CheckCircle size={24} className="stat-icon available" />
                  <div className="stat-text">
                    <span className="stat-val text-success">
                      {boards.filter((b) => b.status === 'AVAILABLE').length}
                    </span>
                    <span className="stat-lbl">Sẵn có</span>
                  </div>
                </div>
                <div className="w-stat-card">
                  <Cpu size={24} className="stat-icon checkedout" />
                  <div className="stat-text">
                    <span className="stat-val text-warning">
                      {boards.filter((b) => b.status === 'CHECKED_OUT' || b.status === 'IN_USE').length}
                    </span>
                    <span className="stat-lbl">Đang sử dụng</span>
                  </div>
                </div>
                <div className="w-stat-card">
                  <History size={24} className="stat-icon maintenance" />
                  <div className="stat-text">
                    <span className="stat-val text-danger">
                      {boards.filter((b) => b.status === 'MAINTENANCE' || b.status === 'IN_REPAIR').length}
                    </span>
                    <span className="stat-lbl">Bảo trì / Sửa</span>
                  </div>
                </div>
              </div>

              {/* Search & Actions Bar */}
              <div className="warehouse-control-bar">
                <div className="search-input-wrapper flex-1">
                  <Search size={18} className="search-icon" />
                  <input
                    type="text"
                    placeholder="Tìm theo tên, serial, model, vị trí kho..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="w-search-input"
                  />
                </div>

                <div className="filters-actions-wrapper">
                  <select
                    value={statusFilter}
                    onChange={(e) => setStatusFilter(e.target.value)}
                    className="w-status-select"
                  >
                    <option value="ALL">Mọi trạng thái</option>
                    <option value="AVAILABLE">Sẵn sàng</option>
                    <option value="CHECKED_OUT">Đang dùng</option>
                    <option value="IN_REPAIR">Đang sửa</option>
                    <option value="DAMAGED">Hỏng</option>
                    <option value="LOST">Mất</option>
                    <option value="ARCHIVED">Lưu trữ</option>
                    <option value="MAINTENANCE">Bảo trì</option>
                  </select>

                  <button
                    className="btn-export-pdf-all"
                    onClick={() => exportBoardQrPdfList(filteredBoards)}
                    title="Xuất PDF mã QR cho tất cả bo mạch đang hiển thị"
                  >
                    <FileText size={16} />
                    <span>Xuất PDF Mã QR</span>
                  </button>

                  <button className="btn-add-board" onClick={() => openAddEditModal(null)}>
                    <Plus size={16} />
                    <span>Thêm bo mạch</span>
                  </button>
                </div>
              </div>

              {/* Boards Grid Display */}
              <div className="boards-grid-wrapper">
                {loading ? (
                  <div className="list-status-msg">Đang tải danh sách bo mạch...</div>
                ) : filteredBoards.length === 0 ? (
                  <div className="list-status-msg">Không tìm thấy bo mạch nào trong kho.</div>
                ) : (
                  <div className="boards-grid-list">
                    {filteredBoards.map((board) => {
                      const isSelected = selectedBoard?.id === board.id;
                      const statusLabel = getStatusLabel(board.status);
                      const colorClass = getStatusColorClass(board.status);

                      return (
                        <div
                          key={board.id}
                          className={`board-grid-card ${isSelected ? 'selected' : ''}`}
                          onClick={() => handleSelectBoard(board)}
                        >
                          <div className="board-card-header">
                            <h4 className="board-card-title" title={board.name}>
                              {board.name}
                            </h4>
                            <span className={`board-status-dot-badge ${colorClass}`}>
                              {statusLabel}
                            </span>
                          </div>

                          <div className="board-card-specs">
                            <div className="spec-row">
                              <MapPin size={12} />
                              <span>Vị trí: {board.location || 'Chưa đặt'}</span>
                            </div>
                          </div>

                          {board.checkedOutBy && (
                            <div className="board-card-borrow-info">
                              <span>Đang mượn bởi: <strong>{board.checkedOutBy}</strong></span>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </>
          ) : (
            <>
              {/* Stats Bar for Parts */}
              <div className="warehouse-stats-row">
                <div className="w-stat-card">
                  <Boxes size={24} className="stat-icon total" />
                  <div className="stat-text">
                    <span className="stat-val">{parts.length}</span>
                    <span className="stat-lbl">Loại linh kiện</span>
                  </div>
                </div>
                <div className="w-stat-card">
                  <Layers size={24} className="stat-icon available" />
                  <div className="stat-text">
                    <span className="stat-val text-success">
                      {parts.reduce((sum, p) => sum + p.totalQuantity, 0)}
                    </span>
                    <span className="stat-lbl">Tổng tồn kho</span>
                  </div>
                </div>
                <div className="w-stat-card">
                  <CheckCircle size={24} className="stat-icon checkedout" />
                  <div className="stat-text">
                    <span className="stat-val text-warning">
                      {parts.filter((p) => p.totalQuantity < p.minAmount).length}
                    </span>
                    <span className="stat-lbl">Dưới định mức</span>
                  </div>
                </div>
                <div className="w-stat-card">
                  <History size={24} className="stat-icon maintenance" />
                  <div className="stat-text">
                    <span className="stat-val text-danger">
                      {parts.filter((p) => p.totalQuantity === 0).length}
                    </span>
                    <span className="stat-lbl">Hết hàng</span>
                  </div>
                </div>
              </div>

              {/* Search & Actions Bar for Parts */}
              <div className="warehouse-control-bar">
                <div className="search-input-wrapper flex-1">
                  <Search size={18} className="search-icon" />
                  <input
                    type="text"
                    placeholder="Tìm theo tên, IPN, danh mục linh kiện..."
                    value={partSearchTerm}
                    onChange={(e) => setPartSearchTerm(e.target.value)}
                    className="w-search-input"
                  />
                </div>

                <div className="filters-actions-wrapper">
                  <button className="btn-add-board" onClick={() => openAddEditPartModal(null)}>
                    <Plus size={16} />
                    <span>Thêm linh kiện</span>
                  </button>
                </div>
              </div>

              {/* Parts Grid Display */}
              <div className="boards-grid-wrapper">
                {loadingParts ? (
                  <div className="list-status-msg">Đang tải danh sách linh kiện...</div>
                ) : filteredParts.length === 0 ? (
                  <div className="list-status-msg">Không tìm thấy linh kiện nào trong kho.</div>
                ) : (
                  <div className="boards-grid-list">
                    {filteredParts.map((part) => {
                      const isSelected = selectedPart?.id === part.id;
                      const isLowStock = part.totalQuantity < part.minAmount;

                      return (
                        <div
                          key={part.id}
                          className={`board-grid-card ${isSelected ? 'selected' : ''}`}
                          onClick={() => setSelectedPart(part)}
                        >
                          <div className="board-card-header">
                            <h4 className="board-card-title" title={part.name}>
                              {part.name}
                            </h4>
                            <span className={`board-status-dot-badge ${part.totalQuantity === 0 ? 'board-damaged' : isLowStock ? 'board-checkedout' : 'board-available'}`}>
                              {part.totalQuantity === 0 ? 'Hết hàng' : isLowStock ? 'Sắp hết' : 'Đủ hàng'}
                            </span>
                          </div>

                          <div className="board-card-specs">
                            <div className="spec-row">
                              <Tag size={12} />
                              <span>IPN: {part.ipn}</span>
                            </div>
                            <div className="spec-row">
                              <Layers size={12} />
                              <span>Danh mục: {part.categoryName || 'Chưa rõ'}</span>
                            </div>
                            <div className="spec-row">
                              <MapPin size={12} />
                              <span>Lưu tại: {part.lots.length > 0 ? part.lots.map(l => `${l.storeLocationCode} (${l.amount})`).join(', ') : 'Chưa nhập kho'}</span>
                            </div>
                          </div>

                          <div className="board-card-borrow-info" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <span>Tồn kho: <strong>{part.totalQuantity}</strong></span>
                            {part.minAmount > 0 && (
                              <span style={{ fontSize: '0.7rem', color: 'var(--color-text-light)' }}>Min: {part.minAmount}</span>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </>
          )}
        </div>

        {/* Right Column: Spec Detail Pane */}
        <div className="warehouse-detail-panel">
          {warehouseMode === 'BOARDS' ? (
            selectedBoard ? (
              <div className="detail-scroller">
                <div className="detail-header-row">
                  <div className="title-wrapper">
                    <div className="board-badge-icon">
                      <Cpu size={24} />
                    </div>
                    <div>
                      <h3 className="detail-board-name">{selectedBoard.name}</h3>
                      <span className={`status-badge ${getStatusColorClass(selectedBoard.status)}`}>
                        {getStatusLabel(selectedBoard.status)}
                      </span>
                    </div>
                  </div>

                  <div className="actions-wrapper">
                    <button className="btn-action-outline" onClick={() => openAddEditModal(selectedBoard)}>
                      <Edit2 size={14} />
                      Sửa
                    </button>
                    <button className="btn-action-outline danger" onClick={handleDeleteBoard}>
                      <Trash2 size={14} />
                      Xóa
                    </button>
                  </div>
                </div>

                {/* Status Action Buttons */}
                <div className="detail-main-actions-bar">
                  {selectedBoard.status === 'AVAILABLE' ? (
                    <button className="btn-checkout-board" onClick={openCheckoutModal}>
                      Mượn board / Checkout
                    </button>
                  ) : (selectedBoard.status === 'CHECKED_OUT' || selectedBoard.status === 'IN_USE') ? (
                    <button className="btn-return-board" onClick={openReturnModal}>
                      Trả board về kho
                    </button>
                  ) : null}
                </div>

                {/* Specs Specifications List */}
                <div className="detail-content-section">
                  <h4 className="section-title">Thông số kỹ thuật</h4>
                  <div className="specs-info-grid">
                    <div className="spec-detail-item">
                      <span className="label">Vị trí lưu trữ</span>
                      <span className="value">{selectedBoard.location || 'Chưa cài đặt'}</span>
                    </div>
                    <div className="spec-detail-item">
                    <span className="label">Tồn kho hiện tại</span>
                    <span className={`value ${(selectedBoard.quantity || 0) > 0 ? 'text-success' : 'text-danger'}`}>
                      {selectedBoard.quantity || 0}
                      {(selectedBoard.quantity || 0) === 0 && ' (Hết hàng)'}
                    </span>
                  </div>
                  </div>
                </div>

                {/* Active Checkout Info */}
                {selectedBoard.checkedOutBy && (
                  <div className="detail-content-section">
                    <h4 className="section-title">Thông tin mượn hiện tại</h4>
                    <div className="active-borrow-card">
                      <div className="borrow-row">
                        <span className="lbl">Người mượn:</span>
                        <span className="val">{selectedBoard.checkedOutBy}</span>
                      </div>
                      {selectedBoard.checkedOutAt && (
                        <div className="borrow-row">
                          <span className="lbl">Ngày mượn:</span>
                          <span className="val">{new Date(selectedBoard.checkedOutAt).toLocaleString('vi-VN')}</span>
                        </div>
                      )}
                      {selectedBoard.currentRepairOrder && (
                        <div className="borrow-row">
                          <span className="lbl">Liên kết đơn sửa:</span>
                          <span className="val link-code">
                            {selectedBoard.currentRepairOrder}
                          </span>
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {/* Description */}
                {selectedBoard.description && (
                  <div className="detail-content-section">
                    <h4 className="section-title">Mô tả bo mạch</h4>
                    <div className="description-card">
                      <p>{selectedBoard.description}</p>
                    </div>
                  </div>
                )}

                {/* QR Code Section */}
                <div className="detail-content-section align-center">
                  <div className="qrcode-section-header">
                    <h4 className="section-title text-left margin-0">QR Code định danh</h4>
                    <button
                      className="btn-export-qr-pdf"
                      onClick={() => exportBoardQrPdf(selectedBoard)}
                      title="Xuất PDF mã QR và mã code của linh kiện bo mạch này"
                    >
                      <Printer size={15} />
                      <span>Xuất PDF QR</span>
                    </button>
                  </div>
                  <div className="qrcode-container-card">
                    <img src={getQRCodeUrl(selectedBoard.qrCode)} alt="QR Code" className="qrcode-img" />
                    <div className="qrcode-meta">
                      <span className="qr-value">{selectedBoard.qrCode}</span>
                      <span className="qr-desc">Dùng ứng dụng di động quét mã QR này để nhanh chóng kiểm tra thông tin hoặc thay đổi vị trí.</span>
                      <button
                        className="btn-export-qr-pdf-outline"
                        onClick={() => exportBoardQrPdf(selectedBoard)}
                      >
                        <Printer size={14} />
                        <span>Xuất tem PDF</span>
                      </button>
                    </div>
                  </div>
                </div>

                {/* History Section */}
                <div className="detail-content-section">
                  <h4 className="section-title">Lịch sử di chuyển & mượn trả</h4>
                  <div className="history-flow-card">
                    {loadingHistory ? (
                      <p className="no-data-text">Đang tải lịch sử di chuyển...</p>
                    ) : boardHistory.length > 0 ? (
                      <div className="history-nodes-list">
                        {boardHistory.map((item, idx) => (
                          <div key={item.id || idx} className="history-node-item">
                            <div className="node-marker" />
                            <div className="node-info">
                              <div className="node-header">
                                <span className="node-author">Mượn bởi: <strong>{item.takenByName}</strong></span>
                                {item.takenAt && (
                                  <span className="node-date">
                                    {new Date(item.takenAt).toLocaleDateString('vi-VN', {
                                      hour: '2-digit',
                                      minute: '2-digit',
                                    })}
                                  </span>
                                )}
                              </div>
                              {item.repairOrderId && (
                                <p className="node-ref-order">Đơn sửa chữa (ID): {item.repairOrderId}</p>
                              )}
                              {item.notes && <p className="node-note">Ghi chú mượn: {item.notes}</p>}

                              {item.returnedAt ? (
                                <div className="node-return-box">
                                  <span className="return-indicator">Đã trả về kho vào: </span>
                                  <span className="node-date">
                                    {new Date(item.returnedAt).toLocaleDateString('vi-VN', {
                                      hour: '2-digit',
                                      minute: '2-digit',
                                    })}
                                  </span>
                                </div>
                              ) : (
                                <div className="node-active-badge">Đang sử dụng</div>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <p className="no-data-text">Chưa có lịch sử dịch chuyển nào được lưu lại.</p>
                    )}
                  </div>
                </div>
              </div>
            ) : (
              <div className="detail-empty-state">
                <Cpu size={48} className="empty-icon" />
                <h3>Chọn một bo mạch</h3>
                <p>Chọn bo mạch từ danh sách kho để xem thông số kỹ thuật, lịch sử chuyển dịch và mượn trả.</p>
              </div>
            )
          ) : (
            selectedPart ? (
              <div className="detail-scroller">
                <div className="detail-header-row">
                  <div className="title-wrapper">
                    <div className="board-badge-icon">
                      <Boxes size={24} />
                    </div>
                    <div>
                      <h3 className="detail-board-name">{selectedPart.name}</h3>
                      <span className={`status-badge ${selectedPart.totalQuantity === 0 ? 'board-damaged' : selectedPart.totalQuantity < selectedPart.minAmount ? 'board-checkedout' : 'board-available'}`}>
                        {selectedPart.totalQuantity === 0 ? 'Hết hàng' : selectedPart.totalQuantity < selectedPart.minAmount ? 'Sắp hết' : 'Đủ hàng'}
                      </span>
                    </div>
                  </div>

                  <div className="actions-wrapper">
                    <button className="btn-action-outline" onClick={() => openAddEditPartModal(selectedPart)}>
                      <Edit2 size={14} />
                      Sửa
                    </button>
                    <button className="btn-action-outline danger" onClick={handleDeletePart}>
                      <Trash2 size={14} />
                      Xóa
                    </button>
                  </div>
                </div>

                {/* Main Action Buttons */}
                <div className="detail-main-actions-bar">
                  <button className="btn-checkout-board" onClick={openAdjustStockModal}>
                    Điều chỉnh số lượng tồn kho
                  </button>
                </div>

                {/* Specs Section */}
                <div className="detail-content-section">
                  <h4 className="section-title">Thông số kỹ thuật</h4>
                  <div className="specs-info-grid">
                    <div className="spec-detail-item">
                      <span className="label">Mã IPN</span>
                      <span className="value" style={{ fontFamily: 'monospace', fontWeight: 700 }}>{selectedPart.ipn}</span>
                    </div>
                    <div className="spec-detail-item">
                      <span className="label">Danh mục linh kiện</span>
                      <span className="value">{selectedPart.categoryName || 'Chưa rõ'}</span>
                    </div>
                    <div className="spec-detail-item">
                      <span className="label">Định mức tối thiểu</span>
                      <span className="value">{selectedPart.minAmount}</span>
                    </div>
                    <div className="spec-detail-item">
                      <span className="label">Tổng lượng tồn kho</span>
                      <span className="value text-success" style={{ fontSize: '1rem', fontWeight: 800 }}>{selectedPart.totalQuantity}</span>
                    </div>
                  </div>
                </div>

                {/* Detailed Stock per Location */}
                <div className="detail-content-section">
                  <h4 className="section-title">Vị trí lưu kho & Số lượng chi tiết</h4>
                  <div className="specs-info-grid">
                    {selectedPart.lots && selectedPart.lots.length > 0 ? (
                      selectedPart.lots.map((lot) => (
                        <div key={lot.id} className="spec-detail-item" style={{ borderBottom: '1px dashed var(--color-border)', paddingBottom: '6px' }}>
                          <div>
                            <span className="value" style={{ display: 'block' }}>{lot.storeLocationName}</span>
                          </div>
                          <span className="value text-success" style={{ fontSize: '0.95rem' }}>{lot.amount}</span>
                        </div>
                      ))
                    ) : (
                      <p className="no-data-text" style={{ margin: 0, padding: '10px 0' }}>Chưa có linh kiện này ở bất kỳ vị trí kho nào. Nhấp "Điều chỉnh số lượng tồn kho" để nhập kho.</p>
                    )}
                  </div>
                </div>

                {/* Description */}
                {selectedPart.description && (
                  <div className="detail-content-section">
                    <h4 className="section-title">Mô tả linh kiện</h4>
                    <div className="description-card">
                      <p>{selectedPart.description}</p>
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <div className="detail-empty-state">
                <Boxes size={48} className="empty-icon" />
                <h3>Chọn một linh kiện</h3>
                <p>Chọn linh kiện từ danh mục để xem định mức, vị trí kho và điều chỉnh số lượng tồn kho.</p>
              </div>
            )
          )}
        </div>
      </div>

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
                  <label>Vị trí lưu kho</label>
                  <input
                    type="text"
                    value={boardLocation}
                    onChange={(e) => setBoardLocation(e.target.value)}
                    placeholder="Kệ A - Tầng 2"
                  />
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
                  rows={3}
                />
              </div>

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
                <label>Vị trí lưu kho *</label>
                <input
                  type="text"
                  required
                  value={adjustLocationCode}
                  onChange={(e) => setAdjustLocationCode(e.target.value)}
                  placeholder="VD: DEFAULT, Kệ A - Hàng 2..."
                  list="location-suggestions"
                />
                <datalist id="location-suggestions">
                  {locations.map((loc) => (
                    <option key={loc.id} value={loc.code} />
                  ))}
                </datalist>
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
    </div>
  );
};
