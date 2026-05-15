package com.suachuabientan.system_internal.modules.warehouse.repository;

import com.suachuabientan.system_internal.modules.warehouse.entity.BoardItem;
import com.suachuabientan.system_internal.modules.warehouse.enums.BoardStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface BoardItemRepository extends JpaRepository<BoardItem, UUID> {
    Optional<BoardItem> findByQrCodeAndIsDeletedFalse(String qrCode);

    Optional<BoardItem> findByIdAndIsDeletedFalse(UUID id);


    boolean existsByQrCodeAndIsDeletedFalse(String qrCode);

    Page<BoardItem> findByIsDeletedFalse(Pageable pageable);

    Page<BoardItem> findByStatusAndIsDeletedFalse(Pageable pageable, BoardStatus status);

    /**
     * Tìm kiếm theo tên, category, location
     */
    @Query(value = """
            SELECT * FROM board_items b
            WHERE b.is_deleted = false
              AND (
                  CAST(:keyword AS TEXT) IS NULL
                  OR LOWER(b.name)     LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                  OR LOWER(b.category) LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                  OR LOWER(b.location) LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
              )
              AND (
                  CAST(:status AS TEXT) IS NULL
                  OR b.status = CAST(:status AS TEXT)
              )
            ORDER BY b.created_at DESC
            """,
            countQuery = """
            SELECT COUNT(*) FROM board_items b
            WHERE b.is_deleted = false
              AND (
                  CAST(:keyword AS TEXT) IS NULL
                  OR LOWER(b.name)     LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                  OR LOWER(b.category) LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                  OR LOWER(b.location) LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
              )
              AND (
                  CAST(:status AS TEXT) IS NULL
                  OR b.status = CAST(:status AS TEXT)
              )
            """,
            nativeQuery = true)
    Page<BoardItem> searchBoards(
            @Param("keyword") String keyword,
            @Param("status") String status,
            Pageable pageable);

    /**
     * Đếm theo status - dùng cho thống kê dashboard
     *
     */
    @Query("""
                SELECT COUNT(b) FROM BoardItem b
                WHERE b.isDeleted = false AND b.status = :status
            """)
    long countByStatus(@Param("status") BoardStatus status);
}
