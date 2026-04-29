# Kiến trúc tổng thể — Hệ thống quản lý nội bộ công ty điện tử

## 1. Tổng quan hệ thống

Hệ thống quản lý nội bộ được xây dựng cho công ty điện tử quy mô nhỏ, phục vụ các nghiệp vụ: quản lý kho bo mạch, tiếp nhận đơn sửa chữa, chấm công khuôn mặt, nhắn tin nội bộ và quản lý nhân viên.

**Mô hình triển khai:** Modular Monolith (Spring Boot) — dễ phát triển, dễ bảo trì, có thể tách microservices sau khi hệ thống lớn hơn.

**Thiết bị sử dụng:**
- Tablet kho — quản lý bo mạch, quét QR
- Tablet giao nhận — tiếp nhận đơn sửa chữa, upload ảnh
- Tablet phòng quản lý — giám sát, sắp xếp ưu tiên
- Mobile nhân viên — chấm công, nhắn tin, xem lịch trình
- Windows Admin — quản lý toàn bộ hệ thống

---

## 2. Kiến trúc phân lớp

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Frontend                        │
│   Mobile │ Tablet (Kho, Giao nhận, QL) │ Windows (Admin)   │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTPS / WebSocket (STOMP)
┌───────────────────────▼─────────────────────────────────────┐
│                  API Gateway + JWT Auth                     │
│              Spring Security — Role-based access            │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│              Spring Boot Backend (Modular Monolith)         │
│                                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │
│  │   Auth   │ │Warehouse │ │  Repair  │ │  Attendance  │  │
│  │ Module   │ │  Module  │ │  Module  │ │    Module    │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │
│  │Messaging │ │Notifica- │ │Employee  │ │    Media     │  │
│  │  Module  │ │  tion    │ │  Module  │ │    Module    │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘  │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                       Data Layer                            │
│  PostgreSQL │ Redis (Cache) │ MinIO (File) │ Firebase (FCM) │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Chi tiết các module Backend

### 3.1 Auth Module
Xử lý xác thực, phân quyền và luồng duyệt tài khoản nhân viên.

**Chức năng:**
- Đăng ký tài khoản (status: `PENDING`) — chờ Admin/Manager duyệt
- Đăng nhập trả về JWT Access Token (15 phút) + Refresh Token (7 ngày)
- Phân quyền theo role: `ADMIN`, `MANAGER`, `TECHNICIAN`, `RECEPTIONIST`, `WAREHOUSE_STAFF`
- Duyệt / từ chối tài khoản nhân viên mới

**Endpoints chính:**
```
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/refresh
GET    /api/auth/pending-users         [ADMIN, MANAGER]
PUT    /api/auth/users/{id}/approve    [ADMIN, MANAGER]
PUT    /api/auth/users/{id}/reject     [ADMIN, MANAGER]
```

---

### 3.2 Warehouse Module
Quản lý kho bo mạch, tạo mã QR, theo dõi lấy/trả.

**Chức năng:**
- CRUD danh mục bo mạch, sinh mã QR tự động
- Nhân viên quét QR để lấy bo mạch — ghi nhận ai lấy, lúc nào
- Hiển thị badge QR: tên người đang sử dụng + thời gian lấy
- Cảnh báo tự động nếu bo mạch chưa trả sau X ngày (configurable)
- Lịch sử lấy/trả đầy đủ

**Endpoints chính:**
```
GET    /api/boards                     [ALL]
POST   /api/boards                     [ADMIN, WAREHOUSE_STAFF]
GET    /api/boards/{qrCode}/scan       [ALL] — thông tin khi quét QR
POST   /api/boards/{id}/checkout       [TECHNICIAN, WAREHOUSE_STAFF]
PUT    /api/boards/{id}/return         [TECHNICIAN, WAREHOUSE_STAFF]
GET    /api/boards/{id}/history        [ADMIN, MANAGER, WAREHOUSE_STAFF]
```

---

### 3.3 Repair Order Module
Tiếp nhận, phân công, theo dõi vòng đời đơn sửa chữa.

**Chức năng:**
- Tạo đơn sửa chữa kèm upload ảnh thiết bị hỏng
- Notification tự động gửi Manager khi có đơn mới
- Manager phân công kỹ thuật viên, điều chỉnh độ ưu tiên (kéo thả)
- Ghi audit log mỗi khi trạng thái thay đổi (repair_timeline)
- Theo dõi lịch trình: nhận đơn → đang sửa → hoàn thành → giao hàng

**Vòng đời đơn:**
```
PENDING → IN_PROGRESS → COMPLETED → DELIVERED
```

**Endpoints chính:**
```
POST   /api/repairs                          [RECEPTIONIST, ADMIN]
GET    /api/repairs                          [MANAGER, ADMIN]
GET    /api/repairs/{id}                     [ALL có liên quan]
PUT    /api/repairs/{id}/assign              [MANAGER, ADMIN]
PUT    /api/repairs/{id}/status              [TECHNICIAN, MANAGER, ADMIN]
PUT    /api/repairs/reorder                  [MANAGER, ADMIN] — cập nhật priority hàng loạt
POST   /api/repairs/{id}/images              [RECEPTIONIST, TECHNICIAN]
GET    /api/repairs/{id}/timeline            [ALL có liên quan]
```

---

### 3.4 Attendance Module
Chấm công bằng nhận diện khuôn mặt, ghi nhận giờ vào/ra.

**Chức năng:**
- Flutter app chụp ảnh khuôn mặt → gửi lên backend
- Backend gọi Face Recognition Service (Python FastAPI + DeepFace)
- Ghi nhận check-in / check-out với confidence score
- Lịch sử chấm công theo ngày, tuần, tháng
- Báo cáo đi muộn / về sớm so với work_schedule

**Luồng xử lý:**
```
Flutter Camera → Base64 Image → POST /api/attendance/checkin
→ Spring Boot → Python Face Service → match/no-match
→ Ghi AttendanceRecord → Response + Notification
```

**Endpoints chính:**
```
POST   /api/attendance/checkin         [ALL]
POST   /api/attendance/checkout        [ALL]
GET    /api/attendance/today           [ALL] — xem của bản thân
GET    /api/attendance/report          [MANAGER, ADMIN]
POST   /api/employees/{id}/face        [ADMIN] — đăng ký khuôn mặt
GET    /api/schedules                  [ALL]
POST   /api/schedules                  [MANAGER, ADMIN]
```

---

### 3.5 Messaging Module
Nhắn tin nội bộ real-time qua WebSocket (STOMP).

**Chức năng:**
- Chat 1-1 và nhóm
- Gửi text và file/ảnh
- Seen indicator, đánh dấu đã đọc
- Lịch sử tin nhắn phân trang

**WebSocket topics:**
```
/topic/conversation/{id}          — nhận tin nhắn mới trong cuộc trò chuyện
/user/{userId}/queue/messages     — notification tin nhắn cá nhân
/user/{userId}/queue/typing       — trạng thái đang gõ
```

**REST Endpoints:**
```
GET    /api/conversations                    [ALL]
POST   /api/conversations                    [ALL]
GET    /api/conversations/{id}/messages      [thành viên]
POST   /api/conversations/{id}/members       [creator, ADMIN]
```

---

### 3.6 Notification Module
Gửi thông báo đa kênh: in-app, push (FCM), WebSocket.

**Trigger events:**
| Sự kiện | Người nhận | Kênh |
|---|---|---|
| Đơn sửa chữa mới | Manager | Push + In-app |
| Được phân công đơn | Kỹ thuật viên | Push + In-app |
| Đơn thay đổi priority | Kỹ thuật viên được assign | In-app |
| Bo mạch chưa trả quá hạn | Manager + người giữ | Push |
| Tài khoản mới chờ duyệt | Admin, Manager | In-app |
| Đơn hoàn thành | Receptionist | Push + In-app |

**Endpoints:**
```
GET    /api/notifications              [ALL] — danh sách của bản thân
PUT    /api/notifications/{id}/read    [ALL]
PUT    /api/notifications/read-all     [ALL]
```

---

### 3.7 Employee Module
Quản lý hồ sơ nhân viên, lịch trình làm việc.

**Chức năng:**
- CRUD thông tin nhân viên
- Xem lịch trình theo ngày (nhận đơn, sửa chữa, hoàn thành)
- Báo cáo hiệu suất (số đơn hoàn thành, thời gian trung bình)

**Endpoints:**
```
GET    /api/employees                  [MANAGER, ADMIN]
GET    /api/employees/{id}             [ALL — bản thân hoặc quản lý]
PUT    /api/employees/{id}             [ADMIN]
GET    /api/employees/{id}/schedule    [ALL]
GET    /api/employees/{id}/stats       [MANAGER, ADMIN]
```

---

### 3.8 Media Module
Xử lý upload, lưu trữ và phục vụ file.

**Chức năng:**
- Upload ảnh đơn sửa chữa, avatar nhân viên, ảnh chấm công
- Lưu trữ MinIO (self-hosted) hoặc AWS S3
- Trả về presigned URL để Flutter hiển thị trực tiếp

**Endpoints:**
```
POST   /api/media/upload               [ALL có quyền]
DELETE /api/media/{key}                [ADMIN]
```

---

## 4. Frontend Flutter — Cấu trúc

```
lib/
├── core/
│   ├── api/
│   │   ├── dio_client.dart          # Dio + interceptor tự động refresh token
│   │   ├── api_endpoints.dart       # Tất cả URL constants
│   │   └── error_handler.dart
│   ├── auth/
│   │   ├── token_storage.dart       # FlutterSecureStorage
│   │   └── auth_state.dart
│   ├── websocket/
│   │   └── stomp_service.dart       # Kết nối WebSocket + subscribe topics
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── app_colors.dart
│   └── utils/
│       ├── qr_utils.dart
│       ├── image_utils.dart
│       └── date_utils.dart
│
├── features/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── pending_approval_screen.dart
│   ├── warehouse/
│   │   ├── warehouse_screen.dart
│   │   ├── qr_scan_screen.dart
│   │   └── board_detail_screen.dart
│   ├── repair/
│   │   ├── repair_list_screen.dart
│   │   ├── repair_detail_screen.dart
│   │   ├── create_repair_screen.dart  # Upload ảnh + mô tả
│   │   └── priority_board_screen.dart # Kéo thả ưu tiên (Manager)
│   ├── attendance/
│   │   ├── checkin_screen.dart        # Camera + face recognition
│   │   └── attendance_history_screen.dart
│   ├── messaging/
│   │   ├── conversation_list_screen.dart
│   │   └── chat_screen.dart
│   ├── notification/
│   │   └── notification_screen.dart
│   ├── employee/
│   │   ├── employee_list_screen.dart
│   │   ├── employee_detail_screen.dart
│   │   └── schedule_screen.dart
│   └── dashboard/
│       ├── admin_dashboard.dart
│       ├── manager_dashboard.dart
│       └── staff_dashboard.dart
│
└── shared/
    ├── widgets/
    │   ├── app_bar_widget.dart
    │   ├── loading_widget.dart
    │   ├── error_widget.dart
    │   └── notification_badge.dart
    └── models/                        # Data models / DTOs
```

**Layout responsive:**
```dart
// Phân biệt layout theo thiết bị
Widget build(BuildContext context) {
  final isTabletOrDesktop = MediaQuery.of(context).size.width > 768;
  return isTabletOrDesktop
      ? SideNavLayout(child: content)   // Tablet + Windows
      : BottomNavLayout(child: content); // Mobile
}
```

---

## 5. Phân quyền theo Role

| Chức năng | ADMIN | MANAGER | TECHNICIAN | RECEPTIONIST | WAREHOUSE |
|---|:---:|:---:|:---:|:---:|:---:|
| Duyệt tài khoản | ✅ | ✅ | | | |
| Quản lý nhân viên | ✅ | Xem | | | |
| Kho bo mạch — xem | ✅ | ✅ | ✅ | | ✅ |
| Kho bo mạch — lấy/trả | ✅ | | ✅ | | ✅ |
| Tạo đơn sửa chữa | ✅ | ✅ | | ✅ | |
| Phân công + ưu tiên đơn | ✅ | ✅ | | | |
| Cập nhật trạng thái đơn | ✅ | ✅ | ✅ | | |
| Chấm công | ✅ | ✅ | ✅ | ✅ | ✅ |
| Nhắn tin nội bộ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Báo cáo tổng hợp | ✅ | ✅ | | | |
| Đăng ký khuôn mặt NV | ✅ | | | | |

---

## 6. Stack công nghệ

### Backend
| Thành phần | Công nghệ | Ghi chú |
|---|---|---|
| Framework | Spring Boot 3.x | Java 17+ |
| Security | Spring Security + JWT | jjwt library |
| ORM | JPA / Hibernate | |
| Migration | Flyway | |
| WebSocket | Spring WebSocket + STOMP | |
| Validation | Jakarta Bean Validation | |
| Docs | SpringDoc OpenAPI (Swagger) | |

### Frontend
| Thành phần | Thư viện | Ghi chú |
|---|---|---|
| Framework | Flutter 3.x | Dart |
| State Management | Riverpod | Hoặc BLoC |
| HTTP Client | Dio | Kèm interceptor |
| WebSocket | stomp_dart_client | |
| QR Scanner | mobile_scanner | |
| Face Detection | google_ml_kit | Offline, nhanh |
| Image Picker | image_picker | |
| Secure Storage | flutter_secure_storage | Lưu JWT |
| Navigation | go_router | |
| Push Notification | firebase_messaging | |

### Infrastructure
| Thành phần | Công nghệ | Ghi chú |
|---|---|---|
| Database | PostgreSQL 15 | Main DB |
| Cache | Redis 7 | Session, QR cache |
| File Storage | MinIO | Self-hosted S3 |
| Push | Firebase FCM | Android + iOS |
| Face AI | Python FastAPI + DeepFace | Service riêng |
| Container | Docker + Docker Compose | |
| Reverse Proxy | Nginx | |

---

## 7. Cấu trúc dự án Backend

```
backend/
├── src/main/java/com/company/ims/
│   ├── ImsApplication.java
│   ├── config/
│   │   ├── SecurityConfig.java
│   │   ├── WebSocketConfig.java
│   │   ├── CorsConfig.java
│   │   ├── MinioConfig.java
│   │   └── SwaggerConfig.java
│   ├── common/
│   │   ├── entity/BaseEntity.java     # id, createdAt, updatedAt
│   │   ├── exception/GlobalExceptionHandler.java
│   │   ├── response/ApiResponse.java  # Chuẩn hoá response
│   │   └── util/JwtUtil.java
│   ├── module/
│   │   ├── auth/
│   │   │   ├── AuthController.java
│   │   │   ├── AuthService.java
│   │   │   └── dto/
│   │   ├── warehouse/
│   │   │   ├── BoardController.java
│   │   │   ├── BoardService.java
│   │   │   ├── entity/BoardItem.java
│   │   │   ├── entity/BoardCheckout.java
│   │   │   └── dto/
│   │   ├── repair/
│   │   │   ├── RepairController.java
│   │   │   ├── RepairService.java
│   │   │   ├── entity/RepairOrder.java
│   │   │   ├── entity/RepairImage.java
│   │   │   ├── entity/RepairTimeline.java
│   │   │   └── dto/
│   │   ├── attendance/
│   │   │   ├── AttendanceController.java
│   │   │   ├── AttendanceService.java
│   │   │   ├── FaceRecognitionClient.java  # Gọi Python service
│   │   │   └── entity/AttendanceRecord.java
│   │   ├── messaging/
│   │   │   ├── MessageController.java
│   │   │   ├── ChatWebSocketController.java
│   │   │   └── entity/
│   │   ├── notification/
│   │   │   ├── NotificationService.java
│   │   │   └── entity/Notification.java
│   │   ├── employee/
│   │   │   ├── EmployeeController.java
│   │   │   └── entity/WorkSchedule.java
│   │   └── media/
│   │       ├── MediaController.java
│   │       └── MinioService.java
│   └── security/
│       ├── JwtAuthFilter.java
│       └── UserDetailsServiceImpl.java
│
├── src/main/resources/
│   ├── application.yml
│   ├── application-dev.yml
│   ├── application-prod.yml
│   └── db/migration/
│       ├── V1__init_users.sql
│       ├── V2__init_warehouse.sql
│       ├── V3__init_repair.sql
│       ├── V4__init_attendance.sql
│       └── V5__init_messaging.sql
│
└── docker-compose.yml
```

---

## 8. Docker Compose

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ims_db
      POSTGRES_USER: ims_user
      POSTGRES_PASSWORD: ims_pass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data

  face-service:
    build: ./face-service
    ports:
      - "8001:8001"

  backend:
    build: ./backend
    ports:
      - "8080:8080"
    depends_on:
      - postgres
      - redis
      - minio
      - face-service
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/ims_db

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - backend

volumes:
  postgres_data:
  minio_data:
```

---

## 9. Thứ tự phát triển đề xuất

| Sprint | Nội dung | Kết quả |
|---|---|---|
| Sprint 1 | Setup project, Docker, Auth, User management | Login, register, role-based access |
| Sprint 2 | Repair Order (core nghiệp vụ) | Tạo đơn, assign, timeline |
| Sprint 3 | Warehouse + QR management | Lấy/trả bo mạch, QR badge |
| Sprint 4 | Messaging + Notification real-time | Chat nội bộ, push notification |
| Sprint 5 | Attendance + Face recognition | Chấm công khuôn mặt |
| Sprint 6 | Dashboard, báo cáo, responsive UI | Hoàn thiện sản phẩm |
