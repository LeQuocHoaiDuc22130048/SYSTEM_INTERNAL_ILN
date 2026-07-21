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
import com.suachuabientan.system_internal.modules.warehouse.entity.Part;
import com.suachuabientan.system_internal.modules.warehouse.entity.StockMovement;
import com.suachuabientan.system_internal.modules.warehouse.entity.StoreLocation;
import com.suachuabientan.system_internal.modules.warehouse.enums.BoardStatus;
import com.suachuabientan.system_internal.modules.warehouse.enums.CheckoutStatus;
import com.suachuabientan.system_internal.modules.warehouse.enums.StockMovementType;
import com.suachuabientan.system_internal.modules.warehouse.repository.BoardCheckoutRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.BoardItemRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.StockMovementRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.StoreLocationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
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
    private final PartRepository partRepository;
    private final StoreLocationRepository storeLocationRepository;
    private final StockMovementRepository stockMovementRepository;
    private final JdbcTemplate jdbcTemplate;

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
                .serialNumber(request.serialNumber())
                .partId(resolvePartId(request.partId()))
                .currentLocationId(resolveLocationId(request.currentLocationId(), request.location()))
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

        if (request.name() != null)
            item.setName(request.name());
        if (request.category() != null)
            item.setCategory(request.category());
        if (request.description() != null)
            item.setDescription(request.description());
        if (request.location() != null)
            item.setLocation(request.location());
        if (request.serialNumber() != null)
            item.setSerialNumber(request.serialNumber());
        if (request.partId() != null)
            item.setPartId(resolvePartId(request.partId()));
        if (request.currentLocationId() != null || request.location() != null) {
            item.setCurrentLocationId(resolveLocationId(request.currentLocationId(), request.location()));
        }

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
        if (item.isCheckedOut())
            throw new BusinessException("Không thể xóa bo mạch đang được mượn");
        item.softDelete(deletedByUserId);
        boardItemRepository.save(item);
        log.info("Xóa bo mạch: id={}, by={}", id, deletedByUserId);
    }

    // QR SCAN

    /**
     * Quét qr trả đầy đủ thông tin để app hiển thị popup
     * không yêu cầu quyền đặc biệt mọi nhân viên có thể quét
     */
    @Transactional(readOnly = true)
    public QrScanResponse scanQr(String qrCode) {
        BoardItem item = boardItemRepository.findByQrCodeAndIsDeletedFalse(qrCode)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bo mạch với QR: " + qrCode));

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
                item.getSerialNumber(),
                item.getPartId(),
                partIpn(item.getPartId()),
                item.getCurrentLocationId(),
                locationCode(item.getCurrentLocationId()),
                item.getStatus().name(),
                holderInfo);
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
                .checkoutStatus(CheckoutStatus.OPEN)
                .build();

        BoardCheckout savedCheckout = boardCheckoutRepository.save(checkout);

        // Cập nhật status bo mạch
        item.setStatus(BoardStatus.CHECKED_OUT);
        boardItemRepository.save(item);
        saveBoardMovement(
                item,
                request.repairOrderId() != null ? StockMovementType.USE_FOR_REPAIR : StockMovementType.EXPORT,
                item.getCurrentLocationId(),
                null,
                "BOARD_CHECKOUT",
                savedCheckout.getId(),
                request.note());

        log.info("Lấy bo mạch: boardId={}, takenBy={}, repairOrderId={}",
                boardItemId, userId, request.repairOrderId());

        return toCheckoutResponse(savedCheckout, item);
    }

    /**
     * Trả bo mạch về kho sau khi sửa chữa xong
     * Chỉ có người đang giữ bo mạch hoặc admin mới được trả về
     */
    @Transactional
    public CheckoutResponse returnBoard(UUID boardItemId, UUID userId, boolean isAdmin, String returnNotes) {
        BoardItem item = findBoardById(boardItemId);
        if (!item.isCheckedOut())
            throw new BusinessException("Bo mạch không đang được mượn");

        BoardCheckout activeCheckout = boardCheckoutRepository
                .findActiveByBoardItemId(boardItemId)
                .orElseThrow(() -> new BusinessException("Không tìm thấy thông tin mượn"));

        if (!activeCheckout.getTakenBy().equals(userId) && !isAdmin)
            throw new BusinessException("Bạn không có quyền trả bo mạch này. " +
                    "Chỉ người đang giữ hoặc quản lý mới có thể trả.");

        // Ghi nhận trả
        activeCheckout.setReturnedAt(Instant.now());
        activeCheckout.setCheckoutStatus(CheckoutStatus.RETURNED);
        if (returnNotes != null && !returnNotes.trim().isEmpty()) {
            String existingNotes = activeCheckout.getNotes();
            if (existingNotes != null && !existingNotes.trim().isEmpty()) {
                activeCheckout.setNotes(existingNotes + " | Sửa chữa: " + returnNotes.trim());
            } else {
                activeCheckout.setNotes("Sửa chữa: " + returnNotes.trim());
            }
        }
        boardCheckoutRepository.save(activeCheckout);

        // Trả về AVAILABLE
        item.setStatus(BoardStatus.AVAILABLE);
        boardItemRepository.save(item);
        saveBoardMovement(
                item,
                StockMovementType.RETURN,
                null,
                item.getCurrentLocationId(),
                "BOARD_CHECKOUT",
                activeCheckout.getId(),
                activeCheckout.getNotes());

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
                checkout.getNotes());
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
                item.getSerialNumber(),
                item.getPartId(),
                partIpn(item.getPartId()),
                item.getCurrentLocationId(),
                locationCode(item.getCurrentLocationId()),
                item.getCreatedAt(),
                activeCheckout);
    }

    private UUID resolvePartId(String partIdStr) {
        if (!StringUtils.hasText(partIdStr)) return null;
        String trimmed = partIdStr.trim();
        try {
            UUID partId = UUID.fromString(trimmed);
            return partRepository.findByIdAndIsDeletedFalse(partId)
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy linh kiện: " + partId))
                    .getId();
        } catch (IllegalArgumentException e) {
            return partRepository.findByIpnAndIsDeletedFalse(trimmed)
                    .orElseGet(() -> {
                        UUID categoryId = getOrCreateUncategorizedCategory();
                        Part newPart = Part.builder()
                                .ipn(trimmed)
                                .name(trimmed)
                                .description("Tự động tạo từ liên kết bo mạch")
                                .categoryId(categoryId)
                                .minAmount(BigDecimal.ZERO)
                                .manufacturingStatus("ACTIVE")
                                .build();
                        Part saved = partRepository.save(newPart);
                        log.info("Tự động tạo linh kiện mới từ bo mạch: ipn={}, id={}", trimmed, saved.getId());
                        return saved;
                    })
                    .getId();
        }
    }

    private UUID getOrCreateUncategorizedCategory() {
        try {
            return jdbcTemplate.queryForObject(
                    "SELECT id FROM categories WHERE name = 'Uncategorized' AND is_deleted = false LIMIT 1",
                    UUID.class
            );
        } catch (Exception e) {
            try {
                return jdbcTemplate.queryForObject(
                        "SELECT id FROM categories WHERE is_deleted = false LIMIT 1",
                        UUID.class
                );
            } catch (Exception ex) {
                UUID newCategoryId = UUID.randomUUID();
                jdbcTemplate.update(
                        "INSERT INTO categories (id, name, description, not_selectable, is_deleted) VALUES (?, ?, ?, ?, ?)",
                        newCategoryId, "Uncategorized", "Default category for imported or board-linked parts", false, false
                );
                return newCategoryId;
            }
        }
    }

    private UUID resolveLocationId(String locationIdStr, String legacyLocation) {
        if (StringUtils.hasText(locationIdStr)) {
            String trimmed = locationIdStr.trim();
            try {
                UUID locationId = UUID.fromString(trimmed);
                return storeLocationRepository.findByIdAndIsDeletedFalse(locationId)
                        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy vị trí kho: " + locationId))
                        .getId();
            } catch (IllegalArgumentException e) {
                return storeLocationRepository.findByCodeAndIsDeletedFalse(trimmed)
                        .orElseGet(() -> {
                            StoreLocation newLocation = StoreLocation.builder()
                                    .code(trimmed)
                                    .name(trimmed)
                                    .description("Tự động tạo từ liên kết bo mạch")
                                    .isFull(false)
                                    .onlySinglePart(false)
                                    .build();
                            StoreLocation saved = storeLocationRepository.save(newLocation);
                            log.info("Tự động tạo vị trí kho mới: code={}, id={}", trimmed, saved.getId());
                            return saved;
                        })
                        .getId();
            }
        }
        if (!StringUtils.hasText(legacyLocation)) return null;
        String legacyTrimmed = legacyLocation.trim();
        return storeLocationRepository.findByCodeAndIsDeletedFalse(legacyTrimmed)
                .map(StoreLocation::getId)
                .orElseGet(() -> {
                    StoreLocation newLocation = StoreLocation.builder()
                            .code(legacyTrimmed)
                            .name(legacyTrimmed)
                            .description("Tự động tạo từ vị trí bo mạch")
                            .isFull(false)
                            .onlySinglePart(false)
                            .build();
                    StoreLocation saved = storeLocationRepository.save(newLocation);
                    log.info("Tự động tạo vị trí kho mới từ legacy location: code={}, id={}", legacyTrimmed, saved.getId());
                    return saved.getId();
                });
    }

    private void saveBoardMovement(
            BoardItem item,
            StockMovementType movementType,
            UUID fromLocationId,
            UUID toLocationId,
            String refType,
            UUID refId,
            String note) {
        stockMovementRepository.save(StockMovement.builder()
                .boardItemId(item.getId())
                .partId(item.getPartId())
                .movementType(movementType)
                .quantity(BigDecimal.ONE)
                .fromLocationId(fromLocationId)
                .toLocationId(toLocationId)
                .refType(refType)
                .refId(refId)
                .note(note)
                .build());
    }

    private String partIpn(UUID partId) {
        if (partId == null)
            return null;
        return partRepository.findByIdAndIsDeletedFalse(partId)
                .map(Part::getIpn)
                .orElse(null);
    }

    private String locationCode(UUID locationId) {
        if (locationId == null)
            return null;
        return storeLocationRepository.findByIdAndIsDeletedFalse(locationId)
                .map(StoreLocation::getCode)
                .orElse(null);
    }
}
