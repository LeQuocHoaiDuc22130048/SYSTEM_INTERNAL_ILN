package com.suachuabientan.system_internal.modules.warehouse.dto.response;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record LocationScanResponse(
        UUID locationId,
        String code,
        String name,
        String description,
        String qrCode,
        Boolean isFull,
        List<LocationPartItem> parts,
        List<LocationBoardItem> boards,
        int totalPartTypes,
        BigDecimal totalQuantity,
        int partTypesCount,
        BigDecimal partQuantity,
        int boardTypesCount,
        BigDecimal boardQuantity
) {
    public LocationScanResponse(
            UUID locationId,
            String code,
            String name,
            String description,
            String qrCode,
            Boolean isFull,
            List<LocationPartItem> parts,
            List<LocationBoardItem> boards,
            int totalPartTypes,
            BigDecimal totalQuantity
    ) {
        this(
                locationId,
                code,
                name,
                description,
                qrCode,
                isFull,
                parts,
                boards,
                totalPartTypes,
                totalQuantity,
                parts != null ? parts.size() : 0,
                parts != null ? parts.stream().map(p -> p.amount() != null ? p.amount() : BigDecimal.ZERO).reduce(BigDecimal.ZERO, BigDecimal::add) : BigDecimal.ZERO,
                boards != null ? boards.size() : 0,
                boards != null ? boards.stream().map(b -> BigDecimal.valueOf(b.quantity() != null ? b.quantity() : 0)).reduce(BigDecimal.ZERO, BigDecimal::add) : BigDecimal.ZERO
        );
    }

    public LocationScanResponse(
            UUID locationId,
            String code,
            String name,
            String description,
            String qrCode,
            Boolean isFull,
            List<LocationPartItem> parts,
            int totalPartTypes,
            BigDecimal totalQuantity
    ) {
        this(locationId, code, name, description, qrCode, isFull, parts, List.of(), totalPartTypes, totalQuantity);
    }

    public record LocationPartItem(
            UUID partId,
            UUID partLotId,
            String ipn,
            String name,
            String description,
            BigDecimal amount,
            String unit,
            String categoryName,
            String imageUrl,
            String condition
    ) {}

    public record LocationBoardItem(
            UUID boardId,
            String qrCode,
            String name,
            String model,
            String repairBrand,
            String category,
            String status,
            Integer quantity,
            Integer minQuantity,
            String location
    ) {}
}
