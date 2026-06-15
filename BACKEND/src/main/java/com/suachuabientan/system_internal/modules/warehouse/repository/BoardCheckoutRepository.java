package com.suachuabientan.system_internal.modules.warehouse.repository;

import com.suachuabientan.system_internal.modules.warehouse.entity.BoardCheckout;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface BoardCheckoutRepository extends JpaRepository<BoardCheckout, UUID> {

    /**
     * Tìm checkout active chưa trả của một bo mạch
     * Dùng khi quét qr biết ai giữ
     *
     */
    @Query("""
                SELECT c FROM BoardCheckout c
                WHERE c.boardItemId = :boardItemId
                AND c.checkoutStatus = com.suachuabientan.system_internal.modules.warehouse.enums.CheckoutStatus.OPEN
                AND c.returnedAt is NULL 
                AND c.isDeleted = false
            """)
    Optional<BoardCheckout> findActiveByBoardItemId(@Param("boardItemId") UUID boardItemId);

    /**
     * Lịch sử lấy trả của một bo mạch mới nhất trước
     *
     */
    Page<BoardCheckout> findByBoardItemIdAndIsDeletedFalseOrderByTakenAtDesc(UUID boardItemId, Pageable pageable);

    /**
     * Tất cả bo mạch được mượn bởi một nhân viên - phân trang
     */
    Page<BoardCheckout> findByTakenByAndIsDeletedFalseOrderByTakenAtDesc(UUID takenAt, Pageable pageable);
}
