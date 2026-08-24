import React from 'react';
import { Search, Plus, Boxes, CheckCircle, Cpu, History, MapPin, Tag } from 'lucide-react';
import type { Board } from '../../types/warehouse';

interface BoardListPanelProps {
  boards: Board[];
  loading: boolean;
  searchTerm: string;
  setSearchTerm: (val: string) => void;
  statusFilter: string;
  setStatusFilter: (val: string) => void;
  filteredBoards: Board[];
  selectedBoard: Board | null;
  handleSelectBoard: (board: Board) => void;
  openAddEditModal: (board: Board | null) => void;
  openAddLocationModal?: () => void;
  getStatusLabel: (status: string) => string;
  getStatusColorClass: (status: string) => string;
}

export const BoardListPanel: React.FC<BoardListPanelProps> = ({
  boards,
  loading,
  searchTerm,
  setSearchTerm,
  statusFilter,
  setStatusFilter,
  filteredBoards,
  selectedBoard,
  handleSelectBoard,
  openAddEditModal,
  openAddLocationModal,
  getStatusLabel,
  getStatusColorClass,
}) => {
  return (
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
        <div className="warehouse-control-top-row">
          <div className="search-input-wrapper">
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

            {openAddLocationModal && (
              <button
                type="button"
                className="btn-action-outline"
                onClick={openAddLocationModal}
                style={{ display: 'flex', alignItems: 'center', gap: '6px', whiteSpace: 'nowrap' }}
                title="Tạo vị trí / kệ kho mới với mã QR"
              >
                <MapPin size={16} className="text-primary" />
                <span>Thêm vị trí (QR)</span>
              </button>
            )}

            <button className="btn-add-board" onClick={() => openAddEditModal(null)}>
              <Plus size={16} />
              <span>Thêm bo mạch</span>
            </button>
          </div>
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
                    {board.model && (
                      <div className="spec-row">
                        <Tag size={12} />
                        <span>Model: {board.model}</span>
                      </div>
                    )}
                  </div>

                  <div
                    className="board-card-borrow-info"
                    style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}
                  >
                    <span>
                      Số lượng: <strong>{board.quantity ?? 1}</strong>
                    </span>
                    {(board.minQuantity ?? 0) > 0 && (
                      <span
                        style={{
                          fontSize: '0.75rem',
                          color: (board.quantity ?? 1) <= (board.minQuantity ?? 0) ? '#dc2626' : 'var(--color-text-light)',
                          fontWeight: (board.quantity ?? 1) <= (board.minQuantity ?? 0) ? 600 : 400,
                        }}
                      >
                        Min: {board.minQuantity}
                      </span>
                    )}
                  </div>

                  {board.checkedOutBy && (
                    <div className="board-card-borrow-info" style={{ marginTop: '4px' }}>
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
  );
};
