package com.suachuabientan.system_internal.modules.repair.repository;

import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.enums.RepairStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RepairOrderRepository extends JpaRepository<RepairOrder, UUID> {
    Optional<RepairOrder> findByIdAndIsDeletedFalse(UUID id);

    Optional<RepairOrder> findByOrderCodeAndIsDeletedFalse(String orderCode);

    boolean existsByOrderCodeAndIsDeletedFalse(String orderCode);

    boolean existsByOrderCode(String orderCode);

    /**
     * Danh sách đơn theo status - sort theo priority ASC
     */
    Page<RepairOrder> findByStatusAndIsDeletedFalseOrderByPriorityAsc(RepairStatus status, Pageable pageable);

    /**
     * Danh sách đơn được assign cho một kỹ thuật viên
     */
    Page<RepairOrder> findByAssignedToAndIsDeletedFalseOrderByPriorityAsc(UUID assignedTo, Pageable pageable);

    /**
     * Tìm kiếm đơn, - filter theo status, keyword (tên thiết bị, mã đơn, tên khách hàng)
     * Native query để tránh lỗi Hibernate type interface và Null parameter
     */
    @Query(value = """
            SELECT DISTINCT r.* FROM repair_orders r
            LEFT JOIN repair_order_assignees roa ON roa.order_id = r.id
            LEFT JOIN repair_devices rd ON rd.order_id = r.id
            WHERE r.is_deleted = false
              AND (CAST(:status AS TEXT) IS NULL OR r.status = CAST(:status AS TEXT))
              AND (CAST(:assignedTo AS TEXT) IS NULL OR roa.technician_id = CAST(:assignedTo AS uuid) OR r.assigned_to = CAST(:assignedTo AS uuid))
              AND (CAST(:staffId AS TEXT) IS NULL OR roa.technician_id = CAST(:staffId AS uuid) OR r.assigned_to = CAST(:staffId AS uuid) OR r.received_by = CAST(:staffId AS uuid))
              AND (
                  CAST(:keyword AS TEXT) IS NULL
                  OR LOWER(r.device_name)    LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                  OR LOWER(r.customer_name)  LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                  OR LOWER(r.customer_phone) LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                  OR LOWER(r.order_code)     LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                  OR LOWER(r.serial_number)  LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                  OR LOWER(rd.serial_number) LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
              )
            ORDER BY r.priority ASC, r.received_at DESC
            """,
            countQuery = """
                    SELECT COUNT(DISTINCT r.id) FROM repair_orders r
                    LEFT JOIN repair_order_assignees roa ON roa.order_id = r.id
                    LEFT JOIN repair_devices rd ON rd.order_id = r.id
                    WHERE r.is_deleted = false
                      AND (CAST(:status AS TEXT) IS NULL OR r.status = CAST(:status AS TEXT))
                      AND (CAST(:assignedTo AS TEXT) IS NULL OR roa.technician_id = CAST(:assignedTo AS uuid) OR r.assigned_to = CAST(:assignedTo AS uuid))
                      AND (CAST(:staffId AS TEXT) IS NULL OR roa.technician_id = CAST(:staffId AS uuid) OR r.assigned_to = CAST(:staffId AS uuid) OR r.received_by = CAST(:staffId AS uuid))
                      AND (
                          CAST(:keyword AS TEXT) IS NULL
                          OR LOWER(r.device_name)    LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                          OR LOWER(r.customer_name)  LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                          OR LOWER(r.customer_phone) LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                          OR LOWER(r.order_code)     LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                          OR LOWER(r.serial_number)  LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                          OR LOWER(rd.serial_number) LIKE LOWER(CONCAT('%', CAST(:keyword AS TEXT), '%'))
                      )
                    """,
            nativeQuery = true)
    Page<RepairOrder> searchOrders(
            @Param("keyword") String keyword,
            @Param("status") String status,
            @Param("assignedTo") String assignedTo,
            @Param("staffId") String staffId,
            Pageable pageable);


    /**
     * Đếm đơn theo status — dùng cho dashboard.
     */
    @Query("SELECT COUNT(r) FROM RepairOrder r WHERE r.isDeleted = false AND r.status = :status")
    long countByStatus(@Param("status") RepairStatus status);

    /**
     * Cập nhật priority hàng loạt khi Manager kéo thả.
     * Gọi trong vòng lặp bên Service — mỗi lệnh update 1 đơn.
     */
    @Modifying
    @Query("UPDATE RepairOrder r SET r.priority = :priority WHERE r.id = :id AND r.isDeleted = false")
    void updatePriority(@Param("id") UUID id, @Param("priority") int priority);

    /**
     * Đơn active của một kỹ thuật viên — dùng để kiểm tra workload.
     */
    @Query("""
            SELECT DISTINCT r FROM RepairOrder r LEFT JOIN r.assignees a
            WHERE (r.assignedTo = :userId OR a = :userId)
              AND r.isDeleted = false
              AND r.status IN ('PENDING', 'IN_PROGRESS')
            ORDER BY r.priority ASC
            """)
    List<RepairOrder> findActiveByAssignedTo(@Param("userId") UUID userId);
}
