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
} from 'lucide-react';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
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

interface RepairOrder {
  id: string;
  orderCode: string;
  deviceName: string;
  customerName: string;
  status: string;
}

interface WarehouseTabProps {
  showToast: (msg: string) => void;
}

export const WarehouseTab: React.FC<WarehouseTabProps> = ({ showToast }) => {
  const [boards, setBoards] = useState<Board[]>([]);
  const [repairOrders, setRepairOrders] = useState<RepairOrder[]>([]);
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

  // Checkout form states
  const [checkoutOrderId, setCheckoutOrderId] = useState<string>('');
  const [checkoutNote, setCheckoutNote] = useState<string>('');

  // Return form states
  const [returnNote, setReturnNote] = useState<string>('');

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

  // Fetch Active Repair Orders (for checkout link dropdown)
  const fetchRepairOrders = useCallback(async () => {
    try {
      const response = await fetch('/api/v1/repair-orders?size=200', {
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data?.content) {
          setRepairOrders(result.data.content);
        } else if (Array.isArray(result?.data)) {
          setRepairOrders(result.data);
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
          updatedSelected.name !== selectedBoard.name
        ) {
          setSelectedBoard(updatedSelected);
        }
      }
    }
  }, [boards, selectedBoard]);

  useEffect(() => {
    fetchBoards();
    fetchRepairOrders();
  }, [fetchBoards, fetchRepairOrders]);

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
    } else {
      setBoardName('');
      setBoardModel('');
      setBoardLocation('');
      setBoardSerial('');
      setBoardPartId('');
      setBoardLocationId('');
      setBoardDesc('');
      setBoardStatus('AVAILABLE');
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

  // Open Checkout Modal
  const openCheckoutModal = () => {
    setCheckoutOrderId('');
    setCheckoutNote('');
    setIsCheckoutModalOpen(true);
  };

  // Checkout API
  const handleCheckoutBoard = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedBoard) return;

    try {
      const response = await fetch(`/api/v1/boards/${selectedBoard.id}/checkout`, {
        method: 'POST',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({
          repairOrderId: checkoutOrderId || undefined,
          note: checkoutNote.trim() || undefined,
        }),
      });

      if (response.ok) {
        showToast('Cho mượn (checkout) bo mạch thành công!');
        setIsCheckoutModalOpen(false);
        fetchBoards();
        fetchBoardHistory(selectedBoard.id);
      } else {
        showToast('Checkout thất bại');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi checkout');
    }
  };

  // Open Return Modal
  const openReturnModal = () => {
    setReturnNote('');
    setIsReturnModalOpen(true);
  };

  // Return API
  const handleReturnBoard = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedBoard) return;

    try {
      const response = await fetch(`/api/v1/boards/${selectedBoard.id}/return`, {
        method: 'PATCH',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({
          notes: returnNote.trim() || undefined,
        }),
      });

      if (response.ok) {
        showToast('Trả bo mạch về kho thành công!');
        setIsReturnModalOpen(false);
        fetchBoards();
        fetchBoardHistory(selectedBoard.id);
      } else {
        showToast('Trả bo mạch thất bại');
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
                          <Layers size={12} />
                          <span>Model: {board.model || 'Chưa rõ'}</span>
                        </div>
                        <div className="spec-row">
                          <MapPin size={12} />
                          <span>Vị trí: {board.location || 'Chưa đặt'}</span>
                        </div>
                        {board.serialNumber && (
                          <div className="spec-row">
                            <Tag size={12} />
                            <span>SN: {board.serialNumber}</span>
                          </div>
                        )}
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
        </div>

        {/* Right Column: Spec Detail Pane */}
        <div className="warehouse-detail-panel">
          {selectedBoard ? (
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
                    <span className="label">Danh mục / Model</span>
                    <span className="value">{selectedBoard.model || 'Chưa xác định'}</span>
                  </div>
                  <div className="spec-detail-item">
                    <span className="label">Vị trí lưu trữ</span>
                    <span className="value">{selectedBoard.location || 'Chưa cài đặt'}</span>
                  </div>
                  <div className="spec-detail-item">
                    <span className="label">Số Serial (SN)</span>
                    <span className="value">{selectedBoard.serialNumber || 'Không có'}</span>
                  </div>
                  {selectedBoard.partIpn && (
                    <div className="spec-detail-item">
                      <span className="label">Part IPN / ID</span>
                      <span className="value">{selectedBoard.partIpn}</span>
                    </div>
                  )}
                  {selectedBoard.currentLocationCode && (
                    <div className="spec-detail-item">
                      <span className="label">Kho chứa ID/Code</span>
                      <span className="value">{selectedBoard.currentLocationCode}</span>
                    </div>
                  )}
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
                <h4 className="section-title text-left width-full">QR Code định danh</h4>
                <div className="qrcode-container-card">
                  <img src={getQRCodeUrl(selectedBoard.qrCode)} alt="QR Code" className="qrcode-img" />
                  <div className="qrcode-meta">
                    <span className="qr-value">{selectedBoard.qrCode}</span>
                    <span className="qr-desc">Dùng ứng dụng di động quét mã QR này để nhanh chóng kiểm tra thông tin hoặc thay đổi vị trí.</span>
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
                  <label>Model / Danh mục</label>
                  <input
                    type="text"
                    value={boardModel}
                    onChange={(e) => setBoardModel(e.target.value)}
                    placeholder="VFD-M Control Board"
                  />
                </div>
                <div className="form-group">
                  <label>Vị trí lưu kho</label>
                  <input
                    type="text"
                    value={boardLocation}
                    onChange={(e) => setBoardLocation(e.target.value)}
                    placeholder="Kệ A - Tầng 2"
                  />
                </div>
              </div>

              <div className="form-row-grid">
                <div className="form-group">
                  <label>Số Serial (SN)</label>
                  <input
                    type="text"
                    value={boardSerial}
                    onChange={(e) => setBoardSerial(e.target.value)}
                    placeholder="SN-BOARD-999"
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
              </div>

              <div className="form-row-grid">
                <div className="form-group">
                  <label>Part ID / IPN (Nếu liên kết linh kiện)</label>
                  <input
                    type="text"
                    value={boardPartId}
                    onChange={(e) => setBoardPartId(e.target.value)}
                    placeholder="IPN-001 hoặc ID"
                  />
                </div>
                <div className="form-group">
                  <label>Location ID / Code kho chứa</label>
                  <input
                    type="text"
                    value={boardLocationId}
                    onChange={(e) => setBoardLocationId(e.target.value)}
                    placeholder="DEFAULT hoặc ID"
                  />
                </div>
              </div>

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
              <div className="form-group">
                <label>Liên kết Đơn sửa chữa</label>
                <select
                  value={checkoutOrderId}
                  onChange={(e) => setCheckoutOrderId(e.target.value)}
                >
                  <option value="">Không liên kết đơn sửa chữa</option>
                  {repairOrders
                    .filter((o) => o.status !== 'CANCELLED' && o.status !== 'DELIVERED')
                    .map((order) => (
                      <option key={order.id} value={order.id}>
                        {order.orderCode} - {order.deviceName} ({order.customerName})
                      </option>
                    ))}
                </select>
              </div>

              <div className="form-group">
                <label>Ghi chú checkout *</label>
                <textarea
                  required
                  value={checkoutNote}
                  onChange={(e) => setCheckoutNote(e.target.value)}
                  placeholder="Nhập mục đích mượn board hoặc kỹ thuật viên thực hiện..."
                  rows={3}
                />
              </div>

              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsCheckoutModalOpen(false)}>
                  Hủy
                </button>
                <button type="submit" className="btn-submit">
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
              <div className="form-group">
                <label>Ghi chú trả board về kho</label>
                <textarea
                  value={returnNote}
                  onChange={(e) => setReturnNote(e.target.value)}
                  placeholder="Ghi chú thêm về trạng thái board sau khi sử dụng (ví dụ: đã sửa xong, dùng tốt)..."
                  rows={3}
                />
              </div>

              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsReturnModalOpen(false)}>
                  Hủy
                </button>
                <button type="submit" className="btn-submit">
                  Xác nhận trả
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
