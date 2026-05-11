package com.suachuabientan.system_internal.modules.warehouse.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.common.util.QrCodeGenerator;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CheckoutRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CreateBoardItemRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.UpdateBoardItemRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.BoardItemResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.CheckoutResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.QrScanResponse;
import com.suachuabientan.system_internal.modules.warehouse.entity.BoardCheckout;
import com.suachuabientan.system_internal.modules.warehouse.entity.BoardItem;
import com.suachuabientan.system_internal.modules.warehouse.enums.BoardStatus;
import com.suachuabientan.system_internal.modules.warehouse.repository.BoardCheckoutRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.BoardItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class WarehouseService {
    private final BoardItemRepository boardItemRepository;
    private final BoardCheckoutRepository boardCheckoutRepository;
    private final UserRepository userRepository;
    private final QrCodeGenerator qrCodeGenerator;


    @Transactional
    public BoardItemResponse create(CreateBoardItemRequest request, UUID createdByUserId) {
        // Sinh QR duy nhất
        String qrCode;
        do {
            qrCode = qrCodeGenerator.generateQrCode();
        } while (boardItemRepository.existsByQrCodeAndIsDeletedFalse(qrCode));

        BoardItem item = BoardItem.builder()
                .qrCode(qrCode)
                .name(request.name())
                .category(request.category())
                .description(request.description())
                .location(request.location())
                .status(BoardStatus.AVAILABLE)
                .build();

        BoardItem saved = boardItemRepository.save(item);
        log.info("Tạo bo mạch mới: qrCode={}, name={}, by={}", saved.getQrCode(), saved.getName(), createdByUserId);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public Page<BoardItemResponse> getAll(String keyword, BoardStatus status, Pageable pageable) {
        String statusStr = status != null ? status.name() : null;
        return boardItemRepository.searchBoards(keyword, statusStr, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public BoardItemResponse getById(UUID id) {
        BoardItem item = findBoardById(id);
        return toResponse(item);
    }

    @Transactional
    public BoardItemResponse update(UUID id, UpdateBoardItemRequest request, UUID updatedByUserId) {
        BoardItem item = findBoardById(id);

        if (request.name() != null) item.setName(request.name());
        if (request.category() != null) item.setCategory(request.category());
        if (request.description() != null) item.setDescription(request.description());
        if (request.location() != null) item.setLocation(request.location());

        if (request.status() != null) {
            if (item.isCheckedOut() && request.status() != BoardStatus.CHECKED_OUT) {
                throw new BusinessException("Không thể đổi trạng thái khi bo mạch đang được mượn");
            }
            item.setStatus(request.status());
        }
        log.info("Cập nhật bo mạch: id={}, by={}", id, updatedByUserId);
        return toResponse(boardItemRepository.save(item));
    }

    @Transactional
    public void delete(UUID id, UUID deletedByUserId) {
        BoardItem item = findBoardById(id);
        if (item.isCheckedOut()) throw new BusinessException("Không thể xóa bo mạch đang được mượn");
        item.softDelete(deletedByUserId);
        boardItemRepository.save(item);
        log.info("Xóa bo mạch: id={}, by={}", id, deletedByUserId);
    }

    //QR SCAN

    /**
     * Quét qr trả đầy đủ thông tin để app hiển thị popup
     * không yêu cầu quyền đặc biệt mọi nhân viên có thể quét
     */
    @Transactional(readOnly = true)
    public QrScanResponse scanQr(String qrCode) {
        BoardItem item = boardItemRepository.findByQrCodeAndIsDeletedFalse(qrCode).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bo mạch với QR: " + qrCode));

        QrScanResponse.HolderInfo holderInfo = null;

        if (item.isCheckedOut()) {
            holderInfo = boardCheckoutRepository
                    .findActiveByBoardItemId(item.getId())
                    .map(checkout -> {
                        UserEntity holder = userRepository.findByIdAndIsDeletedFalse(checkout.getTakenBy())
                                .orElse(null);
                        return new QrScanResponse.HolderInfo(
                                checkout.getTakenBy(),
                                holder != null ? holder.getFullName() : "Không xác định",
                                holder != null ? holder.getEmployeeCode() : null,
                                holder != null ? holder.getAvatarUrl() : null,
                                checkout.getTakenAt(),
                                null // orderCode — TODO: thêm sau khi có RepairOrder module
                        );
                    })
                    .orElse(null);
        }
        return new QrScanResponse(
                item.getId(),
                item.getQrCode(),
                item.getName(),
                item.getCategory(),
                item.getLocation(),
                item.getStatus().name(),
                holderInfo
        );
    }

    // Checkout lấy bo mạch

    /**
     * Lấy bo mạch ra khỏi kho để sửa chữa
     */
    @Transactional
    public CheckoutResponse checkout(UUID boardItemId, CheckoutRequest request, UUID userId) {
        BoardItem item = findBoardById(boardItemId);

        if (!item.isAvailable())
            throw new BusinessException(STR."Bo mạch không khả dụng. Trạng thái hiện tại: \{item.getStatus().name()}");
        BoardCheckout checkout = BoardCheckout.builder()
                .boardItemId(boardItemId)
                .takenBy(userId)
                .repairOrderId(request.repairOrderId())
                .takenAt(Instant.now())
                .notes(request.note())
                .build();

        boardCheckoutRepository.save(checkout);

        // Cập nhật status bo mạch
        item.setStatus(BoardStatus.CHECKED_OUT);
        boardItemRepository.save(item);

        log.info("Lấy bo mạch: boardId={}, takenBy={}, repairOrderId={}",
                boardItemId, userId, request.repairOrderId());

        return toCheckoutResponse(checkout, item);
    }

    /**
     * Trả bo mạch về kho sau khi sửa chữa xong
     * Chỉ có người đang giữ bo mạch hoặc admin mới được trả về
     */
    @Transactional
    public CheckoutResponse returnBoard(UUID boardItemId, UUID userId, boolean isAdmin) {
        BoardItem item = findBoardById(boardItemId);
        if (!item.isCheckedOut()) throw new BusinessException("Bo mạch không đang được mượn");

        BoardCheckout activeCheckout = boardCheckoutRepository
                .findActiveByBoardItemId(boardItemId)
                .orElseThrow(() -> new BusinessException("Không tìm thấy thông tin mượn"));

        if (!activeCheckout.getTakenBy().equals(userId) && !isAdmin)
            throw new BusinessException("Bạn không có quyền trả bo mạch này. " +
                    "Chỉ người đang giữ hoặc quản lý mới có thể trả.");

        // Ghi nhận trả
        activeCheckout.setReturnedAt(Instant.now());
        boardCheckoutRepository.save(activeCheckout);

        // Trả về AVAILABLE
        item.setStatus(BoardStatus.AVAILABLE);
        boardItemRepository.save(item);

        log.info("Trả bo mạch: boardId={}, returnedBy={}", boardItemId, userId);
        return toCheckoutResponse(activeCheckout, item);
    }

    // ── History ───────────────────────────────────────────────

    @Transactional(readOnly = true)
    public Page<CheckoutResponse> getHistory(UUID boardItemId, Pageable pageable) {
        findBoardById(boardItemId); // Validate tồn tại
        return boardCheckoutRepository
                .findByBoardItemIdAndIsDeletedFalseOrderByTakenAtDesc(boardItemId, pageable)
                .map(checkout -> {
                    BoardItem item = boardItemRepository.findByIdAndIsDeletedFalse(boardItemId).orElseThrow();
                    return toCheckoutResponse(checkout, item);
                });
    }


    // Helpers
    private CheckoutResponse toCheckoutResponse(BoardCheckout checkout, BoardItem item) {
        UserEntity taker = userRepository.findByIdAndIsDeletedFalse(checkout.getTakenBy()).orElse(null);
        return new CheckoutResponse(
                checkout.getId(),
                item.getId(),
                item.getName(),
                item.getQrCode(),
                checkout.getTakenBy(),
                taker != null ? taker.getFullName() : "Không xác định",
                checkout.getTakenAt(),
                checkout.getReturnedAt(),
                checkout.getRepairOrderId(),
                checkout.getNotes()
        );
    }


    private BoardItem findBoardById(UUID id) {
        return boardItemRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException(STR."Không tìm thấy bo mạch: \{id}"));
    }

    private BoardItemResponse toResponse(BoardItem item) {
        BoardItemResponse.ActiveCheckoutInfo activeCheckout = null;

        if (item.isCheckedOut()) {
            activeCheckout = boardCheckoutRepository
                    .findActiveByBoardItemId(item.getId())
                    .map(checkout -> {
                        UserEntity holder = userRepository
                                .findByIdAndIsDeletedFalse(checkout.getTakenBy())
                                .orElse(null);
                        return new BoardItemResponse.ActiveCheckoutInfo(
                                checkout.getId(),
                                checkout.getTakenBy(),
                                holder != null ? holder.getFullName() : "Không xác định",
                                holder != null ? holder.getEmployeeCode() : null,
                                checkout.getTakenAt(),
                                checkout.getRepairOrderId(),
                                null // orderCode — TODO
                        );
                    })
                    .orElse(null);
        }

        return new BoardItemResponse(
                item.getId(),
                item.getQrCode(),
                item.getName(),
                item.getCategory(),
                item.getDescription(),
                item.getStatus().name(),
                item.getLocation(),
                item.getCreatedAt(),
                activeCheckout
        );
    }
}
