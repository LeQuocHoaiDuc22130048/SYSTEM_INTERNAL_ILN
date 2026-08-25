package com.suachuabientan.system_internal.modules.warehouse.service;

import com.suachuabientan.system_internal.common.exception.ResourceNotFoundException;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.AdjustStockRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.CheckoutRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.request.PartCheckoutRequest;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.CategoryInfo;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.UnifiedWarehouseItemResponse;
import com.suachuabientan.system_internal.modules.warehouse.dto.response.UnifiedWarehouseSummaryResponse;
import com.suachuabientan.system_internal.modules.warehouse.entity.BoardItem;
import com.suachuabientan.system_internal.modules.warehouse.entity.Part;
import com.suachuabientan.system_internal.modules.warehouse.entity.PartLot;
import com.suachuabientan.system_internal.modules.warehouse.entity.StoreLocation;
import com.suachuabientan.system_internal.modules.warehouse.enums.BoardStatus;
import com.suachuabientan.system_internal.modules.warehouse.repository.BoardCheckoutRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.BoardItemRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartLotRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.StoreLocationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class UnifiedWarehouseService {

    private final BoardItemRepository boardItemRepository;
    private final PartRepository partRepository;
    private final PartLotRepository partLotRepository;
    private final StoreLocationRepository storeLocationRepository;
    private final BoardCheckoutRepository boardCheckoutRepository;
    private final UserRepository userRepository;
    private final WarehouseService warehouseService;
    private final PartService partService;

    @Transactional(readOnly = true)
    public Page<UnifiedWarehouseItemResponse> getInventory(
            String type,
            String keyword,
            String status,
            String location,
            Pageable pageable
    ) {
        List<UnifiedWarehouseItemResponse> allItems = new ArrayList<>();
        String kw = (keyword != null && !keyword.trim().isEmpty()) ? keyword.trim().toLowerCase() : null;
        String reqType = (type != null && !type.trim().isEmpty()) ? type.trim().toUpperCase() : "ALL";
        String reqStatus = (status != null && !status.trim().isEmpty()) ? status.trim().toUpperCase() : "ALL";
        String reqLoc = (location != null && !location.trim().isEmpty()) ? location.trim().toLowerCase() : null;

        Map<UUID, String> locationNameMap = storeLocationRepository.findAll().stream()
                .collect(Collectors.toMap(StoreLocation::getId, StoreLocation::getName, (a, b) -> a));
        Map<UUID, String> locationCodeMap = storeLocationRepository.findAll().stream()
                .collect(Collectors.toMap(StoreLocation::getId, StoreLocation::getCode, (a, b) -> a));
        
        Map<UUID, String> categoryMap = new HashMap<>();
        try {
            for (CategoryInfo c : partService.getCategories()) {
                if (c.id() != null && c.name() != null) {
                    categoryMap.put(c.id(), c.name());
                }
            }
        } catch (Exception e) {
            log.warn("Không thể tải danh mục: {}", e.getMessage());
        }

        if ("ALL".equals(reqType) || "BOARD".equals(reqType)) {
            List<BoardItem> boards = boardItemRepository.findAll().stream()
                    .filter(b -> !Boolean.TRUE.equals(b.getIsDeleted()))
                    .toList();

            for (BoardItem b : boards) {
                String loc = b.getLocation() != null ? b.getLocation() : "";
                if (b.getCurrentLocationId() != null && locationCodeMap.containsKey(b.getCurrentLocationId())) {
                    loc = locationCodeMap.get(b.getCurrentLocationId());
                }

                String bStatus = mapBoardStatus(b.getStatus());
                BigDecimal qty = BigDecimal.valueOf(b.getQuantity() != null ? b.getQuantity() : 0);
                BigDecimal minQty = BigDecimal.valueOf(b.getMinQuantity() != null ? b.getMinQuantity() : 0);

                if (qty.compareTo(BigDecimal.ZERO) <= 0) {
                    bStatus = "OUT_OF_STOCK";
                } else if (minQty.compareTo(BigDecimal.ZERO) > 0 && qty.compareTo(minQty) < 0) {
                    bStatus = "LOW_STOCK";
                }

                if (kw != null) {
                    boolean match = (b.getName() != null && b.getName().toLowerCase().contains(kw)) ||
                            (b.getQrCode() != null && b.getQrCode().toLowerCase().contains(kw)) ||
                            (b.getModel() != null && b.getModel().toLowerCase().contains(kw)) ||
                            (b.getCategory() != null && b.getCategory().toLowerCase().contains(kw)) ||
                            loc.toLowerCase().contains(kw);
                    if (!match) continue;
                }

                if (!"ALL".equals(reqStatus) && !bStatus.equalsIgnoreCase(reqStatus)) {
                    continue;
                }

                if (reqLoc != null && !loc.toLowerCase().contains(reqLoc)) {
                    continue;
                }

                allItems.add(new UnifiedWarehouseItemResponse(
                        b.getId(),
                        "BOARD",
                        b.getName(),
                        b.getQrCode(),
                        b.getQrCode(),
                        b.getCategory() != null ? b.getCategory() : "Bo mạch",
                        loc,
                        b.getCurrentLocationId(),
                        qty,
                        minQty,
                        "Cái",
                        bStatus,
                        b.getModel(),
                        b.getDescription(),
                        null,
                        null,
                        b.getUpdatedAt() != null ? b.getUpdatedAt() : Instant.now(),
                        List.of()
                ));
            }
        }

        if ("ALL".equals(reqType) || "PART".equals(reqType)) {
            List<Part> parts = partRepository.findAll().stream()
                    .filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
                    .toList();

            List<PartLot> allLots = partLotRepository.findAll().stream()
                    .filter(l -> !Boolean.TRUE.equals(l.getIsDeleted()))
                    .toList();

            Map<UUID, List<PartLot>> lotsByPartId = allLots.stream()
                    .collect(Collectors.groupingBy(PartLot::getPartId));

            for (Part p : parts) {
                List<PartLot> partLots = lotsByPartId.getOrDefault(p.getId(), List.of());
                BigDecimal totalPartQty = partLots.stream()
                        .map(l -> l.getAmount() != null ? l.getAmount() : BigDecimal.ZERO)
                        .reduce(BigDecimal.ZERO, BigDecimal::add);

                BigDecimal minQty = p.getMinAmount() != null ? p.getMinAmount() : BigDecimal.ZERO;
                String catName = p.getCategoryId() != null ? categoryMap.getOrDefault(p.getCategoryId(), "Linh kiện") : "Linh kiện";

                List<UnifiedWarehouseItemResponse.PartLotInfo> lotInfos = new ArrayList<>();
                StringBuilder locBuilder = new StringBuilder();

                for (PartLot l : partLots) {
                    if (l.getAmount() == null || l.getAmount().compareTo(BigDecimal.ZERO) <= 0) continue;
                    String lCode = locationCodeMap.getOrDefault(l.getStoreLocationId(), "KHO");
                    String lName = locationNameMap.getOrDefault(l.getStoreLocationId(), lCode);
                    lotInfos.add(new UnifiedWarehouseItemResponse.PartLotInfo(
                            l.getId(),
                            l.getStoreLocationId(),
                            lCode,
                            lName,
                            l.getAmount(),
                            l.getCondition()
                    ));
                    if (locBuilder.length() > 0) locBuilder.append(", ");
                    locBuilder.append(lCode).append(" (").append(l.getAmount().stripTrailingZeros().toPlainString()).append(")");
                }

                String mainLoc = locBuilder.length() > 0 ? locBuilder.toString() : "Chưa xếp vị trí";
                UUID mainLocId = !partLots.isEmpty() ? partLots.get(0).getStoreLocationId() : null;

                String pStatus = "AVAILABLE";
                if (totalPartQty.compareTo(BigDecimal.ZERO) <= 0) {
                    pStatus = "OUT_OF_STOCK";
                } else if (minQty.compareTo(BigDecimal.ZERO) > 0 && totalPartQty.compareTo(minQty) < 0) {
                    pStatus = "LOW_STOCK";
                }

                if (kw != null) {
                    boolean match = (p.getName() != null && p.getName().toLowerCase().contains(kw)) ||
                            (p.getIpn() != null && p.getIpn().toLowerCase().contains(kw)) ||
                            catName.toLowerCase().contains(kw) ||
                            (p.getDescription() != null && p.getDescription().toLowerCase().contains(kw)) ||
                            mainLoc.toLowerCase().contains(kw);
                    if (!match) continue;
                }

                if (!"ALL".equals(reqStatus) && !pStatus.equalsIgnoreCase(reqStatus)) {
                    continue;
                }

                if (reqLoc != null && !mainLoc.toLowerCase().contains(reqLoc)) {
                    continue;
                }

                allItems.add(new UnifiedWarehouseItemResponse(
                        p.getId(),
                        "PART",
                        p.getName(),
                        p.getIpn(),
                        p.getIpn(),
                        catName,
                        mainLoc,
                        mainLocId,
                        totalPartQty,
                        minQty,
                        p.getMeasurementUnit() != null ? p.getMeasurementUnit() : "Cái",
                        pStatus,
                        p.getSeries(),
                        p.getDescription(),
                        p.getImageUrl(),
                        null,
                        p.getUpdatedAt() != null ? p.getUpdatedAt() : Instant.now(),
                        lotInfos
                ));
            }
        }

        allItems.sort((a, b) -> {
            if (b.updatedAt() != null && a.updatedAt() != null) {
                return b.updatedAt().compareTo(a.updatedAt());
            }
            return a.name().compareToIgnoreCase(b.name());
        });

        int start = (int) pageable.getOffset();
        if (start >= allItems.size()) {
            return new PageImpl<>(List.of(), pageable, allItems.size());
        }
        int end = Math.min(start + pageable.getPageSize(), allItems.size());
        return new PageImpl<>(allItems.subList(start, end), pageable, allItems.size());
    }

    @Transactional(readOnly = true)
    public UnifiedWarehouseSummaryResponse getSummary() {
        List<BoardItem> boards = boardItemRepository.findAll().stream()
                .filter(b -> !Boolean.TRUE.equals(b.getIsDeleted()))
                .toList();

        List<Part> parts = partRepository.findAll().stream()
                .filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
                .toList();

        List<PartLot> lots = partLotRepository.findAll().stream()
                .filter(l -> !Boolean.TRUE.equals(l.getIsDeleted()))
                .toList();

        Map<UUID, BigDecimal> partQtyMap = new HashMap<>();
        for (PartLot l : lots) {
            if (l.getPartId() != null && l.getAmount() != null) {
                partQtyMap.put(l.getPartId(), partQtyMap.getOrDefault(l.getPartId(), BigDecimal.ZERO).add(l.getAmount()));
            }
        }

        BigDecimal totalQty = BigDecimal.ZERO;
        long lowStockCount = 0;
        long outOfStockCount = 0;

        for (BoardItem b : boards) {
            BigDecimal qty = BigDecimal.valueOf(b.getQuantity() != null ? b.getQuantity() : 0);
            BigDecimal minQty = BigDecimal.valueOf(b.getMinQuantity() != null ? b.getMinQuantity() : 0);
            totalQty = totalQty.add(qty);
            if (qty.compareTo(BigDecimal.ZERO) <= 0) {
                outOfStockCount++;
            } else if (minQty.compareTo(BigDecimal.ZERO) > 0 && qty.compareTo(minQty) < 0) {
                lowStockCount++;
            }
        }

        for (Part p : parts) {
            BigDecimal qty = partQtyMap.getOrDefault(p.getId(), BigDecimal.ZERO);
            BigDecimal minQty = p.getMinAmount() != null ? p.getMinAmount() : BigDecimal.ZERO;
            totalQty = totalQty.add(qty);
            if (qty.compareTo(BigDecimal.ZERO) <= 0) {
                outOfStockCount++;
            } else if (minQty.compareTo(BigDecimal.ZERO) > 0 && qty.compareTo(minQty) < 0) {
                lowStockCount++;
            }
        }

        long totalItems = boards.size() + parts.size();
        return new UnifiedWarehouseSummaryResponse(
                totalItems,
                totalQty,
                boards.size(),
                parts.size(),
                lowStockCount,
                outOfStockCount
        );
    }

    @Transactional
    public Object checkoutUnifiedItem(UUID id, String itemType, Map<String, Object> payload, UUID userId) {
        if ("BOARD".equalsIgnoreCase(itemType)) {
            int qty = payload.get("quantity") instanceof Number n ? n.intValue() : 1;
            String repairBrand = payload.get("repairBrand") != null ? payload.get("repairBrand").toString() : null;
            UUID repairOrderId = null;
            if (payload.get("repairOrderId") != null) {
                try {
                    repairOrderId = UUID.fromString(payload.get("repairOrderId").toString());
                } catch (Exception ignored) {}
            }
            String note = payload.get("note") != null ? payload.get("note").toString() : null;
            CheckoutRequest req = new CheckoutRequest(repairOrderId, note, qty, repairBrand);
            return warehouseService.checkout(id, req, userId);
        } else {
            BigDecimal qty = payload.get("quantity") instanceof Number n ? BigDecimal.valueOf(n.doubleValue()) : BigDecimal.ONE;
            UUID storeLocId = null;
            UUID lotId = null;
            if (payload.get("storeLocationId") != null) {
                try {
                    storeLocId = UUID.fromString(payload.get("storeLocationId").toString());
                } catch (Exception ignored) {}
            }
            if (payload.get("partLotId") != null) {
                try {
                    lotId = UUID.fromString(payload.get("partLotId").toString());
                } catch (Exception ignored) {}
            }
            if (storeLocId == null) {
                List<PartLot> lots = partLotRepository.findByPartIdAndIsDeletedFalse(id);
                if (!lots.isEmpty()) {
                    storeLocId = lots.get(0).getStoreLocationId();
                    if (lotId == null) lotId = lots.get(0).getId();
                }
            }

            String purpose = payload.get("purpose") != null ? payload.get("purpose").toString() : "Lấy linh kiện sửa chữa";
            UUID repairOrderId = null;
            if (payload.get("repairOrderId") != null) {
                try {
                    repairOrderId = UUID.fromString(payload.get("repairOrderId").toString());
                } catch (Exception ignored) {}
            }
            String notes = payload.get("note") != null ? payload.get("note").toString() : null;

            PartCheckoutRequest req = new PartCheckoutRequest(
                    storeLocId,
                    lotId,
                    qty,
                    purpose,
                    repairOrderId,
                    notes
            );
            return partService.checkoutPart(id, req, userId);
        }
    }

    @Transactional
    public void adjustUnifiedItemStock(UUID id, String itemType, AdjustStockRequest req, UUID userId) {
        if ("BOARD".equalsIgnoreCase(itemType)) {
            BoardItem b = boardItemRepository.findByIdAndIsDeletedFalse(id)
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bo mạch với ID: " + id));
            int newQty = req.amount() != null ? req.amount().intValue() : 1;
            b.setQuantity(newQty);
            if (req.storeLocationCode() != null && !req.storeLocationCode().trim().isEmpty()) {
                b.setLocation(req.storeLocationCode().trim());
            }
            if (newQty <= 0) {
                b.setStatus(BoardStatus.CHECKED_OUT);
            } else if (b.getStatus() == BoardStatus.CHECKED_OUT) {
                b.setStatus(BoardStatus.AVAILABLE);
            }
            boardItemRepository.save(b);
        } else {
            partService.adjustStock(id, req, userId);
        }
    }

    @Transactional
    public void deleteUnifiedItem(UUID id, String itemType, UUID userId) {
        if ("BOARD".equalsIgnoreCase(itemType)) {
            warehouseService.delete(id, userId);
        } else {
            partService.delete(id, userId);
        }
    }

    private String mapBoardStatus(BoardStatus status) {
        if (status == null) return "AVAILABLE";
        return switch (status) {
            case AVAILABLE, TESTED_OK -> "AVAILABLE";
            case CHECKED_OUT, IN_REPAIR -> "CHECKED_OUT";
            case MAINTENANCE, UNTESTED, DAMAGED, LOST, ARCHIVED, RETIRED -> "MAINTENANCE";
            default -> "AVAILABLE";
        };
    }
}
