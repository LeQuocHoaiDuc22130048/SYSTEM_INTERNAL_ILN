package com.suachuabientan.system_internal.modules.warehouse.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.common.util.QrCodeGenerator;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CheckoutRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CreateBoardItemRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.ReturnBoardRequest;
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
import java.util.List;
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

        String serialNumber = StringUtils.hasText(request.serialNumber()) ? request.serialNumber().trim() : null;
        if (serialNumber != null && boardItemRepository.existsBySerialNumberAndIsDeletedFalse(serialNumber)) {
            throw new com.suachuabientan.system_internal.common.exception.BusinessException(
                    "Số serial '" + serialNumber + "' đã tồn tại trong hệ thống", 409);
        }

        BoardItem item = BoardItem.builder()
                .qrCode(qrCode)
                .name(request.name())
                .category(request.category())
                .description(request.description())
                .location(request.location())
                .serialNumber(serialNumber)
                .model(request.model())
                .boardType(request.boardType())
                .firmware(request.firmware())
                .removedParts(request.removedParts())
                .receivedDate(request.receivedDate())
                .note(request.note())
                .partId(resolvePartId(request.partId()))
                .currentLocationId(resolveLocationId(request.currentLocationId(), request.location()))
                .quantity(request.quantity() != null ? request.quantity() : 1)
                .minQuantity(request.minQuantity() != null ? request.minQuantity() : 0)
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
        if (request.serialNumber() != null) {
            String newSerial = StringUtils.hasText(request.serialNumber()) ? request.serialNumber().trim() : null;
            if (newSerial != null && boardItemRepository.existsBySerialNumberAndIdNotAndIsDeletedFalse(newSerial, id)) {
                throw new com.suachuabientan.system_internal.common.exception.BusinessException(
                        "Số serial '" + newSerial + "' đã tồn tại trong hệ thống", 409);
            }
            item.setSerialNumber(newSerial);
        }
        if (request.model() != null)
            item.setModel(request.model());
        if (request.boardType() != null)
            item.setBoardType(request.boardType());
        if (request.firmware() != null)
            item.setFirmware(request.firmware());
        if (request.removedParts() != null)
            item.setRemovedParts(request.removedParts());
        if (request.receivedDate() != null)
            item.setReceivedDate(request.receivedDate());
        if (request.note() != null)
            item.setNote(request.note());
        if (request.partId() != null)
            item.setPartId(resolvePartId(request.partId()));
        if (request.currentLocationId() != null || request.location() != null) {
            item.setCurrentLocationId(resolveLocationId(request.currentLocationId(), request.location()));
        }
        if (request.quantity() != null) {
            item.setQuantity(request.quantity());
        }
        if (request.minQuantity() != null) {
            item.setMinQuantity(request.minQuantity());
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
                                null, // orderCode — TODO: thêm sau khi có RepairOrder module
                                checkout.getQuantity(),
                                checkout.getRepairBrand()
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
                item.getModel(),
                item.getBoardType(),
                item.getFirmware(),
                item.getRemovedParts(),
                item.getReceivedDate(),
                item.getNote(),
                item.getPartId(),
                partIpn(item.getPartId()),
                item.getCurrentLocationId(),
                locationCode(item.getCurrentLocationId()),
                item.getStatus().name(),
                item.getQuantity(),
                item.getMinQuantity() != null ? item.getMinQuantity() : 0,
                holderInfo);
    }


    // Checkout lấy bo mạch

    /**
     * Lấy bo mạch ra khỏi kho để sửa chữa.
     * Trừ số lượng vào tồn kho của BoardItem.
     * Chỉ đổi trạng thái sang CHECKED_OUT khi hết hàng.
     */
    @Transactional
    public CheckoutResponse checkout(UUID boardItemId, CheckoutRequest request, UUID userId) {
        BoardItem item = findBoardById(boardItemId);

        // Chỉ cho phép lấy khi ở trạng thái AVAILABLE hoặc CHECKED_OUT và còn hàng trong kho
        if (item.getStatus() != BoardStatus.AVAILABLE && item.getStatus() != BoardStatus.CHECKED_OUT)
            throw new BusinessException(STR."Bo mạch không ở trạng thái sẵn sàng để mượn. Trạng thái hiện tại: \{item.getStatus().name()}");
        if (!item.hasStock())
            throw new BusinessException("Bo mạch không còn số lượng trong kho");

        int qtyTaken = (request.quantity() != null && request.quantity() > 0) ? request.quantity() : 1;
        int currentQty = item.getQuantity() != null ? item.getQuantity() : 0;

        // Kiểm tra đủ số lượng
        if (qtyTaken > currentQty)
            throw new BusinessException(
                    STR."Không đủ số lượng trong kho. Yêu cầu \{qtyTaken}, tồn kho \{currentQty}.");

        // Trừ số lượng kho
        int newQty = currentQty - qtyTaken;
        item.setQuantity(newQty);

        // Chỉ đổi sang CHECKED_OUT khi hết hàng
        if (newQty == 0) {
            item.setStatus(BoardStatus.CHECKED_OUT);
        } else {
            // Vẫn còn hàng, giữ AVAILABLE để người khác có thể lấy tiếp
            item.setStatus(BoardStatus.AVAILABLE);
        }

        boardItemRepository.save(item);

        BoardCheckout checkout = BoardCheckout.builder()
                .boardItemId(boardItemId)
                .takenBy(userId)
                .repairOrderId(request.repairOrderId())
                .takenAt(Instant.now())
                .notes(request.note())
                .quantity(qtyTaken)
                .repairBrand(request.repairBrand())
                .checkoutStatus(CheckoutStatus.OPEN)
                .build();

        BoardCheckout savedCheckout = boardCheckoutRepository.save(checkout);

        saveBoardMovement(
                item,
                request.repairOrderId() != null ? StockMovementType.USE_FOR_REPAIR : StockMovementType.EXPORT,
                BigDecimal.valueOf(qtyTaken),
                item.getCurrentLocationId(),
                null,
                "BOARD_CHECKOUT",
                savedCheckout.getId(),
                request.note());

        log.info("Lấy bo mạch: boardId={}, takenBy={}, qty={}, remainQty={}",
                boardItemId, userId, qtyTaken, newQty);

        return toCheckoutResponse(savedCheckout, item);
    }

    /**
     * Trả bo mạch về kho sau khi sửa chữa xong.
     * Cộng số lượng trả lại vào tồn kho BoardItem.
     * Trả về AVAILABLE nếu còn hàng, CHECKED_OUT nếu vẫn còn người đang giữ.
     */
    @Transactional
    public CheckoutResponse returnBoard(UUID boardItemId, UUID userId, boolean isAdmin, ReturnBoardRequest request) {
        BoardItem item = findBoardById(boardItemId);

        // Tìm checkout của đúng người đang trả hoặc theo checkoutId cụ thể nếu truyền
        BoardCheckout activeCheckout;
        if (request.checkoutId() != null) {
            activeCheckout = boardCheckoutRepository.findByIdAndIsDeletedFalse(request.checkoutId())
                    .orElseThrow(() -> new BusinessException("Không tìm thấy thông tin mượn với ID: " + request.checkoutId()));
            if (!boardItemId.equals(activeCheckout.getBoardItemId())) {
                throw new BusinessException("Lượt mượn này không thuộc bo mạch được chọn");
            }
            if (activeCheckout.getCheckoutStatus() != CheckoutStatus.OPEN || activeCheckout.getReturnedAt() != null) {
                throw new BusinessException("Lượt mượn này đã được trả hoặc không còn mở");
            }
            if (!isAdmin && !userId.equals(activeCheckout.getTakenBy())) {
                throw new BusinessException("Bạn không có quyền trả lượt mượn của người khác");
            }
        } else if (isAdmin) {
            // Admin có thể trả thay người khác — tìm bất kỳ checkout active nào
            activeCheckout = boardCheckoutRepository
                    .findActiveByBoardItemId(boardItemId)
                    .orElseThrow(() -> new BusinessException("Không tìm thấy thông tin mượn cho bo mạch này"));
        } else {
            activeCheckout = boardCheckoutRepository
                    .findActiveByBoardItemIdAndTakenBy(boardItemId, userId)
                    .orElseThrow(() -> new BusinessException(
                            "Bạn không có bản ghi mượn nào đang mở cho bo mạch này"));
        }

        int checkedOutQty = activeCheckout.getQuantity() != null ? activeCheckout.getQuantity() : 1;
        String returnType = request.returnType(); // "FULL" | "PARTIAL" | null (legacy = FULL)
        String reason = request.reason();
        String notes = request.notes();
        int returnQty;

        if ("PARTIAL".equalsIgnoreCase(returnType)) {
            if (request.returnQuantity() == null || request.returnQuantity() <= 0)
                throw new BusinessException("Vui lòng nhập số lượng trả lại hợp lệ");
            returnQty = request.returnQuantity();
            if (returnQty >= checkedOutQty) {
                returnQty = checkedOutQty;
                returnType = "FULL";
            }
        } else {
            returnQty = checkedOutQty;
        }

        // Xây dựng ghi chú
        StringBuilder noteBuilder = new StringBuilder();
        if (notes != null && !notes.trim().isEmpty()) noteBuilder.append(notes.trim());
        if (reason != null && !reason.trim().isEmpty()) {
            if (noteBuilder.length() > 0) noteBuilder.append(" | ");
            noteBuilder.append("Lý do thiếu: ").append(reason.trim());
        }
        if ("PARTIAL".equalsIgnoreCase(returnType)) {
            if (noteBuilder.length() > 0) noteBuilder.append(" | ");
            noteBuilder.append("Trả một phần: ").append(returnQty).append("/").append(checkedOutQty);
        }
        String existingNotes = activeCheckout.getNotes();
        String finalNotes;
        if (noteBuilder.length() > 0) {
            finalNotes = (existingNotes != null && !existingNotes.trim().isEmpty())
                    ? existingNotes + " | Trả: " + noteBuilder
                    : noteBuilder.toString();
        } else {
            finalNotes = existingNotes;
        }
        activeCheckout.setNotes(finalNotes);

        // Cộng số lượng trả lại vào tồn kho
        int currentQty = item.getQuantity() != null ? item.getQuantity() : 0;
        int newQty = currentQty + returnQty;
        item.setQuantity(newQty);

        if ("PARTIAL".equalsIgnoreCase(returnType)) {
            // Trả một phần: giảm quantity trong checkout record, board cập nhật qty
            int remainingInCheckout = checkedOutQty - returnQty;
            activeCheckout.setQuantity(remainingInCheckout);
            boardCheckoutRepository.save(activeCheckout);

            // Cập nhật trạng thái board: nếu còn stock → AVAILABLE, nếu không → CHECKED_OUT
            List<BoardCheckout> allActive = boardCheckoutRepository.findAllActiveByBoardItemId(boardItemId);
            int totalStillOut = allActive.stream().mapToInt(c -> c.getQuantity() != null ? c.getQuantity() : 0).sum();
            item.setStatus(newQty > 0 ? BoardStatus.AVAILABLE : BoardStatus.CHECKED_OUT);
            boardItemRepository.save(item);

            saveBoardMovement(
                    item, StockMovementType.RETURN, BigDecimal.valueOf(returnQty), null, item.getCurrentLocationId(),
                    "BOARD_PARTIAL_RETURN", activeCheckout.getId(),
                    "Trả một phần: " + returnQty + "/" + checkedOutQty);

            log.info("Trả một phần bo mạch: boardId={}, by={}, returnQty={}/{}, newStock={}, totalStillOut={}",
                    boardItemId, userId, returnQty, checkedOutQty, newQty, totalStillOut);
        } else {
            // FULL return: đóng checkout
            activeCheckout.setReturnedAt(Instant.now());
            activeCheckout.setCheckoutStatus(CheckoutStatus.RETURNED);
            boardCheckoutRepository.save(activeCheckout);

            // Kiểm tra xem còn checkout nào active không
            List<BoardCheckout> remainingActive = boardCheckoutRepository.findAllActiveByBoardItemId(boardItemId);
            if (remainingActive.isEmpty() || newQty > 0) {
                item.setStatus(BoardStatus.AVAILABLE);
            } else {
                item.setStatus(BoardStatus.CHECKED_OUT);
            }
            boardItemRepository.save(item);

            saveBoardMovement(
                    item, StockMovementType.RETURN, BigDecimal.valueOf(returnQty), null, item.getCurrentLocationId(),
                    "BOARD_CHECKOUT", activeCheckout.getId(), activeCheckout.getNotes());

            log.info("Trả hết bo mạch: boardId={}, by={}, returnQty={}, newStock={}",
                    boardItemId, userId, returnQty, newQty);
        }

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
                checkout.getNotes(),
                checkout.getQuantity(),
                checkout.getRepairBrand());
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
                                null, // orderCode — TODO
                                checkout.getQuantity(),
                                checkout.getRepairBrand()
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
                item.getStatus() != null ? item.getStatus().name() : "AVAILABLE",
                item.getLocation(),
                item.getSerialNumber(),
                item.getModel(),
                item.getBoardType(),
                item.getFirmware(),
                item.getRemovedParts(),
                item.getReceivedDate(),
                item.getNote(),
                item.getPartId(),
                partIpn(item.getPartId()),
                item.getCurrentLocationId(),
                locationCode(item.getCurrentLocationId()),
                item.getCreatedAt(),
                item.getQuantity(),
                item.getMinQuantity() != null ? item.getMinQuantity() : 0,
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
            String ipn100 = trimmed.length() > 100 ? trimmed.substring(0, 100) : trimmed;
            return partRepository.findByIpnAndIsDeletedFalse(ipn100)
                    .orElseGet(() -> {
                        UUID categoryId = getOrCreateUncategorizedCategory();
                        Part newPart = Part.builder()
                                .ipn(ipn100)
                                .name(trimmed)
                                .description("Tự động tạo từ liên kết bo mạch")
                                .categoryId(categoryId)
                                .minAmount(BigDecimal.ZERO)
                                .manufacturingStatus("ACTIVE")
                                .build();
                        Part saved = partRepository.save(newPart);
                        log.info("Tự động tạo linh kiện mới từ bo mạch: ipn={}, id={}", ipn100, saved.getId());
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
                String code80 = trimmed.length() > 80 ? trimmed.substring(0, 80) : trimmed;
                return storeLocationRepository.findByCodeAndIsDeletedFalse(code80)
                        .orElseGet(() -> {
                            StoreLocation newLocation = StoreLocation.builder()
                                    .code(code80)
                                    .name(trimmed)
                                    .description("Tự động tạo từ liên kết bo mạch")
                                    .isFull(false)
                                    .onlySinglePart(false)
                                    .build();
                            StoreLocation saved = storeLocationRepository.save(newLocation);
                            log.info("Tự động tạo vị trí kho mới: code={}, id={}", code80, saved.getId());
                            return saved;
                        })
                        .getId();
            }
        }
        if (!StringUtils.hasText(legacyLocation)) return null;
        String legacyTrimmed = legacyLocation.trim();
        String code80 = legacyTrimmed.length() > 80 ? legacyTrimmed.substring(0, 80) : legacyTrimmed;
        return storeLocationRepository.findByCodeAndIsDeletedFalse(code80)
                .map(StoreLocation::getId)
                .orElseGet(() -> {
                    StoreLocation newLocation = StoreLocation.builder()
                            .code(code80)
                            .name(legacyTrimmed)
                            .description("Tự động tạo từ vị trí bo mạch")
                            .isFull(false)
                            .onlySinglePart(false)
                            .build();
                    StoreLocation saved = storeLocationRepository.save(newLocation);
                    log.info("Tự động tạo vị trí kho mới từ legacy location: code={}, id={}", code80, saved.getId());
                    return saved.getId();
                });
    }

    private void saveBoardMovement(
            BoardItem item,
            StockMovementType movementType,
            BigDecimal quantity,
            UUID fromLocationId,
            UUID toLocationId,
            String refType,
            UUID refId,
            String note) {
        stockMovementRepository.save(StockMovement.builder()
                .boardItemId(item.getId())
                .partId(item.getPartId())
                .movementType(movementType)
                .quantity(quantity != null ? quantity : BigDecimal.ONE)
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
