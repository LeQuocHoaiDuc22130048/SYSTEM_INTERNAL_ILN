package com.suachuabientan.system_internal.modules.notification.repository;

import com.suachuabientan.system_internal.modules.notification.entity.Notification;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface NotificationRepository extends JpaRepository<Notification, UUID> {
    /**
     * Danh sách thông báo của user — mới nhất trước.
     */
    @Query(value = """
            SELECT * FROM notifications n
            WHERE n.recipient_id = :recipientId
              AND n.is_deleted = false
            ORDER BY n.created_at DESC
            """,
            countQuery = """
            SELECT COUNT(*) FROM notifications n
            WHERE n.recipient_id = :recipientId
              AND n.is_deleted = false
            """,
            nativeQuery = true)
    Page<Notification> findByRecipient(
            @Param("recipientId") UUID recipientId,
            Pageable pageable);

    /**
     * Đếm thông báo chưa đọc — hiển thị badge.
     */
    @Query("""
            SELECT COUNT(n) FROM Notification n
            WHERE n.recipientId = :recipientId
              AND n.isRead = false
              AND n.isDeleted = false
            """)
    long countUnread(@Param("recipientId") UUID recipientId);

    /**
     * Đánh dấu một thông báo đã đọc.
     */
    @Modifying
    @Query("""
            UPDATE Notification n
            SET n.isRead = true
            WHERE n.id = :id
              AND n.recipientId = :recipientId
              AND n.isDeleted = false
            """)
    void markAsRead(@Param("id") UUID id, @Param("recipientId") UUID recipientId);

    /**
     * Đánh dấu tất cả thông báo của user đã đọc.
     */
    @Modifying
    @Query("""
            UPDATE Notification n
            SET n.isRead = true
            WHERE n.recipientId = :recipientId
              AND n.isRead = false
              AND n.isDeleted = false
            """)
    void markAllAsRead(@Param("recipientId") UUID recipientId);

    Optional<Notification> findByIdAndRecipientIdAndIsDeletedFalse(UUID id, UUID recipientId);
}
