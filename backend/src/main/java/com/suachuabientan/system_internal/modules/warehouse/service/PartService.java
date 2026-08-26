package com.suachuabientan.system_internal.modules.warehouse.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.enums.UserRole;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.notification.enums.NotificationType;
import com.suachuabientan.system_internal.modules.notification.service.NotificationService;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.AdjustStockRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.BulkImportPartItemRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.BulkImportPartRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CreatePartRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.PartCheckoutRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.PartReturnRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.UpdatePartRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CreateStoreLocationRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.UpdateStoreLocationRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.BulkImportPartResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.CategoryInfo;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.LocationInfo;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.LocationScanResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.PartCheckoutHistoryResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.PartLotResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.PartResponse;
import com.suachuabientan.system_internal.modules.warehouse.entity.Part;
import com.suachuabientan.system_internal.modules.warehouse.entity.PartCheckout;
import com.suachuabientan.system_internal.modules.warehouse.entity.PartLot;
import com.suachuabientan.system_internal.modules.warehouse.entity.StockMovement;
import com.suachuabientan.system_internal.modules.warehouse.entity.StoreLocation;
import com.suachuabientan.system_internal.modules.warehouse.enums.CheckoutStatus;
import com.suachuabientan.system_internal.modules.warehouse.enums.PartCondition;
import com.suachuabientan.system_internal.modules.warehouse.enums.StockMovementType;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartCheckoutRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartLotRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.StockMovementRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.StoreLocationRepository;
import java.util.Objects;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PartService {
    private final PartRepository partRepository;
    private final PartLotRepository partLotRepository;
    private final StoreLocationRepository storeLocationRepository;
    private final StockMovementRepository stockMovementRepository;
    private final PartCheckoutRepository partCheckoutRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final JdbcTemplate jdbcTemplate;
    private final com.suachuabientan.system_internal.modules.warehouse.repository.BoardItemRepository boardItemRepository;

    private static final List<UserRole> WAREHOUSE_ALERT_ROLES = List.of(
            UserRole.SUPER_ADMIN,
            UserRole.ADMIN,
            UserRole.MANAGER,
            UserRole.WAREHOUSE,
            UserRole.TECHNICIAN
    );

    @Transactional(readOnly = true)
    public Page<PartResponse> getAll(String keyword, Pageable pageable) {
        return partRepository.searchParts(keyword, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public PartResponse getById(UUID id) {
        Part part = partRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy linh kiện: " + id));
        return toResponse(part);
    }

    @Transactional
    public PartResponse create(CreatePartRequest request, UUID createdByUserId) {
        String ipn = request.ipn().trim();
        if (partRepository.findByIpnAndIsDeletedFalse(ipn).isPresent()) {
            throw new BusinessException("Mã IPN " + ipn + " đã tồn tại trong hệ thống");
        }

        UUID categoryId = request.categoryId();
        if (categoryId == null && StringUtils.hasText(request.categoryName())) {
            categoryId = getOrCreateCategory(request.categoryName().trim());
        }
        if (categoryId == null) {
            categoryId = getOrCreateUncategorizedCategory();
        }

        Part part = Part.builder()
                .ipn(ipn)
                .name(request.name().trim())
                .description(request.description())
                .minAmount(request.minAmount() != null ? request.minAmount() : BigDecimal.ZERO)
                .maxAmount(request.maxAmount() != null ? request.maxAmount() : BigDecimal.ZERO)
                .purchasePrice(request.purchasePrice())
                .salePrice(request.salePrice())
                .manufacturingStatus(request.manufacturingStatus() != null ? request.manufacturingStatus() : "ACTIVE")
                .parameters(request.parameters())
                .datasheetUrl(request.datasheetUrl())
                .imageUrl(request.imageUrl())
                .note(request.note())
                .categoryId(categoryId)
                .footprintId(request.footprintId())
                .manufacturerId(request.manufacturerId())
                .measurementUnitId(request.measurementUnitId())
                .build();

        part.setCreatedBy(createdByUserId);
        Part saved = partRepository.save(part);
        log.info("Tạo linh kiện mới: ipn={}, name={}, by={}", saved.getIpn(), saved.getName(), createdByUserId);
        return toResponse(saved);
    }

    @Transactional
    public PartResponse update(UUID id, UpdatePartRequest request, UUID updatedByUserId) {
        Part part = partRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy linh kiện: " + id));

        if (request.ipn() != null) {
            String ipn = request.ipn().trim();
            partRepository.findByIpnAndIsDeletedFalse(ipn)
                    .ifPresent(existing -> {
                        if (!existing.getId().equals(id)) {
                            throw new BusinessException("Mã IPN " + ipn + " đã tồn tại ở linh kiện khác");
                        }
                    });
            part.setIpn(ipn);
        }

        if (request.name() != null) {
            part.setName(request.name().trim());
        }
        if (request.description() != null) {
            part.setDescription(request.description().trim());
        }
        if (request.minAmount() != null) {
            part.setMinAmount(request.minAmount());
        }
        if (request.maxAmount() != null) {
            part.setMaxAmount(request.maxAmount());
        }
        if (request.purchasePrice() != null) {
            part.setPurchasePrice(request.purchasePrice());
        }
        if (request.salePrice() != null) {
            part.setSalePrice(request.salePrice());
        }
        if (request.manufacturingStatus() != null) {
            part.setManufacturingStatus(request.manufacturingStatus());
        }
        if (request.parameters() != null) {
            part.setParameters(request.parameters());
        }
        if (request.datasheetUrl() != null) {
            part.setDatasheetUrl(request.datasheetUrl());
        }
        if (request.imageUrl() != null) {
            part.setImageUrl(request.imageUrl());
        }
        if (request.note() != null) {
            part.setNote(request.note());
        }
        if (request.footprintId() != null) {
            part.setFootprintId(request.footprintId());
        }
        if (request.manufacturerId() != null) {
            part.setManufacturerId(request.manufacturerId());
        }
        if (request.measurementUnitId() != null) {
            part.setMeasurementUnitId(request.measurementUnitId());
        }

        if (request.categoryId() != null) {
            part.setCategoryId(request.categoryId());
        } else if (request.categoryName() != null && !request.categoryName().trim().isEmpty()) {
            part.setCategoryId(getOrCreateCategory(request.categoryName().trim()));
        }

        part.setUpdatedBy(updatedByUserId);
        Part saved = partRepository.save(part);
        log.info("Cập nhật linh kiện: id={}, by={}", id, updatedByUserId);
        return toResponse(saved);
    }

    @Transactional
    public void delete(UUID id, UUID deletedByUserId) {
        Part part = partRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy linh kiện: " + id));

        List<PartLot> lots = partLotRepository.findByPartIdAndIsDeletedFalse(id);
        BigDecimal totalQty = lots.stream()
                .map(PartLot::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        if (totalQty.compareTo(BigDecimal.ZERO) > 0) {
            throw new BusinessException("Không thể xoá linh kiện khi vẫn còn hàng tồn kho (" + totalQty + ")");
        }

        part.softDelete(deletedByUserId);
        partRepository.save(part);
        log.info("Xoá linh kiện: id={}, by={}", id, deletedByUserId);
    }

    @Transactional
    public PartResponse adjustStock(UUID partId, AdjustStockRequest request, UUID userId) {
        Part part = partRepository.findByIdAndIsDeletedFalse(partId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy linh kiện: " + partId));

        String locCode = request.storeLocationCode().trim();
        StoreLocation location = storeLocationRepository.findByCodeIgnoreCaseAndIsDeletedFalse(locCode)
                .or(() -> storeLocationRepository.findByCodeOrQrCode(locCode))
                .orElseGet(() -> {
                    StoreLocation newLoc = StoreLocation.builder()
                            .code(locCode)
                            .name(locCode)
                            .qrCode(locCode)
                            .description("Tự động tạo từ điều chỉnh kho linh kiện")
                            .isFull(false)
                            .onlySinglePart(false)
                            .build();
                    newLoc.setCreatedBy(userId);
                    return storeLocationRepository.save(newLoc);
                });

        PartLot lot = partLotRepository.findByPartIdAndStoreLocationIdAndIsDeletedFalse(part.getId(), location.getId())
                .orElse(null);

        BigDecimal oldAmount = BigDecimal.ZERO;
        BigDecimal newAmount = request.amount();

        if (newAmount.compareTo(BigDecimal.ZERO) < 0) {
            throw new BusinessException("Số lượng không được âm");
        }

        if (lot != null) {
            oldAmount = lot.getAmount();
            lot.setAmount(newAmount);
            lot.setUpdatedBy(userId);
            partLotRepository.save(lot);
        } else {
            lot = PartLot.builder()
                    .partId(part.getId())
                    .storeLocationId(location.getId())
                    .amount(newAmount)
                    .instockUnknown(false)
                    .needsRefill(false)
                    .lotCode("LOT-" + part.getIpn() + "-" + System.currentTimeMillis())
                    .build();
            lot.setCreatedBy(userId);
            partLotRepository.save(lot);
        }

        BigDecimal delta = newAmount.subtract(oldAmount);
        if (delta.compareTo(BigDecimal.ZERO) != 0) {
            stockMovementRepository.save(StockMovement.builder()
                    .partId(part.getId())
                    .partLotId(lot.getId())
                    .movementType(StockMovementType.ADJUST)
                    .quantity(delta.abs())
                    .fromLocationId(delta.compareTo(BigDecimal.ZERO) < 0 ? location.getId() : null)
                    .toLocationId(delta.compareTo(BigDecimal.ZERO) > 0 ? location.getId() : null)
                    .refType("INVENTORY_ADJUSTMENT")
                    .refId(lot.getId())
                    .note(StringUtils.hasText(request.note()) ? request.note() : "Điều chỉnh kho linh kiện")
                    .build());
        }

        checkAndNotifyLowStock(part);

        return toResponse(part);
    }

    // ── Bulk Import Linh Kiện từ Excel/CSV ──────────────────────────────
    @Transactional
    public BulkImportPartResponse bulkImport(BulkImportPartRequest request, UUID userId) {
        if (request.items() == null || request.items().isEmpty()) {
            throw new BusinessException("Danh sách linh kiện nhập trống");
        }

        int successCount = 0;
        int updatedCount = 0;
        int failedCount = 0;
        List<BulkImportPartResponse.BulkImportErrorItem> errors = new ArrayList<>();
        List<PartResponse> importedParts = new ArrayList<>();

        for (int i = 0; i < request.items().size(); i++) {
            int rowNumber = i + 1;
            BulkImportPartItemRequest item = request.items().get(i);

            if (item.ipn() == null || item.ipn().trim().isEmpty()) {
                errors.add(new BulkImportPartResponse.BulkImportErrorItem(rowNumber, "", "Mã IPN không được để trống"));
                failedCount++;
                continue;
            }

            if (item.name() == null || item.name().trim().isEmpty()) {
                errors.add(new BulkImportPartResponse.BulkImportErrorItem(rowNumber, item.ipn().trim(), "Tên linh kiện không được để trống"));
                failedCount++;
                continue;
            }

            String ipn = item.ipn().trim();
            var existingOpt = partRepository.findByIpnAndIsDeletedFalse(ipn);

            if (existingOpt.isPresent()) {
                if (!request.updateIfExists()) {
                    errors.add(new BulkImportPartResponse.BulkImportErrorItem(rowNumber, ipn, "Mã IPN đã tồn tại trong hệ thống"));
                    failedCount++;
                    continue;
                }

                // Cập nhật thông tin linh kiện đã có
                Part existingPart = existingOpt.get();
                if (StringUtils.hasText(item.name())) existingPart.setName(item.name().trim());
                if (StringUtils.hasText(item.description())) existingPart.setDescription(item.description().trim());
                if (item.minAmount() != null) existingPart.setMinAmount(item.minAmount());
                if (item.maxAmount() != null) existingPart.setMaxAmount(item.maxAmount());
                if (item.purchasePrice() != null) existingPart.setPurchasePrice(item.purchasePrice());
                if (item.salePrice() != null) existingPart.setSalePrice(item.salePrice());
                if (StringUtils.hasText(item.parameters())) existingPart.setParameters(item.parameters());
                if (StringUtils.hasText(item.note())) existingPart.setNote(item.note());
                if (StringUtils.hasText(item.categoryName())) {
                    existingPart.setCategoryId(getOrCreateCategory(item.categoryName().trim()));
                }
                existingPart.setUpdatedBy(userId);
                Part savedPart = partRepository.save(existingPart);

                // Nếu có số lượng hoặc vị trí thì cập nhật / cộng dồn kho
                BigDecimal importQty = item.quantity() != null ? item.quantity() : BigDecimal.ZERO;
                if (importQty.compareTo(BigDecimal.ZERO) > 0 || StringUtils.hasText(item.storeLocationCode())) {
                    String locCode = StringUtils.hasText(item.storeLocationCode()) ? item.storeLocationCode().trim() : "DEFAULT";
                    StoreLocation location = storeLocationRepository.findByCodeIgnoreCaseAndIsDeletedFalse(locCode)
                            .or(() -> storeLocationRepository.findByCodeOrQrCode(locCode))
                            .orElseGet(() -> {
                                StoreLocation newLoc = StoreLocation.builder()
                                        .code(locCode)
                                        .name(locCode)
                                        .qrCode(locCode)
                                        .description("Tự động tạo từ nhập kho hàng loạt")
                                        .isFull(false)
                                        .onlySinglePart(false)
                                        .build();
                                newLoc.setCreatedBy(userId);
                                return storeLocationRepository.save(newLoc);
                            });

                    PartLot lot = partLotRepository.findByPartIdAndStoreLocationIdAndIsDeletedFalse(savedPart.getId(), location.getId())
                            .orElse(null);

                    if (lot != null) {
                        lot.setAmount(lot.getAmount().add(importQty));
                        lot.setUpdatedBy(userId);
                        partLotRepository.save(lot);
                    } else {
                        lot = PartLot.builder()
                                .partId(savedPart.getId())
                                .storeLocationId(location.getId())
                                .amount(importQty)
                                .origin("NEW")
                                .condition(StringUtils.hasText(item.condition()) ? item.condition() : "TESTED_OK")
                                .instockUnknown(false)
                                .needsRefill(false)
                                .lotCode("LOT-" + savedPart.getIpn() + "-" + System.currentTimeMillis())
                                .build();
                        lot.setCreatedBy(userId);
                        partLotRepository.save(lot);
                    }

                    if (importQty.compareTo(BigDecimal.ZERO) > 0) {
                        String movementCode = "PN-" + java.time.LocalDate.now().toString().replace("-", "") + "-" + UUID.randomUUID().toString().substring(0, 6).toUpperCase();
                        stockMovementRepository.save(StockMovement.builder()
                                .movementCode(movementCode)
                                .partId(savedPart.getId())
                                .partLotId(lot.getId())
                                .storageLocationId(location.getId())
                                .toLocationId(location.getId())
                                .movementType(StockMovementType.IMPORT)
                                .quantity(importQty)
                                .amount(importQty)
                                .movementStatus("COMPLETED")
                                .refType("BULK_IMPORT")
                                .refId(lot.getId())
                                .purpose("Nhập kho linh kiện hàng loạt từ Excel")
                                .note("Cộng dồn số lượng: " + importQty)
                                .build());
                    }
                }

                importedParts.add(toResponse(savedPart));
                updatedCount++;
            } else {
                // Tạo mới Part
                UUID categoryId = StringUtils.hasText(item.categoryName())
                        ? getOrCreateCategory(item.categoryName().trim())
                        : getOrCreateUncategorizedCategory();

                Part newPart = Part.builder()
                        .ipn(ipn)
                        .name(item.name().trim())
                        .description(item.description())
                        .categoryId(categoryId)
                        .minAmount(item.minAmount() != null ? item.minAmount() : BigDecimal.ZERO)
                        .maxAmount(item.maxAmount() != null ? item.maxAmount() : BigDecimal.ZERO)
                        .purchasePrice(item.purchasePrice())
                        .salePrice(item.salePrice())
                        .manufacturingStatus("ACTIVE")
                        .parameters(item.parameters())
                        .note(item.note())
                        .build();
                newPart.setCreatedBy(userId);
                Part savedPart = partRepository.save(newPart);

                // Khởi tạo Lô và Vị trí nếu có
                BigDecimal importQty = item.quantity() != null ? item.quantity() : BigDecimal.ZERO;
                if (importQty.compareTo(BigDecimal.ZERO) > 0 || StringUtils.hasText(item.storeLocationCode())) {
                    String locCode = StringUtils.hasText(item.storeLocationCode()) ? item.storeLocationCode().trim() : "DEFAULT";
                    StoreLocation location = storeLocationRepository.findByCodeIgnoreCaseAndIsDeletedFalse(locCode)
                            .or(() -> storeLocationRepository.findByCodeOrQrCode(locCode))
                            .orElseGet(() -> {
                                StoreLocation newLoc = StoreLocation.builder()
                                        .code(locCode)
                                        .name(locCode)
                                        .qrCode(locCode)
                                        .description("Tự động tạo từ nhập kho hàng loạt")
                                        .isFull(false)
                                        .onlySinglePart(false)
                                        .build();
                                newLoc.setCreatedBy(userId);
                                return storeLocationRepository.save(newLoc);
                            });

                    PartLot lot = PartLot.builder()
                            .partId(savedPart.getId())
                            .storeLocationId(location.getId())
                            .amount(importQty)
                            .origin("NEW")
                            .condition(StringUtils.hasText(item.condition()) ? item.condition() : "TESTED_OK")
                            .instockUnknown(false)
                            .needsRefill(false)
                            .lotCode("LOT-" + savedPart.getIpn() + "-" + System.currentTimeMillis())
                            .build();
                    lot.setCreatedBy(userId);
                    partLotRepository.save(lot);

                    if (importQty.compareTo(BigDecimal.ZERO) > 0) {
                        String movementCode = "PN-" + java.time.LocalDate.now().toString().replace("-", "") + "-" + UUID.randomUUID().toString().substring(0, 6).toUpperCase();
                        stockMovementRepository.save(StockMovement.builder()
                                .movementCode(movementCode)
                                .partId(savedPart.getId())
                                .partLotId(lot.getId())
                                .storageLocationId(location.getId())
                                .toLocationId(location.getId())
                                .movementType(StockMovementType.IMPORT)
                                .quantity(importQty)
                                .amount(importQty)
                                .movementStatus("COMPLETED")
                                .refType("BULK_IMPORT")
                                .refId(lot.getId())
                                .purpose("Nhập kho linh kiện hàng loạt từ Excel")
                                .note("Nhập ban đầu: " + importQty)
                                .build());
                    }
                }

                importedParts.add(toResponse(savedPart));
                successCount++;
            }
        }

        log.info("Nhập linh kiện hàng loạt: total={}, success={}, updated={}, failed={}, by={}",
                request.items().size(), successCount, updatedCount, failedCount, userId);

        return new BulkImportPartResponse(
                request.items().size(),
                successCount,
                updatedCount,
                failedCount,
                errors,
                importedParts
        );
    }

    // ── 1. Quét QR Vị trí Kho ──────────────────────────────────────────
    @Transactional
    public LocationScanResponse scanLocationQr(String codeOrQr) {
        String cleanCode = codeOrQr.trim();
        cleanCode = cleanCode.replaceAll("(?i)^(?:mã qr|mã vị trí kho|vị trí|location):\\s*", "").trim();

        List<StoreLocation> matchingLocations = new ArrayList<>(storeLocationRepository.findAllByCodeOrQrCodeIgnoreCase(cleanCode));

        // Kiểm tra nếu là UUID của StoreLocation
        if (matchingLocations.isEmpty()) {
            try {
                UUID locUuid = UUID.fromString(cleanCode);
                storeLocationRepository.findByIdAndIsDeletedFalse(locUuid).ifPresent(matchingLocations::add);
            } catch (Exception ignored) {}
        }

        // Kiểm tra nếu quét trúng mã IPN hoặc ID của Linh kiện -> chuyển hướng sang vị trí kho của linh kiện
        if (matchingLocations.isEmpty()) {
            Optional<Part> partOpt = partRepository.findByIpnAndIsDeletedFalse(cleanCode);
            if (partOpt.isEmpty()) {
                try {
                    UUID partUuid = UUID.fromString(cleanCode);
                    partOpt = partRepository.findByIdAndIsDeletedFalse(partUuid);
                } catch (Exception ignored) {}
            }
            if (partOpt.isPresent()) {
                Part p = partOpt.get();
                List<PartLot> lots = partLotRepository.findByPartIdAndIsDeletedFalse(p.getId());
                for (PartLot lot : lots) {
                    if (lot.getStoreLocationId() != null) {
                        storeLocationRepository.findByIdAndIsDeletedFalse(lot.getStoreLocationId())
                                .ifPresent(matchingLocations::add);
                    }
                }
                if (!matchingLocations.isEmpty()) {
                    return scanLocationQr(matchingLocations.get(0).getCode());
                }
            }
        }

        StoreLocation location;
        List<UUID> locationIds = new ArrayList<>();

        if (matchingLocations.isEmpty()) {
            // Kiểm tra xem có bo mạch nào lưu ở vị trí này không
            List<com.suachuabientan.system_internal.modules.warehouse.entity.BoardItem> boards =
                    boardItemRepository.findByLocationText(cleanCode);
            if (boards.isEmpty()) {
                // Kiểm tra nếu mã quét là mã QR của chính bo mạch
                var boardByQr = boardItemRepository.findByQrCodeAndIsDeletedFalse(cleanCode);
                if (boardByQr.isEmpty()) {
                    try {
                        UUID boardUuid = UUID.fromString(cleanCode);
                        boardByQr = boardItemRepository.findByIdAndIsDeletedFalse(boardUuid);
                    } catch (Exception ignored) {}
                }
                if (boardByQr.isPresent()) {
                    var b = boardByQr.get();
                    if (b.getCurrentLocationId() != null) {
                        var locOpt = storeLocationRepository.findByIdAndIsDeletedFalse(b.getCurrentLocationId());
                        if (locOpt.isPresent()) {
                            return scanLocationQr(locOpt.get().getCode());
                        }
                    }
                    String loc = b.getLocation() != null ? b.getLocation() : "KHO";
                    return scanLocationQr(loc);
                }
                throw new ResourceNotFoundException("Không tìm thấy vị trí kho, bo mạch hoặc linh kiện với mã: " + codeOrQr);
            }

            // Tự động tạo và lưu vị trí kho để đồng bộ lâu dài
            StoreLocation newLoc = StoreLocation.builder()
                    .code(cleanCode.toUpperCase())
                    .name("Vị trí " + cleanCode)
                    .description("Vị trí kho " + cleanCode)
                    .qrCode(cleanCode)
                    .isFull(false)
                    .build();
            try {
                location = storeLocationRepository.save(newLoc);
                locationIds.add(location.getId());
            } catch (Exception e) {
                location = newLoc;
            }
        } else {
            location = matchingLocations.get(0);
            locationIds = matchingLocations.stream().map(StoreLocation::getId).filter(Objects::nonNull).distinct().toList();
        }

        List<PartLot> lots = locationIds.isEmpty() ? List.of() : partLotRepository.findByStoreLocationIdInAndIsDeletedFalse(locationIds);
        List<LocationScanResponse.LocationPartItem> partItems = new ArrayList<>();
        BigDecimal totalPartQty = BigDecimal.ZERO;

        for (PartLot lot : lots) {
            if (lot.getAmount() == null || lot.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
                continue;
            }
            Part part = partRepository.findByIdAndIsDeletedFalse(lot.getPartId()).orElse(null);
            if (part == null) continue;

            totalPartQty = totalPartQty.add(lot.getAmount());
            partItems.add(new LocationScanResponse.LocationPartItem(
                    part.getId(),
                    lot.getId(),
                    part.getIpn(),
                    part.getName(),
                    part.getDescription(),
                    lot.getAmount(),
                    "Cái/Chiếc",
                    getCategoryName(part.getCategoryId()),
                    part.getImageUrl(),
                    lot.getCondition() != null ? lot.getCondition() : "NGUYEN_VEN"
            ));
        }

        // Tìm các bo mạch (BoardItem) được gán ở vị trí này
        List<com.suachuabientan.system_internal.modules.warehouse.entity.BoardItem> boards =
                locationIds.isEmpty()
                        ? boardItemRepository.findByLocationText(cleanCode)
                        : boardItemRepository.findByLocationOrLocationIds(cleanCode, locationIds);
        List<LocationScanResponse.LocationBoardItem> boardItems = new ArrayList<>();
        BigDecimal totalBoardQty = BigDecimal.ZERO;

        for (var b : boards) {
            int qty = b.getQuantity() != null ? b.getQuantity() : 0;
            if (qty > 0) {
                totalBoardQty = totalBoardQty.add(BigDecimal.valueOf(qty));
            }
            boardItems.add(new LocationScanResponse.LocationBoardItem(
                    b.getId(),
                    b.getQrCode(),
                    b.getName(),
                    b.getModel(),
                    b.getRepairBrand(),
                    b.getCategory(),
                    b.getStatus() != null ? b.getStatus().name() : "AVAILABLE",
                    qty,
                    b.getMinQuantity() != null ? b.getMinQuantity() : 0,
                    b.getLocation()
            ));
        }

        BigDecimal totalQty = totalPartQty.add(totalBoardQty);
        int totalTypes = partItems.size() + boardItems.size();

        return new LocationScanResponse(
                location.getId(),
                location.getCode(),
                location.getName(),
                location.getDescription(),
                location.getQrCode() != null ? location.getQrCode() : location.getCode(),
                location.getIsFull(),
                partItems,
                boardItems,
                totalTypes,
                totalQty
        );
    }

    // ── 2. Lấy Linh Kiện Out Kho ─────────────────────────────────────
    @Transactional
    public PartCheckoutHistoryResponse checkoutPart(UUID partId, PartCheckoutRequest request, UUID userId) {
        Part part = partRepository.findByIdAndIsDeletedFalse(partId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy linh kiện: " + partId));

        StoreLocation location = storeLocationRepository.findByIdAndIsDeletedFalse(request.storeLocationId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy vị trí kho: " + request.storeLocationId()));

        PartLot lot;
        if (request.partLotId() != null) {
            lot = partLotRepository.findByIdAndIsDeletedFalse(request.partLotId())
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lô linh kiện: " + request.partLotId()));
        } else {
            lot = partLotRepository.findByPartIdAndStoreLocationIdAndIsDeletedFalse(part.getId(), location.getId())
                    .orElseThrow(() -> new BusinessException("Không tìm thấy linh kiện tại vị trí kho " + location.getCode()));
        }

        if (lot.getAmount().compareTo(request.quantity()) < 0) {
            throw new BusinessException("Số lượng tồn tại vị trí " + location.getCode() + " không đủ (Hiện có: "
                    + lot.getAmount() + ", Yêu cầu: " + request.quantity() + ")");
        }

        // Trừ kho
        lot.setAmount(lot.getAmount().subtract(request.quantity()));
        lot.setUpdatedBy(userId);
        partLotRepository.save(lot);

        // Tạo bản ghi lượt lấy
        PartCheckout checkout = PartCheckout.builder()
                .partId(part.getId())
                .partLotId(lot.getId())
                .storeLocationId(location.getId())
                .takenBy(userId)
                .quantity(request.quantity())
                .returnedQuantity(BigDecimal.ZERO)
                .takenAt(Instant.now())
                .purpose(StringUtils.hasText(request.purpose()) ? request.purpose().trim() : "Lấy linh kiện sử dụng")
                .repairOrderId(request.repairOrderId())
                .checkoutStatus(CheckoutStatus.OPEN)
                .notes(request.notes())
                .build();
        checkout.setCreatedBy(userId);
        PartCheckout savedCheckout = partCheckoutRepository.save(checkout);

        // Ghi StockMovement Append-Only chuẩn hóa kiến trúc
        String movementCode = "PX-" + java.time.LocalDate.now().toString().replace("-", "") + "-" + UUID.randomUUID().toString().substring(0, 6).toUpperCase();
        stockMovementRepository.save(StockMovement.builder()
                .movementCode(movementCode)
                .partId(part.getId())
                .partLotId(lot.getId())
                .storageLocationId(location.getId())
                .fromLocationId(location.getId())
                .movementType(StockMovementType.USE_FOR_REPAIR)
                .quantity(request.quantity())
                .amount(request.quantity().negate())
                .remainingToReturn(request.quantity())
                .movementStatus("OPEN")
                .refType("PART_CHECKOUT")
                .refId(savedCheckout.getId())
                .purpose(checkout.getPurpose())
                .note("Lấy linh kiện out kho: " + checkout.getPurpose() + (StringUtils.hasText(request.notes()) ? " (" + request.notes() + ")" : ""))
                .build());

        log.info("Nhân viên {} đã lấy {} linh kiện {} tại vị trí {}", userId, request.quantity(), part.getIpn(), location.getCode());

        checkAndNotifyLowStock(part);

        return toCheckoutHistoryResponse(savedCheckout);
    }

    // ── 3. Trả Linh Kiện Về Kho ─────────────────────────────────────
    @Transactional
    public PartCheckoutHistoryResponse returnPart(UUID checkoutId, PartReturnRequest request, UUID userId) {
        PartCheckout checkout = partCheckoutRepository.findByIdAndIsDeletedFalse(checkoutId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bản ghi lấy linh kiện: " + checkoutId));

        if (!checkout.isActive()) {
            throw new BusinessException("Lượt lấy linh kiện này đã hoàn thành hoặc không ở trạng thái mở");
        }

        BigDecimal remainingQty = checkout.getQuantity().subtract(checkout.getReturnedQuantity() != null ? checkout.getReturnedQuantity() : BigDecimal.ZERO);
        if (request.returnedQuantity().compareTo(remainingQty) > 0) {
            throw new BusinessException("Số lượng trả (" + request.returnedQuantity() + ") vượt quá số lượng còn mượn (" + remainingQty + ")");
        }

        PartLot lot = partLotRepository.findByIdAndIsDeletedFalse(checkout.getPartLotId())
                .orElseGet(() -> partLotRepository.findByPartIdAndStoreLocationIdAndIsDeletedFalse(checkout.getPartId(), checkout.getStoreLocationId())
                        .orElse(null));

        PartCondition condition = request.conditionStatus() != null ? request.conditionStatus() : PartCondition.GOOD;

        // Nếu trả bình thường (GOOD) -> Cộng lại kho
        if (lot != null && PartCondition.GOOD.equals(condition)) {
            lot.setAmount(lot.getAmount().add(request.returnedQuantity()));
            lot.setUpdatedBy(userId);
            partLotRepository.save(lot);
        }

        BigDecimal updatedReturnedQty = (checkout.getReturnedQuantity() != null ? checkout.getReturnedQuantity() : BigDecimal.ZERO).add(request.returnedQuantity());
        checkout.setReturnedQuantity(updatedReturnedQty);
        checkout.setReturnedAt(Instant.now());
        checkout.setConditionStatus(condition);
        if (StringUtils.hasText(request.notes())) {
            checkout.setNotes((checkout.getNotes() != null ? checkout.getNotes() + " | " : "") + "Trả: " + request.notes());
        }

        if (updatedReturnedQty.compareTo(checkout.getQuantity()) >= 0) {
            checkout.setCheckoutStatus(PartCondition.DAMAGED.equals(condition) ? CheckoutStatus.DAMAGED : CheckoutStatus.RETURNED);
        }

        checkout.setUpdatedBy(userId);
        PartCheckout savedCheckout = partCheckoutRepository.save(checkout);

        // Ghi StockMovement Append-Only chuẩn hóa
        String returnCode = "PN-" + java.time.LocalDate.now().toString().replace("-", "") + "-" + UUID.randomUUID().toString().substring(0, 6).toUpperCase();
        StockMovementType returnType = PartCondition.DAMAGED.equals(condition) ? StockMovementType.RETURN_SCRAP : StockMovementType.RETURN;
        stockMovementRepository.save(StockMovement.builder()
                .movementCode(returnCode)
                .partId(checkout.getPartId())
                .partLotId(checkout.getPartLotId())
                .storageLocationId(checkout.getStoreLocationId())
                .toLocationId(checkout.getStoreLocationId())
                .movementType(returnType)
                .quantity(request.returnedQuantity())
                .amount(request.returnedQuantity())
                .movementStatus("COMPLETED")
                .refType("PART_RETURN")
                .refId(savedCheckout.getId())
                .purpose("Trả linh kiện về kho")
                .note("Trả linh kiện (" + condition + "): " + (StringUtils.hasText(request.notes()) ? request.notes() : "Đổi trả kho"))
                .build());

        log.info("Nhân viên {} đã trả {} linh kiện (Trạng thái: {}) cho lượt checkout {}", userId, request.returnedQuantity(), condition, checkoutId);
        return toCheckoutHistoryResponse(savedCheckout);
    }

    // ── 4. Xem Lịch Sử Lấy/Trả Linh Kiện ───────────────────────────
    @Transactional(readOnly = true)
    public Page<PartCheckoutHistoryResponse> getCheckoutHistory(UUID partId, UUID locationId, UUID userId, CheckoutStatus status, Pageable pageable) {
        return partCheckoutRepository.searchHistory(partId, locationId, userId, status, pageable)
                .map(this::toCheckoutHistoryResponse);
    }

    @Transactional(readOnly = true)
    public List<CategoryInfo> getCategories() {
        return jdbcTemplate.query(
                "SELECT id, name, description FROM categories WHERE is_deleted = false ORDER BY name",
                (rs, rowNum) -> new CategoryInfo(
                        UUID.fromString(rs.getString("id")),
                        rs.getString("name"),
                        rs.getString("description")
                )
        );
    }

    @Transactional
    public LocationInfo createLocation(CreateStoreLocationRequest request, UUID userId) {
        String code = request.code().trim();
        String qrCode = StringUtils.hasText(request.qrCode()) ? request.qrCode().trim() : code;

        Optional<StoreLocation> existingByCode = storeLocationRepository.findByCodeIgnoreCase(code);
        if (existingByCode.isPresent()) {
            StoreLocation existing = existingByCode.get();
            if (!Boolean.TRUE.equals(existing.getIsDeleted())) {
                throw new BusinessException("Mã vị trí kho '" + code + "' đã tồn tại trong hệ thống");
            }
            // Khôi phục và tái sử dụng bản ghi đã bị xóa mềm trước đó
            existing.setCode(code);
            existing.setName(request.name().trim());
            existing.setDescription(StringUtils.hasText(request.description()) ? request.description().trim() : null);
            existing.setQrCode(qrCode);
            existing.setIsDeleted(false);
            existing.setDeletedAt(null);
            existing.setUpdatedBy(userId);
            StoreLocation saved = storeLocationRepository.save(existing);
            log.info("Khôi phục vị trí kho: id={}, code={}, qrCode={}, name={}, by={}", saved.getId(), saved.getCode(), saved.getQrCode(), saved.getName(), userId);
            return new LocationInfo(
                    saved.getId(),
                    saved.getCode(),
                    saved.getName(),
                    saved.getDescription(),
                    saved.getQrCode(),
                    0,
                    BigDecimal.ZERO
            );
        }

        // Kiểm tra trùng qrCode nếu khác code
        Optional<StoreLocation> existingByQr = storeLocationRepository.findByQrCodeIgnoreCase(qrCode);
        if (existingByQr.isPresent() && !Boolean.TRUE.equals(existingByQr.get().getIsDeleted())) {
            throw new BusinessException("Mã QR '" + qrCode + "' đã được gán cho vị trí " + existingByQr.get().getCode());
        }

        StoreLocation location = StoreLocation.builder()
                .code(code)
                .name(request.name().trim())
                .description(StringUtils.hasText(request.description()) ? request.description().trim() : null)
                .qrCode(qrCode)
                .isFull(false)
                .onlySinglePart(false)
                .build();
        location.setIsDeleted(false);
        location.setCreatedBy(userId);
        location.setUpdatedBy(userId);
        StoreLocation saved = storeLocationRepository.save(location);
        log.info("Tạo vị trí kho mới: code={}, qrCode={}, name={}, by={}", saved.getCode(), saved.getQrCode(), saved.getName(), userId);
        return new LocationInfo(
                saved.getId(),
                saved.getCode(),
                saved.getName(),
                saved.getDescription(),
                saved.getQrCode(),
                0,
                BigDecimal.ZERO
        );
    }

    @Transactional
    public LocationInfo updateLocation(UUID id, UpdateStoreLocationRequest request, UUID userId) {
        StoreLocation location = storeLocationRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy vị trí kho: " + id));

        if (StringUtils.hasText(request.code())) {
            String newCode = request.code().trim();
            if (!newCode.equalsIgnoreCase(location.getCode())) {
                storeLocationRepository.findByCodeIgnoreCase(newCode).ifPresent(existing -> {
                    if (!existing.getId().equals(id)) {
                        if (!Boolean.TRUE.equals(existing.getIsDeleted())) {
                            throw new BusinessException("Mã vị trí kho '" + newCode + "' đã tồn tại trong hệ thống");
                        } else {
                            // Đổi code của bản ghi đã xóa để giải phóng code mới
                            existing.setCode(existing.getCode() + "_DELETED_" + System.currentTimeMillis());
                            storeLocationRepository.save(existing);
                        }
                    }
                });
                location.setCode(newCode);
            }
        }

        if (StringUtils.hasText(request.name())) {
            location.setName(request.name().trim());
        }

        if (request.description() != null) {
            location.setDescription(StringUtils.hasText(request.description()) ? request.description().trim() : null);
        }

        if (request.qrCode() != null) {
            String newQr = StringUtils.hasText(request.qrCode()) ? request.qrCode().trim() : location.getCode();
            storeLocationRepository.findByQrCodeIgnoreCase(newQr).ifPresent(existing -> {
                if (!existing.getId().equals(id) && !Boolean.TRUE.equals(existing.getIsDeleted())) {
                    throw new BusinessException("Mã QR '" + newQr + "' đã được gán cho vị trí " + existing.getCode());
                }
            });
            location.setQrCode(newQr);
        }

        location.setUpdatedBy(userId);
        StoreLocation saved = storeLocationRepository.save(location);
        log.info("Cập nhật vị trí kho: id={}, code={}, name={}, by={}", saved.getId(), saved.getCode(), saved.getName(), userId);

        List<PartLot> lots = partLotRepository.findByStoreLocationIdAndIsDeletedFalse(saved.getId());
        int partTypes = (int) lots.stream()
                .filter(l -> l.getAmount() != null && l.getAmount().compareTo(BigDecimal.ZERO) > 0)
                .map(PartLot::getPartId)
                .distinct()
                .count();
        BigDecimal totalQty = lots.stream()
                .map(l -> l.getAmount() != null ? l.getAmount() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return new LocationInfo(
                saved.getId(),
                saved.getCode(),
                saved.getName(),
                saved.getDescription(),
                saved.getQrCode() != null ? saved.getQrCode() : saved.getCode(),
                partTypes,
                totalQty
        );
    }

    @Transactional
    public void deleteLocation(UUID id, UUID userId) {
        StoreLocation location = storeLocationRepository.findByIdAndIsDeletedFalse(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy vị trí kho: " + id));

        // 1. Kiểm tra xem vị trí có đang chứa lô linh kiện còn tồn kho không
        List<PartLot> lots = partLotRepository.findByStoreLocationIdAndIsDeletedFalse(id);
        long activeLotsCount = lots.stream()
                .filter(l -> l.getAmount() != null && l.getAmount().compareTo(BigDecimal.ZERO) > 0)
                .count();
        BigDecimal totalPartQty = lots.stream()
                .map(l -> l.getAmount() != null ? l.getAmount() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // 2. Kiểm tra xem vị trí có đang chứa bo mạch nào không
        List<com.suachuabientan.system_internal.modules.warehouse.entity.BoardItem> boardsAtLocation =
                boardItemRepository.findByLocationText(location.getCode());
        long activeBoardsCount = boardsAtLocation.stream()
                .filter(b -> !Boolean.TRUE.equals(b.getIsDeleted()) && (b.getQuantity() == null || b.getQuantity() > 0))
                .count();

        if (activeLotsCount > 0 || activeBoardsCount > 0) {
            List<String> reasons = new ArrayList<>();
            if (activeLotsCount > 0) {
                reasons.add("Còn " + activeLotsCount + " loại linh kiện (Tổng tồn kho: " + totalPartQty + ")");
            }
            if (activeBoardsCount > 0) {
                reasons.add("Còn " + activeBoardsCount + " bo mạch đang lưu trữ");
            }
            String detailMsg = String.join(" và ", reasons);
            throw new BusinessException("Không thể xóa vị trí '" + location.getName() + " (" + location.getCode() + ")' vì "
                    + detailMsg + ". Vui lòng chuyển linh kiện/bo mạch sang vị trí khác hoặc xuất kho trước khi xóa!");
        }

        location.setIsDeleted(true);
        location.setUpdatedBy(userId);
        storeLocationRepository.save(location);
        log.info("Xóa vị trí kho thành công: id={}, code={}, by={}", id, location.getCode(), userId);
    }

    @Transactional(readOnly = true)
    public List<LocationInfo> getLocations() {
        return storeLocationRepository.findAll().stream()
                .filter(loc -> !Boolean.TRUE.equals(loc.getIsDeleted()))
                .map(loc -> {
                    List<PartLot> lots = partLotRepository.findByStoreLocationIdAndIsDeletedFalse(loc.getId());
                    int partTypes = (int) lots.stream()
                            .filter(l -> l.getAmount() != null && l.getAmount().compareTo(BigDecimal.ZERO) > 0)
                            .map(PartLot::getPartId)
                            .distinct()
                            .count();
                    BigDecimal totalQty = lots.stream()
                            .map(l -> l.getAmount() != null ? l.getAmount() : BigDecimal.ZERO)
                            .reduce(BigDecimal.ZERO, BigDecimal::add);

                    return new LocationInfo(
                            loc.getId(),
                            loc.getCode(),
                            loc.getName(),
                            loc.getDescription(),
                            loc.getQrCode() != null ? loc.getQrCode() : loc.getCode(),
                            partTypes,
                            totalQty
                    );
                })
                .toList();
    }

    // Mappers & Helpers
    private PartResponse toResponse(Part part) {
        List<PartLot> lots = partLotRepository.findByPartIdAndIsDeletedFalse(part.getId());
        List<PartLotResponse> lotResponses = lots.stream()
                .map(this::toLotResponse)
                .toList();

        BigDecimal totalQuantity = lotResponses.stream()
                .map(PartLotResponse::amount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return new PartResponse(
                part.getId(),
                part.getIpn(),
                part.getName(),
                part.getDescription(),
                part.getMinAmount(),
                part.getMaxAmount(),
                part.getPurchasePrice(),
                part.getSalePrice(),
                part.getParameters(),
                part.getDatasheetUrl(),
                part.getImageUrl(),
                part.getNote(),
                part.getManufacturingStatus(),
                part.getCategoryId(),
                getCategoryName(part.getCategoryId()),
                part.getFootprintId(),
                part.getManufacturerId(),
                part.getMeasurementUnitId(),
                totalQuantity,
                lotResponses,
                part.getCreatedAt()
        );
    }

    private PartLotResponse toLotResponse(PartLot lot) {
        StoreLocation loc = lot.getStoreLocationId() != null
                ? storeLocationRepository.findByIdAndIsDeletedFalse(lot.getStoreLocationId()).orElse(null)
                : null;
        return new PartLotResponse(
                lot.getId(),
                lot.getStoreLocationId(),
                loc != null ? loc.getCode() : "DEFAULT",
                loc != null ? loc.getName() : "Mặc định",
                lot.getAmount(),
                lot.getLotCode()
        );
    }

    private PartCheckoutHistoryResponse toCheckoutHistoryResponse(PartCheckout checkout) {
        Part part = partRepository.findByIdAndIsDeletedFalse(checkout.getPartId()).orElse(null);
        StoreLocation location = checkout.getStoreLocationId() != null
                ? storeLocationRepository.findByIdAndIsDeletedFalse(checkout.getStoreLocationId()).orElse(null)
                : null;
        UserEntity takenByUser = checkout.getTakenBy() != null
                ? userRepository.findByIdAndIsDeletedFalse(checkout.getTakenBy()).orElse(null)
                : null;

        return new PartCheckoutHistoryResponse(
                checkout.getId(),
                checkout.getPartId(),
                part != null ? part.getIpn() : null,
                part != null ? part.getName() : null,
                checkout.getStoreLocationId(),
                location != null ? location.getCode() : null,
                location != null ? location.getName() : null,
                checkout.getTakenBy(),
                takenByUser != null ? takenByUser.getFullName() : "Không xác định",
                takenByUser != null ? takenByUser.getEmployeeCode() : null,
                checkout.getQuantity(),
                checkout.getReturnedQuantity(),
                checkout.getTakenAt(),
                checkout.getReturnedAt(),
                checkout.getPurpose(),
                checkout.getRepairOrderId(),
                checkout.getConditionStatus(),
                checkout.getCheckoutStatus(),
                checkout.getNotes()
        );
    }

    private String getCategoryName(UUID categoryId) {
        if (categoryId == null) return null;
        try {
            return jdbcTemplate.queryForObject(
                    "SELECT name FROM categories WHERE id = ? AND is_deleted = false",
                    String.class,
                    categoryId
            );
        } catch (Exception e) {
            return "Uncategorized";
        }
    }

    private UUID getOrCreateCategory(String categoryName) {
        try {
            return jdbcTemplate.queryForObject(
                    "SELECT id FROM categories WHERE LOWER(name) = LOWER(?) AND is_deleted = false LIMIT 1",
                    UUID.class,
                    categoryName
            );
        } catch (Exception e) {
            UUID newCategoryId = UUID.randomUUID();
            jdbcTemplate.update(
                    "INSERT INTO categories (id, name, description, not_selectable, is_deleted) VALUES (?, ?, ?, ?, ?)",
                    newCategoryId, categoryName, "Tự động tạo từ kho linh kiện", false, false
            );
            return newCategoryId;
        }
    }

    private UUID getOrCreateUncategorizedCategory() {
        return getOrCreateCategory("Uncategorized");
    }

    public void checkAndNotifyLowStock(Part part) {
        if (part == null || part.getMinAmount() == null || part.getMinAmount().compareTo(BigDecimal.ZERO) <= 0) {
            return;
        }

        List<PartLot> lots = partLotRepository.findByPartIdAndIsDeletedFalse(part.getId());
        BigDecimal totalQty = lots.stream()
                .map(l -> l.getAmount() != null ? l.getAmount() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        if (totalQty.compareTo(part.getMinAmount()) <= 0) {
            String unit = StringUtils.hasText(part.getMeasurementUnit()) ? part.getMeasurementUnit() : "cái";
            String title;
            String body;

            if (totalQty.compareTo(BigDecimal.ZERO) <= 0) {
                title = "Hết hàng: " + part.getName();
                body = "Linh kiện " + part.getIpn() + " (" + part.getName() + ") đã HẾT HÀNG trong kho (Tồn kho: 0 " + unit + ", Định mức Min: " + part.getMinAmount() + " " + unit + "). Vui lòng nhập thêm.";
            } else {
                title = "Cảnh báo tồn kho tối thiểu: " + part.getName();
                body = "Linh kiện " + part.getIpn() + " (" + part.getName() + ") chỉ còn " + totalQty + " " + unit + ", đã đạt/dưới mức tối thiểu (" + part.getMinAmount() + " " + unit + ").";
            }

            try {
                notificationService.sendToRoles(
                        WAREHOUSE_ALERT_ROLES,
                        NotificationType.PART_LOW_STOCK_ALERT,
                        title,
                        body,
                        "PART",
                        part.getId().toString(),
                        true
                );
            } catch (Exception e) {
                log.error("Lỗi khi gửi thông báo cảnh báo tồn kho tối thiểu cho partId={}: {}", part.getId(), e.getMessage());
            }
        }
    }

    @Transactional(readOnly = true)
    public int scanAndNotifyAllLowStockParts() {
        List<Part> parts = partRepository.findByIsDeletedFalse();
        int alertCount = 0;
        for (Part part : parts) {
            if (part.getMinAmount() != null && part.getMinAmount().compareTo(BigDecimal.ZERO) > 0) {
                List<PartLot> lots = partLotRepository.findByPartIdAndIsDeletedFalse(part.getId());
                BigDecimal totalQty = lots.stream()
                        .map(l -> l.getAmount() != null ? l.getAmount() : BigDecimal.ZERO)
                        .reduce(BigDecimal.ZERO, BigDecimal::add);

                if (totalQty.compareTo(part.getMinAmount()) <= 0) {
                    checkAndNotifyLowStock(part);
                    alertCount++;
                }
            }
        }
        return alertCount;
    }
}
