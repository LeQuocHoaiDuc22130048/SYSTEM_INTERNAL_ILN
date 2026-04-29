# Database Design — Hệ thống quản lý nội bộ công ty điện tử

**Database:** PostgreSQL 15  
**Migration tool:** Flyway  
**Quy ước đặt tên:** snake_case, bảng dạng số nhiều, FK dạng `{table_singular}_id`

---

## 1. Tổng quan các bảng

| Nhóm | Bảng | Mô tả |
|---|---|---|
| Auth & Users | `users` | Tài khoản nhân viên |
| Auth & Users | `user_registration_requests` | Lịch sử duyệt tài khoản |
| Attendance | `attendance_records` | Bản ghi chấm công |
| Attendance | `work_schedules` | Lịch làm việc |
| Warehouse | `board_items` | Danh mục bo mạch |
| Warehouse | `board_checkouts` | Lịch sử lấy/trả bo mạch |
| Repair | `repair_orders` | Đơn sửa chữa |
| Repair | `repair_images` | Ảnh đính kèm đơn |
| Repair | `repair_timeline` | Audit log vòng đời đơn |
| Messaging | `conversations` | Cuộc trò chuyện |
| Messaging | `conversation_members` | Thành viên cuộc trò chuyện |
| Messaging | `messages` | Tin nhắn |
| Messaging | `message_reads` | Trạng thái đã đọc |
| Notification | `notifications` | Thông báo in-app |

---

## 2. Nhóm Auth & Users

### 2.1 Bảng `users`

Bảng trung tâm của toàn hệ thống. Mọi bảng khác đều FK về đây.

```sql
CREATE TABLE users (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username         VARCHAR(50)  NOT NULL UNIQUE,
    full_name        VARCHAR(100) NOT NULL,
    email            VARCHAR(150) NOT NULL UNIQUE,
    phone            VARCHAR(20),
    password_hash    VARCHAR(255) NOT NULL,

    -- Phân quyền
    role             VARCHAR(30)  NOT NULL
                     CHECK (role IN ('ADMIN','MANAGER','TECHNICIAN',
                                     'RECEPTIONIST','WAREHOUSE_STAFF')),
    department       VARCHAR(100),

    -- Trạng thái tài khoản
    status           VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                     CHECK (status IN ('PENDING','ACTIVE','INACTIVE','REJECTED')),
    approved_by      UUID REFERENCES users(id),
    approved_at      TIMESTAMP,

    -- Chấm công & thông báo
    face_encoding    TEXT,            -- JSON vector từ DeepFace/ML Kit
    device_token     VARCHAR(255),    -- Firebase FCM token
    avatar_url       VARCHAR(500),

    -- Audit
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_role     ON users(role);
CREATE INDEX idx_users_status   ON users(status);
CREATE INDEX idx_users_username ON users(username);
```

**Ghi chú:**
- `face_encoding` lưu dạng JSON array float — vector đặc trưng khuôn mặt, không lưu ảnh gốc.
- `device_token` cập nhật mỗi lần user login từ thiết bị mới.
- `approved_by` là self-reference FK — ai duyệt tài khoản người đó.

---

### 2.2 Bảng `user_registration_requests`

Audit log đầy đủ lịch sử duyệt/từ chối tài khoản.

```sql
CREATE TABLE user_registration_requests (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES users(id),
    action         VARCHAR(20) NOT NULL
                   CHECK (action IN ('APPROVE','REJECT')),
    reviewed_by    UUID NOT NULL REFERENCES users(id),
    note           TEXT,
    reviewed_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reg_requests_user ON user_registration_requests(user_id);
```

---

## 3. Nhóm Attendance

### 3.1 Bảng `work_schedules`

Lịch làm việc theo ngày của từng nhân viên.

```sql
CREATE TABLE work_schedules (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    work_date      DATE NOT NULL,
    shift_start    TIME NOT NULL,
    shift_end      TIME NOT NULL,
    note           TEXT,
    created_by     UUID REFERENCES users(id),
    created_at     TIMESTAMP NOT NULL DEFAULT NOW(),

    UNIQUE (employee_id, work_date)
);

CREATE INDEX idx_schedules_employee_date ON work_schedules(employee_id, work_date);
```

---

### 3.2 Bảng `attendance_records`

Bản ghi chấm công — mỗi lần check-in hoặc check-out tạo một dòng riêng.

```sql
CREATE TABLE attendance_records (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id       UUID NOT NULL REFERENCES users(id),
    type              VARCHAR(10) NOT NULL CHECK (type IN ('IN','OUT')),
    check_time        TIMESTAMP NOT NULL DEFAULT NOW(),
    face_image_path   VARCHAR(500),    -- Đường dẫn ảnh lưu trên MinIO
    confidence_score  DECIMAL(5,4),    -- 0.0000 → 1.0000
    device_id         VARCHAR(100),    -- ID tablet chấm công
    is_valid          BOOLEAN NOT NULL DEFAULT TRUE,  -- FALSE nếu admin huỷ
    note              TEXT             -- Ghi chú nếu chấm tay (override)
);

CREATE INDEX idx_attendance_employee    ON attendance_records(employee_id);
CREATE INDEX idx_attendance_check_time  ON attendance_records(check_time);
CREATE INDEX idx_attendance_emp_date    ON attendance_records(employee_id, check_time::DATE);
```

**Ghi chú:**
- Mỗi lần quét khuôn mặt tạo 1 record — không merge IN/OUT vào cùng một dòng.
- `confidence_score` ngưỡng chấp nhận khuyến nghị: >= 0.80.

---

## 4. Nhóm Warehouse

### 4.1 Bảng `board_items`

Danh mục bo mạch trong kho.

```sql
CREATE TABLE board_items (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    qr_code      VARCHAR(100) NOT NULL UNIQUE,  -- Sinh tự động: BOARD-{uuid-short}
    name         VARCHAR(200) NOT NULL,
    category     VARCHAR(100),                  -- VD: Mainboard, GPU, RAM, PSU
    description  TEXT,
    status       VARCHAR(30)  NOT NULL DEFAULT 'AVAILABLE'
                 CHECK (status IN ('AVAILABLE','CHECKED_OUT','MAINTENANCE','RETIRED')),
    location     VARCHAR(100),                  -- Vị trí trong kho: VD "Kệ A - Tầng 2"
    created_by   UUID REFERENCES users(id),
    created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_board_items_qr_code ON board_items(qr_code);
CREATE INDEX idx_board_items_status  ON board_items(status);
```

---

### 4.2 Bảng `board_checkouts`

Lịch sử lấy/trả bo mạch. Mỗi lần lấy tạo một dòng, trả thì update `returned_at`.

```sql
CREATE TABLE board_checkouts (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    board_item_id    UUID NOT NULL REFERENCES board_items(id),
    taken_by         UUID NOT NULL REFERENCES users(id),
    repair_order_id  UUID REFERENCES repair_orders(id),  -- Nullable: chưa gắn đơn
    taken_at         TIMESTAMP NOT NULL DEFAULT NOW(),
    returned_at      TIMESTAMP,                          -- NULL = chưa trả
    note             TEXT
);

CREATE INDEX idx_checkouts_board_item   ON board_checkouts(board_item_id);
CREATE INDEX idx_checkouts_taken_by     ON board_checkouts(taken_by);
CREATE INDEX idx_checkouts_repair_order ON board_checkouts(repair_order_id);
CREATE INDEX idx_checkouts_unreturned   ON board_checkouts(board_item_id)
    WHERE returned_at IS NULL;   -- Partial index — tìm nhanh bo mạch đang được mượn
```

**Ghi chú:**
- `repair_order_id` nullable — kỹ thuật viên có thể lấy bo mạch trước khi tạo đơn.
- Khi quét QR, query bảng này với `returned_at IS NULL` để biết bo mạch đang ở đâu.

---

## 5. Nhóm Repair

### 5.1 Bảng `repair_orders`

Bảng trung tâm của module sửa chữa.

```sql
CREATE TABLE repair_orders (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_code       VARCHAR(30) NOT NULL UNIQUE,  -- Sinh tự động: RO-20240115-001
    
    -- Thông tin thiết bị
    device_name      VARCHAR(200) NOT NULL,
    device_type      VARCHAR(100),                 -- VD: Laptop, Desktop, Màn hình
    
    -- Thông tin khách hàng (không quản lý customer riêng)
    customer_name    VARCHAR(100) NOT NULL,
    customer_phone   VARCHAR(20)  NOT NULL,
    
    -- Mô tả vấn đề
    description      TEXT NOT NULL,
    
    -- Vòng đời đơn
    status           VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                     CHECK (status IN ('PENDING','IN_PROGRESS',
                                       'COMPLETED','DELIVERED','CANCELLED')),
    priority         INTEGER NOT NULL DEFAULT 100, -- Số nhỏ = ưu tiên cao hơn
    
    -- Phân công
    received_by      UUID NOT NULL REFERENCES users(id),  -- Người tiếp nhận
    assigned_to      UUID REFERENCES users(id),            -- Kỹ thuật viên (nullable)
    
    -- Thời gian
    received_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    estimated_done   TIMESTAMP,
    started_at       TIMESTAMP,
    completed_at     TIMESTAMP,
    delivered_at     TIMESTAMP,
    
    -- Audit
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_repair_orders_status      ON repair_orders(status);
CREATE INDEX idx_repair_orders_assigned_to ON repair_orders(assigned_to);
CREATE INDEX idx_repair_orders_received_by ON repair_orders(received_by);
CREATE INDEX idx_repair_orders_priority    ON repair_orders(priority, status);
```

**Ghi chú về `priority`:**
- Giá trị số nguyên tự do — Manager kéo thả để sắp xếp thứ tự.
- Khi reorder: backend nhận mảng `[{id, priority}]` và UPDATE hàng loạt trong 1 transaction.
- Khuyến nghị dùng bước nhảy 100 (100, 200, 300...) để dễ chèn giữa mà không cần reorder toàn bộ.

---

### 5.2 Bảng `repair_images`

Ảnh đính kèm đơn sửa chữa (có thể upload nhiều lần ở các giai đoạn khác nhau).

```sql
CREATE TABLE repair_images (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id      UUID NOT NULL REFERENCES repair_orders(id) ON DELETE CASCADE,
    image_url     VARCHAR(500) NOT NULL,    -- Presigned URL hoặc path MinIO
    caption       VARCHAR(255),             -- Mô tả ngắn: "Ảnh trước sửa", "Ảnh sau sửa"
    uploaded_by   UUID NOT NULL REFERENCES users(id),
    uploaded_at   TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_repair_images_order ON repair_images(order_id);
```

---

### 5.3 Bảng `repair_timeline`

Audit log bất biến — chỉ INSERT, không bao giờ UPDATE/DELETE.

```sql
CREATE TABLE repair_timeline (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id      UUID NOT NULL REFERENCES repair_orders(id),
    action        VARCHAR(100) NOT NULL,  -- VD: 'Tiếp nhận đơn', 'Phân công', 'Bắt đầu sửa'
    note          TEXT,
    performed_by  UUID NOT NULL REFERENCES users(id),
    created_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_timeline_order ON repair_timeline(order_id, created_at);
```

**Các action chuẩn:**

| Action | Trigger |
|---|---|
| `Tiếp nhận đơn` | Tạo đơn mới |
| `Phân công kỹ thuật viên` | Manager assign |
| `Thay đổi ưu tiên` | Manager kéo thả priority |
| `Bắt đầu sửa chữa` | Technician cập nhật status → IN_PROGRESS |
| `Upload ảnh` | Thêm ảnh vào đơn |
| `Hoàn thành sửa chữa` | Status → COMPLETED |
| `Giao hàng cho khách` | Status → DELIVERED |
| `Huỷ đơn` | Status → CANCELLED |

---

## 6. Nhóm Messaging

### 6.1 Bảng `conversations`

```sql
CREATE TABLE conversations (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type         VARCHAR(20) NOT NULL CHECK (type IN ('DIRECT','GROUP')),
    name         VARCHAR(100),          -- NULL với DIRECT, bắt buộc với GROUP
    avatar_url   VARCHAR(500),
    created_by   UUID NOT NULL REFERENCES users(id),
    created_at   TIMESTAMP NOT NULL DEFAULT NOW()
);
```

---

### 6.2 Bảng `conversation_members`

```sql
CREATE TABLE conversation_members (
    conversation_id  UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id          UUID NOT NULL REFERENCES users(id),
    joined_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    last_read_at     TIMESTAMP,         -- Dùng để tính số tin chưa đọc
    is_admin         BOOLEAN NOT NULL DEFAULT FALSE,  -- Admin của nhóm

    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX idx_conv_members_user ON conversation_members(user_id);
```

---

### 6.3 Bảng `messages`

```sql
CREATE TABLE messages (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id  UUID NOT NULL REFERENCES conversations(id),
    sender_id        UUID NOT NULL REFERENCES users(id),
    content          TEXT,
    media_url        VARCHAR(500),
    message_type     VARCHAR(20) NOT NULL DEFAULT 'TEXT'
                     CHECK (message_type IN ('TEXT','IMAGE','FILE','SYSTEM')),
    sent_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    is_deleted       BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id, sent_at DESC);
CREATE INDEX idx_messages_sender       ON messages(sender_id);
```

---

### 6.4 Bảng `message_reads`

```sql
CREATE TABLE message_reads (
    message_id  UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id),
    read_at     TIMESTAMP NOT NULL DEFAULT NOW(),

    PRIMARY KEY (message_id, user_id)
);

CREATE INDEX idx_message_reads_user ON message_reads(user_id);
```

---

## 7. Nhóm Notification

### 7.1 Bảng `notifications`

```sql
CREATE TABLE notifications (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id  UUID NOT NULL REFERENCES users(id),
    type          VARCHAR(50) NOT NULL,
                  -- VD: 'NEW_REPAIR_ORDER', 'ASSIGNED', 'PRIORITY_CHANGED',
                  --     'BOARD_OVERDUE', 'ACCOUNT_PENDING', 'ORDER_COMPLETED'
    title         VARCHAR(200) NOT NULL,
    body          TEXT NOT NULL,

    -- Deep link — navigate đến đúng màn hình khi tap notification
    ref_type      VARCHAR(50),     -- VD: 'REPAIR_ORDER', 'BOARD_ITEM', 'USER'
    ref_id        VARCHAR(100),    -- UUID của đối tượng liên quan

    is_read       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_recipient ON notifications(recipient_id, is_read, created_at DESC);
```

**Ghi chú về `ref_type` + `ref_id`:**
Dùng polymorphic reference thay vì nhiều FK riêng. Flutter đọc `ref_type` để quyết định navigate:

```dart
switch (notification.refType) {
  case 'REPAIR_ORDER' => router.push('/repairs/${notification.refId}');
  case 'BOARD_ITEM'   => router.push('/boards/${notification.refId}');
  case 'USER'         => router.push('/employees/${notification.refId}');
}
```

---

## 8. Enum tham chiếu

### User roles
| Value | Mô tả |
|---|---|
| `ADMIN` | Quản trị viên hệ thống — toàn quyền |
| `MANAGER` | Quản lý — duyệt đơn, phân công, báo cáo |
| `TECHNICIAN` | Kỹ thuật viên — lấy bo mạch, cập nhật đơn |
| `RECEPTIONIST` | Lễ tân / tiếp nhận — tạo đơn, upload ảnh |
| `WAREHOUSE_STAFF` | Nhân viên kho — quản lý bo mạch |

### User status
| Value | Mô tả |
|---|---|
| `PENDING` | Vừa đăng ký, chờ duyệt |
| `ACTIVE` | Đã duyệt, đang hoạt động |
| `INACTIVE` | Đã khoá tài khoản |
| `REJECTED` | Bị từ chối |

### Board item status
| Value | Mô tả |
|---|---|
| `AVAILABLE` | Có sẵn trong kho |
| `CHECKED_OUT` | Đang được mượn |
| `MAINTENANCE` | Đang bảo trì kho |
| `RETIRED` | Ngừng sử dụng |

### Repair order status
| Value | Mô tả |
|---|---|
| `PENDING` | Chờ phân công |
| `IN_PROGRESS` | Đang sửa chữa |
| `COMPLETED` | Đã sửa xong, chưa giao |
| `DELIVERED` | Đã giao khách |
| `CANCELLED` | Đã huỷ |

---

## 9. Quan hệ tổng thể (FK Map)

```
users ──────────────────────────────────────────────────────────
  │  approved_by → users.id (self-ref)
  │
  ├── user_registration_requests.user_id
  ├── user_registration_requests.reviewed_by
  │
  ├── work_schedules.employee_id
  ├── work_schedules.created_by
  │
  ├── attendance_records.employee_id
  │
  ├── board_items.created_by
  ├── board_checkouts.taken_by
  │
  ├── repair_orders.received_by
  ├── repair_orders.assigned_to
  ├── repair_images.uploaded_by
  ├── repair_timeline.performed_by
  │
  ├── conversations.created_by
  ├── conversation_members.user_id
  ├── messages.sender_id
  ├── message_reads.user_id
  │
  └── notifications.recipient_id

board_items ──────────────────────────────────────────────────
  └── board_checkouts.board_item_id

repair_orders ────────────────────────────────────────────────
  ├── board_checkouts.repair_order_id  (nullable)
  ├── repair_images.order_id
  └── repair_timeline.order_id

conversations ────────────────────────────────────────────────
  ├── conversation_members.conversation_id
  └── messages.conversation_id

messages ─────────────────────────────────────────────────────
  └── message_reads.message_id
```

---

## 10. Flyway Migration — thứ tự file

```
db/migration/
├── V1__init_users_auth.sql        # users, user_registration_requests
├── V2__init_attendance.sql        # work_schedules, attendance_records
├── V3__init_warehouse.sql         # board_items (board_checkouts sau V4)
├── V4__init_repair.sql            # repair_orders, repair_images, repair_timeline
├── V5__init_warehouse_checkout.sql # board_checkouts (FK repair_orders đã tồn tại)
├── V6__init_messaging.sql         # conversations, members, messages, reads
├── V7__init_notifications.sql     # notifications
└── V8__seed_admin.sql             # Tài khoản admin mặc định
```

**Lý do tách V3 và V5:** `board_checkouts` có FK đến cả `board_items` (V3) và `repair_orders` (V4), nên phải tạo sau khi cả hai bảng đã tồn tại.

---

## 11. Lưu ý hiệu năng

**Indexes quan trọng nhất cần có:**
- `attendance_records(employee_id, check_time::DATE)` — query báo cáo theo ngày
- `repair_orders(status, priority)` — danh sách đơn sắp theo ưu tiên
- `messages(conversation_id, sent_at DESC)` — phân trang tin nhắn
- `notifications(recipient_id, is_read, created_at DESC)` — danh sách thông báo

**Partial index hữu ích:**
```sql
-- Tìm nhanh bo mạch đang được mượn
CREATE INDEX idx_checkouts_active ON board_checkouts(board_item_id)
    WHERE returned_at IS NULL;

-- Đơn chưa hoàn thành
CREATE INDEX idx_repairs_active ON repair_orders(assigned_to, priority)
    WHERE status IN ('PENDING','IN_PROGRESS');

-- Thông báo chưa đọc
CREATE INDEX idx_notifications_unread ON notifications(recipient_id)
    WHERE is_read = FALSE;
```
