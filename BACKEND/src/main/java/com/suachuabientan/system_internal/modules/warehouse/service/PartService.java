package com.suachuabientan.system_internal.modules.warehouse.service;

import com.suachuabientan.system_internal.common.exception.BusinessException;
import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.AdjustStockRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CreatePartRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.UpdatePartRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.CategoryInfo;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.LocationInfo;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.PartLotResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.PartResponse;
import com.suachuabientan.system_internal.modules.warehouse.entity.Part;
import com.suachuabientan.system_internal.modules.warehouse.entity.PartLot;
import com.suachuabientan.system_internal.modules.warehouse.entity.StockMovement;
import com.suachuabientan.system_internal.modules.warehouse.entity.StoreLocation;
import com.suachuabientan.system_internal.modules.warehouse.enums.StockMovementType;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartLotRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.StockMovementRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.StoreLocationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
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
    private final JdbcTemplate jdbcTemplate;

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

        // Check if there is still inventory left
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
        StoreLocation location = storeLocationRepository.findByCodeAndIsDeletedFalse(locCode)
                .orElseGet(() -> {
                    StoreLocation newLoc = StoreLocation.builder()
                            .code(locCode)
                            .name(locCode)
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

        return toResponse(part);
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

    @Transactional(readOnly = true)
    public List<LocationInfo> getLocations() {
        return storeLocationRepository.findAll().stream()
                .filter(loc -> !Boolean.TRUE.equals(loc.getIsDeleted()))
                .map(loc -> new LocationInfo(loc.getId(), loc.getCode(), loc.getName()))
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
}
