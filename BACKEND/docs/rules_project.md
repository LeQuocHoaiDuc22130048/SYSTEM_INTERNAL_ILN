# ⚙️ PROJECT RULES — Hệ Thống Quản Lý Nội Bộ Công Ty Điện Tử

> **Phiên bản:** 1.0 &nbsp;|&nbsp; **Tech Stack:** Spring Boot Backend + Flutter Frontend &nbsp;|&nbsp; **Năm:** 2024  
> 🔒 *Bảo mật nội bộ — Không phân phối ra ngoài*

---

## Mục Lục

1. [Tổng Quan Dự Án](#1-tổng-quan-dự-án)
2. [Quy Tắc Kiến Trúc](#2-quy-tắc-kiến-trúc-architecture-rules)
3. [Quy Tắc Bảo Mật](#3-quy-tắc-bảo-mật-security-rules)
4. [Quy Tắc Theo Mô-đun](#4-quy-tắc-theo-mô-đun-module-rules)
5. [Quy Tắc Viết Code](#5-quy-tắc-viết-code-coding-rules)
6. [Quy Tắc Thiết Kế API](#6-quy-tắc-thiết-kế-api-api-rules)
7. [Quy Tắc Cơ Sở Dữ Liệu](#7-quy-tắc-cơ-sở-dữ-liệu-database-rules)
8. [Quy Tắc Real-time & WebSocket](#8-quy-tắc-real-time--websocket)
9. [Quy Tắc Kiểm Thử](#9-quy-tắc-kiểm-thử-testing-rules)
10. [Quy Tắc Quản Lý Code](#10-quy-tắc-quản-lý-code-git-rules)
11. [Quy Tắc Vận Hành](#11-quy-tắc-vận-hành-operations-rules)
12. [Checklist Trước Khi Release](#12-checklist-trước-khi-release)
13. [Phê Duyệt Tài Liệu](#13-phê-duyệt-tài-liệu)

---

## 1. Tổng Quan Dự Án

### 1.1 Mục Tiêu

Xây dựng hệ thống quản lý nội bộ toàn diện cho công ty điện tử quy mô nhỏ, hỗ trợ các nghiệp vụ: quản lý kho bo mạch, tiếp nhận đơn sửa chữa, chấm công bằng khuôn mặt, nhắn tin nội bộ và quản lý nhân viên.

### 1.2 Tech Stack

| Layer | Công Nghệ | Ghi Chú |
|---|---|---|
| Backend | Spring Boot 3.x + Java 17 | REST API, JWT Auth, WebSocket |
| Frontend | Flutter (Dart) | Mobile, Tablet, Windows |
| Database | PostgreSQL | Primary database |
| Cache | Redis | Session, real-time data |
| Storage | MinIO / AWS S3 | Ảnh đơn sửa chữa, ảnh chấm công |
| Push Notification | Firebase FCM | Thông báo mobile |
| Face Recognition | OpenCV + DeepFace / Face++ API | Chấm công bằng khuôn mặt |
| QR Code | ZXing (Java) / qr_flutter (Flutter) | Quản lý kho bo mạch |
| WebSocket | Spring WebSocket + STOMP | Chat, thông báo real-time |

### 1.3 Thiết Bị Sử Dụng

| Thiết Bị | Khu Vực | Chức Năng Chính |
|---|---|---|
| Tablet Android/iOS | Kho | Quét QR, xuất/nhập bo mạch |
| Tablet Android/iOS | Nơi giao nhận hàng | Tiếp nhận đơn, chụp ảnh, ký xác nhận |
| Tablet Android/iOS | Phòng quản lý | Theo dõi, phê duyệt, điều phối |
| Mobile (Android/iOS) | Nhân viên cá nhân | Chấm công, nhắn tin, xem lịch trình |
| Windows PC/Laptop | Admin Manager | Quản lý toàn hệ thống, báo cáo |

---

## 2. Quy Tắc Kiến Trúc (Architecture Rules)

### 2.1 Kiến Trúc Tổng Thể

> 📌 Toàn bộ dự án **PHẢI** tuân theo **Layered Architecture** phía Backend và **Clean Architecture** phía Flutter.

#### Backend — Spring Boot

- **Controller Layer:** Chỉ nhận request, validate input, gọi Service. KHÔNG chứa business logic.
- **Service Layer:** Chứa toàn bộ business logic. KHÔNG truy cập DB trực tiếp.
- **Repository Layer:** Chỉ chứa query DB thông qua JPA/JPQL/Native Query.
- **DTO Pattern:** KHÔNG expose Entity ra ngoài Controller. Luôn dùng DTO/Response class.
- **Exception Handling:** Tập trung tại `@ControllerAdvice`. KHÔNG try-catch trong Controller.

#### Flutter — Clean Architecture

- **Presentation Layer:** Widgets, Screens, BLoC/Provider/Riverpod.
- **Domain Layer:** Entities, Use Cases, Repository Interfaces.
- **Data Layer:** Repository Implementations, Remote/Local DataSources, Models.
- **Dependency Injection:** Dùng GetIt hoặc Riverpod. KHÔNG khởi tạo dependency trực tiếp trong Widget.

### 2.2 Rules Kiến Trúc

| ID | Rule | Mô Tả |
|---|---|---|
| **AR-01** | Phân Tách Module Rõ Ràng | Mỗi chức năng (kho, đơn hàng, chấm công, chat, nhân viên) phải là một package/module riêng biệt, không phụ thuộc chéo trực tiếp. |
| **AR-02** | API Versioning Bắt Buộc | Tất cả API endpoint phải có prefix `/api/v1/`. Khi thay đổi breaking, nâng lên `/api/v2/` và duy trì v1 tối thiểu 3 tháng. |
| **AR-03** | Stateless Backend | Backend phải stateless hoàn toàn. Session state lưu trong Redis. JWT không lưu server-side. Phù hợp scale horizontal. |
| **AR-04** | Offline-First Flutter | Ứng dụng Flutter phải có cơ chế cache local (Hive/SQLite). Các thao tác đọc cơ bản vẫn hoạt động khi mất mạng. |

---

## 3. Quy Tắc Bảo Mật (Security Rules)

### 3.1 Xác Thực & Phân Quyền

| ID | Rule | Mô Tả |
|---|---|---|
| **SEC-01** | JWT Authentication | Mọi API (trừ `/auth/**`) phải yêu cầu JWT hợp lệ trong header `Authorization: Bearer {token}`. Access token hết hạn sau 15 phút. Refresh token hết hạn sau 7 ngày. |
| **SEC-02** | Role-Based Access Control (RBAC) | Hệ thống có 4 role: `SUPER_ADMIN`, `ADMIN`, `MANAGER`, `EMPLOYEE`. Mỗi endpoint phải khai báo role được phép. KHÔNG dùng hardcode userId để kiểm tra quyền. |
| **SEC-03** | Đăng Ký Tài Khoản Phải Được Duyệt | Nhân viên đăng ký → trạng thái `PENDING`. Chỉ ADMIN/MANAGER mới có quyền APPROVE hoặc REJECT. Tài khoản chưa duyệt KHÔNG được đăng nhập. |
| **SEC-04** | Password Policy | Mật khẩu tối thiểu 8 ký tự, bao gồm chữ hoa, chữ thường, số. PHẢI hash bằng BCrypt (strength ≥ 12). KHÔNG lưu plain-text password bất kỳ đâu. |
| **SEC-05** | API Rate Limiting | Giới hạn 100 request/phút/IP cho API thông thường. Giới hạn 10 request/phút cho `/auth/login` để chống brute force. Trả về HTTP 429 khi vượt giới hạn. |

### 3.2 Bảo Mật Dữ Liệu

- Mọi giao tiếp client-server phải qua HTTPS (TLS 1.2+).
- Dữ liệu nhạy cảm (CCCD, số điện thoại) phải được mã hóa AES-256 trước khi lưu DB.
- Log hệ thống KHÔNG được ghi thông tin nhạy cảm (password, token, PII).
- File ảnh upload phải validate type và size (max 10MB/ảnh). Chỉ chấp nhận: `jpg`, `jpeg`, `png`, `webp`.
- QR code bo mạch phải có chữ ký số để chống làm giả.

---

## 4. Quy Tắc Theo Mô-đun (Module Rules)

### 4.1 Module Quản Lý Kho Bo Mạch

| ID | Rule | Mô Tả |
|---|---|---|
| **MOD-KHO-01** | Mỗi Bo Mạch Có Một QR Duy Nhất | QR code được sinh khi bo mạch nhập kho. Format: `PCB-{YYYYMMDD}-{UUID_SHORT}`. QR KHÔNG thay đổi trong vòng đời. QR hỏng → in lại nhưng ID giữ nguyên. |
| **MOD-KHO-02** | Trạng Thái Bo Mạch | Luồng hợp lệ: `IN_STOCK → CHECKED_OUT → IN_REPAIR → REPAIRED → RETURNED / DISPOSED`. KHÔNG được nhảy trạng thái bừa bãi. Mỗi thay đổi phải ghi log với timestamp và userId. |
| **MOD-KHO-03** | Check-out Bo Mạch | Khi quét QR lấy bo mạch: ghi nhận userId, thời gian lấy, mục đích. Hệ thống hiển thị real-time ai đang giữ bo mạch nào. Một bo mạch chỉ có thể CHECK_OUT bởi một người tại một thời điểm. |

**Quy tắc bổ sung:**
- Nhập/xuất kho phải có xác nhận 2 bước (scan QR → confirm).
- Cảnh báo nếu bo mạch được check-out quá 48 giờ chưa trả.
- Báo cáo tồn kho cập nhật real-time.
- Chỉ ADMIN và MANAGER mới được xóa hoặc hủy bo mạch.

### 4.2 Module Tiếp Nhận Đơn Sửa Chữa

| ID | Rule | Mô Tả |
|---|---|---|
| **MOD-ORDER-01** | Quy Trình Tiếp Nhận | Nhân viên tiếp nhận PHẢI: (1) Chụp ảnh thiết bị, (2) Ghi mô tả tình trạng, (3) Ghi thời gian nhận. Đơn chưa có ảnh KHÔNG được xác nhận. Tối thiểu 1 ảnh, tối đa 10 ảnh/đơn. |
| **MOD-ORDER-02** | Trạng Thái Đơn Hàng | Luồng: `RECEIVED → ASSIGNED → IN_PROGRESS → QUALITY_CHECK → COMPLETED / RETURNED_UNFIXED`. Sếp/Manager có thể thay đổi priority (`LOW/MEDIUM/HIGH/URGENT`) bất kỳ lúc nào. |
| **MOD-ORDER-03** | Thông Báo Tự Động | Khi tạo đơn: thông báo đến nhân viên được assign. Khi thay đổi priority: thông báo kỹ thuật viên phụ trách. Khi hoàn thành: thông báo lễ tân/nhân viên giao hàng. |

**Quy tắc bổ sung:**
- Mỗi đơn có mã duy nhất: `ORD-{YYYY}-{MM}-{NNNNNN}`.
- Nhân viên không thể tự xóa đơn hàng. Chỉ ADMIN mới được xóa.
- Lịch sử thay đổi đơn hàng phải được lưu đầy đủ (audit log).
- Sếp có thể xem dashboard tổng quan tất cả đơn theo trạng thái và priority.

### 4.3 Module Chấm Công Bằng Khuôn Mặt

| ID | Rule | Mô Tả |
|---|---|---|
| **MOD-ATT-01** | Enrollment Khuôn Mặt | Nhân viên phải đăng ký khuôn mặt trước khi sử dụng. Lưu tối thiểu 5 ảnh ở các góc độ/ánh sáng khác nhau. Admin phải verify ảnh trước khi kích hoạt. |
| **MOD-ATT-02** | Quy Trình Chấm Công | Mở app → Camera bật → Nhận diện khuôn mặt → Ghi nhận `CHECK_IN` hoặc `CHECK_OUT` với timestamp. Confidence score phải ≥ 85% mới chấp nhận. Dưới ngưỡng → yêu cầu thử lại hoặc báo cáo thủ công. |
| **MOD-ATT-03** | Anti-Spoofing | Hệ thống PHẢI có liveness detection (chống ảnh tĩnh/video). Ghi log GPS khi chấm công. Cảnh báo nếu chấm công từ địa điểm bất thường. |

**Quy tắc bổ sung:**
- Một ngày chỉ có 1 `CHECK_IN` và 1 `CHECK_OUT` được tính chính thức. Các lần sau là OT.
- Ảnh chấm công được lưu trữ 12 tháng để đối chiếu.
- Admin có thể override chấm công thủ công với lý do bắt buộc.
- Báo cáo chấm công xuất Excel theo tháng.

### 4.4 Module Nhắn Tin Nội Bộ

| ID | Rule | Mô Tả |
|---|---|---|
| **MOD-CHAT-01** | Kiến Trúc Chat | Dùng WebSocket (STOMP protocol). Tin nhắn được persist vào DB. Hỗ trợ: Direct Message (1-1) và Group Chat. Chỉ tài khoản đã APPROVE mới được chat. |
| **MOD-CHAT-02** | Quản Lý Tin Nhắn | Tin nhắn không được xóa vĩnh viễn, chỉ ẩn (soft delete). Lưu lịch sử chat tối thiểu 6 tháng. Hỗ trợ gửi text và ảnh (max 5MB/ảnh). KHÔNG hỗ trợ file thực thi (`.exe`, `.apk`). |

**Quy tắc bổ sung:**
- Hiển thị trạng thái online/offline real-time.
- Push notification khi có tin nhắn mới và app ở background.
- Admin có thể tạo/xóa Group Chat, thêm/xóa thành viên.
- Tin nhắn hệ thống phân biệt rõ với tin nhắn nhân viên.

### 4.5 Module Quản Lý Nhân Viên

| ID | Rule | Mô Tả |
|---|---|---|
| **MOD-EMP-01** | Vòng Đời Tài Khoản | `REGISTERED → PENDING_APPROVAL → ACTIVE → SUSPENDED → DELETED (soft)`. Admin/Manager phê duyệt hoặc từ chối. Tài khoản SUSPENDED không thể đăng nhập nhưng dữ liệu còn nguyên. |
| **MOD-EMP-02** | Thông Tin Nhân Viên | Bắt buộc: Họ tên, MSNV, Bộ phận, SĐT, Email công ty. Tùy chọn: CCCD, ngày sinh, địa chỉ. MSNV phải duy nhất, format: `{DeptCode}-{YYYY}-{NNN}`. |

**Quy tắc bổ sung:**
- Nhân viên chỉ được xem và sửa thông tin cá nhân của mình.
- ADMIN mới có quyền thay đổi Role và Department.
- Lịch sử thay đổi thông tin nhân viên phải được audit log.
- Khi nhân viên nghỉ việc: tài khoản SUSPENDED, dữ liệu giữ nguyên 1 năm.

### 4.6 Module Thông Báo

| ID | Rule | Mô Tả |
|---|---|---|
| **MOD-NOTIF-01** | Kênh Thông Báo | 3 kênh: In-app notification (tất cả thiết bị), Push notification FCM (mobile/tablet), Email (sự kiện quan trọng). Mỗi loại sự kiện khai báo rõ kênh nào được dùng. |
| **MOD-NOTIF-02** | Loại Thông Báo | PHẢI có thông báo cho: duyệt/từ chối tài khoản, đơn sửa chữa mới/thay đổi, bo mạch check-out quá hạn, tin nhắn mới, thay đổi lịch trình, vi phạm chấm công. |

**Quy tắc bổ sung:**
- Người dùng có thể bật/tắt từng loại thông báo trong Settings.
- Thông báo chưa đọc hiển thị badge số lượng.
- Thông báo được lưu trong DB, có thể xem lại lịch sử 30 ngày.

### 4.7 Module Theo Dõi Lịch Trình

| ID | Rule | Mô Tả |
|---|---|---|
| **MOD-SCHED-01** | Timeline Đơn Hàng | Mỗi đơn sửa chữa có timeline: Tiếp nhận → Assign → Đang sửa → Kiểm tra chất lượng → Hoàn thành. Mỗi bước ghi timestamp, người thực hiện và ghi chú (tùy chọn). |

**Quy tắc bổ sung:**
- Sếp/Manager xem được Gantt chart hoặc Kanban board toàn bộ đơn.
- Nhân viên chỉ xem lịch trình của đơn được assign cho mình.
- Dashboard thống kê: số đơn theo trạng thái, thời gian sửa trung bình, KPI nhân viên.

---

## 5. Quy Tắc Viết Code (Coding Rules)

### 5.1 Spring Boot Backend

#### Naming Convention

- **Package:** `com.company.{module}.{layer}` — ví dụ: `com.company.warehouse.service`
- **Class:** PascalCase &nbsp;|&nbsp; **Method/Field:** camelCase &nbsp;|&nbsp; **Constant:** UPPER_SNAKE_CASE
- **DTO suffix:** `XxxRequest` (input), `XxxResponse` (output)
- **API endpoint:** kebab-case — ví dụ: `/api/v1/repair-orders`

#### Code Quality

- Mỗi method không quá 30 dòng. Class không quá 300 dòng.
- Cyclomatic complexity ≤ 10 cho mỗi method.
- KHÔNG comment code cũ. Dùng Git để quản lý lịch sử.
- Mỗi class/method public phải có Javadoc mô tả.
- Unit test coverage ≥ 70% cho Service layer.

#### Database

- Mọi thay đổi schema qua Flyway migration. KHÔNG modify DB trực tiếp.
- Table name: `snake_case`, số nhiều — ví dụ: `repair_orders`, `employees`.
- Mỗi table phải có: `id (UUID)`, `created_at`, `updated_at`, `created_by`, `is_deleted`.
- Index bắt buộc cho: foreign keys, các cột thường xuyên query.
- KHÔNG dùng `SELECT *`. Luôn chỉ định cột cần lấy.

---

### 5.2 Quy Tắc Sử Dụng Mapper (MapStruct)

> 📌 Dùng **MapStruct** cho mapping đơn giản. Map thủ công khi có business logic phức tạp. **KHÔNG dùng ModelMapper** (reflection, chậm, lỗi runtime).

#### Cài Đặt & Cấu Hình

- Dependency: `mapstruct` + `mapstruct-processor` trong `pom.xml`. Version phải khớp với Lombok nếu dùng chung.
- Annotation bắt buộc: `@Mapper(componentModel = "spring")` để inject được bằng `@Autowired` / `@RequiredArgsConstructor`.
- Đặt tất cả Mapper interface vào package riêng: `com.company.{module}.mapper`.
- Tên file theo convention: `{Entity}Mapper.java` — ví dụ: `EmployeeMapper.java`, `RepairOrderMapper.java`.

#### Khi Nào DÙNG MapStruct ✅

| Module / Trường Hợp | Lý Do |
|---|---|
| Quản lý nhân viên | CRUD đơn giản, field 1-1 giữa Entity và DTO |
| Danh sách bo mạch (kho) | List response mapping, không có logic tính toán |
| Thông tin đơn sửa chữa cơ bản | Create/Update request → Entity mapping |
| Thông báo (Notification) | `NotificationEntity → NotificationResponse` đơn giản |
| Tin nhắn chat (Message) | `MessageEntity → MessageResponse`, field ít, không logic |

#### Khi Nào KHÔNG Dùng MapStruct ❌ (Map Thủ Công)

| Module / Trường Hợp | Lý Do |
|---|---|
| Chấm công (Attendance) | Phải tính toán: giờ làm thực tế, OT, trừ nghỉ. Logic không thuộc về mapper. |
| QR Check-out kho | Cần validate trạng thái, kiểm tra conflict. Mapper không xử lý được. |
| Timeline đơn hàng | Aggregate từ nhiều bảng (order + steps + employees). Dùng builder pattern. |
| Dashboard / Báo cáo | Dữ liệu tổng hợp từ nhiều nguồn, không phải mapping 1 entity. |
| Face recognition response | Cần xử lý confidence score, liveness result trước khi trả về. |

#### Convention Code MapStruct

| ID | Rule | Mô Tả |
|---|---|---|
| **MAP-01** | Ignore Field Nhạy Cảm | Luôn dùng `@Mapping(target = "password", ignore = true)` cho các field nhạy cảm. KHÔNG để sót `password`, `token`, `internalNote` ra ngoài Response DTO. |
| **MAP-02** | Xử Lý Nested Object | Nếu Entity có nested object (VD: `RepairOrder` có `Employee`), khai báo `@Mapping` riêng hoặc dùng `uses = {EmployeeMapper.class}`. KHÔNG để MapStruct tự suy đoán nested mapping. |
| **MAP-03** | Tách Biệt toEntity và toResponse | Mỗi Mapper phải có ít nhất 2 method: `toEntity(XxxRequest)` và `toResponse(XxxEntity)`. KHÔNG dùng chung một method cho cả 2 chiều mapping. |
| **MAP-04** | Cấm Business Logic Trong Mapper | `@AfterMapping` chỉ được set default value hoặc format đơn giản. Business logic (tính toán, gọi service, validate) PHẢI ở Service layer, không được để trong Mapper. |

```java
// ✅ ĐÚNG — MapStruct đơn giản, rõ ràng
@Mapper(componentModel = "spring")
public interface EmployeeMapper {
    @Mapping(target = "password", ignore = true)
    EmployeeResponse toResponse(Employee entity);

    Employee toEntity(CreateEmployeeRequest request);

    List<EmployeeResponse> toResponseList(List<Employee> list);
}

// ❌ SAI — Business logic trong Mapper
@AfterMapping
default void afterMap(@MappingTarget AttendanceResponse res) {
    // Logic tính OT KHÔNG được đặt ở đây!
    res.setOvertimeHours(calcOT(res.getCheckIn(), res.getCheckOut()));
}
```

---

### 5.3 Flutter Frontend

#### Naming Convention

- **File/Folder:** `snake_case` &nbsp;|&nbsp; **Class/Widget:** `PascalCase` &nbsp;|&nbsp; **Variable/Method:** `camelCase`
- Widget file suffix theo loại: `_screen.dart`, `_widget.dart`, `_page.dart`
- State management: BLoC pattern — `XxxEvent`, `XxxState`, `XxxBloc`

#### Code Quality

- Widget phải nhỏ, tái sử dụng được. Tách widget khi vượt 100 dòng.
- KHÔNG có business logic trong Widget. Logic thuộc về BLoC/UseCase.
- Tất cả String user-facing phải dùng `l10n` (localization), không hardcode.
- Hình ảnh phải dùng `CachedNetworkImage` để cache. KHÔNG load ảnh trực tiếp.
- Sử dụng `const` constructor bất cứ khi nào có thể để tối ưu performance.

#### API Call

- Mọi API call phải có timeout (connect: 10s, receive: 30s).
- Xử lý đầy đủ các trường hợp: `loading`, `success`, `error`, `empty`.
- Token hết hạn → tự động refresh. Refresh thất bại → logout.
- KHÔNG call API trực tiếp trong Widget. Gọi qua `Repository → UseCase → BLoC`.

---

## 6. Quy Tắc Thiết Kế API (API Rules)

### 6.1 HTTP Methods & Response

| Method | Dùng Khi | Success Code | Ghi Chú |
|---|---|---|---|
| `GET` | Lấy dữ liệu | 200 OK | Không có body thay đổi |
| `POST` | Tạo mới resource | 201 Created | Body chứa resource mới |
| `PUT` | Update toàn bộ resource | 200 OK | Idempotent |
| `PATCH` | Update một phần | 200 OK | Chỉ field thay đổi |
| `DELETE` | Xóa resource | 204 No Content | Soft delete, không xóa thật |

### 6.2 Response Format Chuẩn

> 📌 Tất cả API response **PHẢI** theo format chuẩn dưới đây, không ngoại lệ.

```json
// SUCCESS RESPONSE
{
  "success": true,
  "code": 200,
  "message": "Thành công",
  "data": { },
  "timestamp": "2024-01-15T10:30:00Z"
}

// ERROR RESPONSE
{
  "success": false,
  "code": 400,
  "message": "Dữ liệu không hợp lệ",
  "errors": [
    { "field": "phone", "message": "Số điện thoại không đúng định dạng" }
  ],
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### 6.3 Pagination

- Mọi API trả về danh sách phải hỗ trợ pagination.
- Query params chuẩn: `?page=0&size=20&sort=createdAt,desc`
- Response phải bao gồm: `content[]`, `totalElements`, `totalPages`, `currentPage`, `pageSize`.
- Default page size: 20. Maximum page size: 100.

---

## 7. Quy Tắc Cơ Sở Dữ Liệu (Database Rules)

### 7.1 Cấu Trúc Bảng Chuẩn

> 📌 Mọi bảng trong hệ thống **PHẢI** có đầy đủ các cột audit sau đây.

| Cột | Kiểu Dữ Liệu | Nullable | Mô Tả |
|---|---|---|---|
| `id` | UUID (PK) | NOT NULL | Khóa chính, sinh tự động |
| `created_at` | TIMESTAMP | NOT NULL | Thời gian tạo (UTC) |
| `updated_at` | TIMESTAMP | NOT NULL | Thời gian cập nhật cuối (UTC) |
| `created_by` | UUID (FK) | NOT NULL | ID nhân viên tạo |
| `updated_by` | UUID (FK) | NULLABLE | ID nhân viên cập nhật cuối |
| `is_deleted` | BOOLEAN | NOT NULL | Soft delete flag, default `FALSE` |
| `deleted_at` | TIMESTAMP | NULLABLE | Thời gian xóa (nếu có) |

### 7.2 Quy Tắc Query

- Mọi query đọc phải thêm `WHERE is_deleted = false`.
- KHÔNG dùng `DELETE` SQL statement. Chỉ `UPDATE is_deleted = true`.
- Query phức tạp (JOIN > 3 bảng) phải có comment giải thích mục đích.
- Dùng `@Transactional` cho operation ghi có nhiều bước.
- Pagination bắt buộc cho query có thể trả về > 100 bản ghi.

---

## 8. Quy Tắc Real-time & WebSocket

| ID | Rule | Mô Tả |
|---|---|---|
| **RT-01** | STOMP Topics Convention | Subscribe: `/topic/public/{resource}` cho broadcast. `/user/queue/{resource}` cho private message. Mỗi user sau login subscribe vào `/user/queue/notifications` cho thông báo cá nhân. |
| **RT-02** | Heartbeat | WebSocket heartbeat mỗi 25 giây. Nếu mất kết nối, client tự động reconnect sau 3s → 5s → 10s (exponential backoff). Tối đa 5 lần retry. |
| **RT-03** | Message Queue | Dùng Redis pub/sub để broadcast giữa các instance backend. Đảm bảo nhắn tin hoạt động đúng khi scale horizontal. |

---

## 9. Quy Tắc Kiểm Thử (Testing Rules)

### 9.1 Backend Testing

- **Unit Test:** JUnit 5 + Mockito. Coverage ≥ 70% cho Service layer.
- **Integration Test:** Dùng `@SpringBootTest` + Testcontainers (PostgreSQL, Redis).
- **API Test:** Dùng RestAssured hoặc MockMvc.
- **Performance Test:** Dùng JMeter cho các API critical (chấm công, kho).

### 9.2 Flutter Testing

- **Unit Test:** Dart test package. Cover tất cả UseCase và BLoC.
- **Widget Test:** Dùng `flutter_test`. Cover màn hình chính.
- **Integration Test:** Dùng `integration_test` package trên thiết bị thật (tablet & mobile).

### 9.3 CI/CD

- Mọi Pull Request phải pass toàn bộ automated tests trước khi merge.
- Build tự động trên mọi push vào nhánh `develop` và `main`.
- Deploy tự động vào môi trường staging sau khi merge vào `develop`.
- Deploy production chỉ thủ công, có approval từ Tech Lead.

---

## 10. Quy Tắc Quản Lý Code (Git Rules)

### 10.1 Branching Strategy (Git Flow)

| Branch | Mục Đích | Quy Tắc |
|---|---|---|
| `main` | Production-ready code | Chỉ merge từ `release/*`. Protected. |
| `develop` | Integration branch | Merge từ `feature/*` sau review. |
| `feature/{ticket-id}-{desc}` | Phát triển tính năng mới | Branch từ `develop`. VD: `feature/PROJ-123-warehouse-qr` |
| `bugfix/{ticket-id}-{desc}` | Sửa bug trên develop | Branch từ `develop`. |
| `hotfix/{desc}` | Sửa lỗi khẩn trên production | Branch từ `main`. Merge vào cả `main` và `develop`. |
| `release/{version}` | Chuẩn bị release | Branch từ `develop`. Chỉ bugfix được merge vào đây. |

### 10.2 Commit Message

> 📌 **Format bắt buộc:** `{type}({scope}): {description}`

```
feat(warehouse): add QR check-out tracking
fix(auth): fix JWT refresh token expiry bug
docs(api): update repair order API documentation
```

| Type | Khi Nào Dùng |
|---|---|
| `feat` | Thêm tính năng mới |
| `fix` | Sửa bug |
| `docs` | Cập nhật tài liệu |
| `style` | Format code, không thay đổi logic |
| `refactor` | Refactor code, không thêm tính năng hoặc fix bug |
| `test` | Thêm hoặc sửa test |
| `chore` | Build process, dependency update, CI/CD |

### 10.3 Code Review

- Mọi code phải được ít nhất 1 người review trước khi merge vào `develop`.
- Tech Lead review bắt buộc cho: security changes, database schema, kiến trúc core.
- PR không được merge nếu: có conflict chưa giải quyết, test thất bại, reviewer request changes.
- PR phải link đến ticket tương ứng trong project management tool.

---

## 11. Quy Tắc Vận Hành (Operations Rules)

### 11.1 Logging

- Dùng SLF4J + Logback. Log Level: `ERROR / WARN / INFO / DEBUG`.
- Production chỉ bật `INFO` và cao hơn. `DEBUG` chỉ bật khi debug, tắt ngay sau đó.
- Mỗi request phải có Correlation ID để trace xuyên suốt hệ thống.
- Log các sự kiện quan trọng: login/logout, thay đổi quyền, xóa dữ liệu, lỗi hệ thống.
- KHÔNG log thông tin nhạy cảm: password, token, PII, thông tin thanh toán.

### 11.2 Monitoring & Alerting

- Tích hợp Spring Actuator + Prometheus + Grafana dashboard.
- Alert khi: CPU > 80%, RAM > 85%, API error rate > 5%, DB connection pool exhausted.
- Uptime monitoring với SLA 99.5% (giờ làm việc 7:00–22:00).
- Log retention: 30 ngày hot storage, 1 năm cold storage.

### 11.3 Backup

- Backup DB tự động hàng ngày lúc 2:00 AM.
- Backup ảnh và file hàng tuần.
- Test restore backup hàng tháng.
- Lưu backup tối thiểu 3 tháng. Backup hàng tháng lưu 1 năm.

### 11.4 Môi Trường

| Môi Trường | Mục Đích | Deploy | Data |
|---|---|---|---|
| Development | Local của developer | Manual | Fake/Seeded data |
| Staging | UAT, Test tích hợp | Auto (CI/CD) | Clone từ production (ẩn danh) |
| Production | Hệ thống thật | Manual approval | Dữ liệu thật |

---

## 12. Checklist Trước Khi Release

### 12.1 Backend Checklist

| # | Kiểm Tra |
|---|---|
| 1 | ☐ Tất cả API endpoint có xác thực JWT |
| 2 | ☐ Role-based authorization đúng cho mọi endpoint |
| 3 | ☐ Input validation đầy đủ (không SQL injection, XSS) |
| 4 | ☐ Flyway migration chạy thành công |
| 5 | ☐ Unit test pass, coverage ≥ 70% |
| 6 | ☐ Integration test pass |
| 7 | ☐ Không có hardcode secret/config trong code |
| 8 | ☐ Logging đúng level, không log dữ liệu nhạy cảm |
| 9 | ☐ Pagination cho mọi API danh sách |
| 10 | ☐ API response đúng format chuẩn |

### 12.2 Flutter Checklist

| # | Kiểm Tra |
|---|---|
| 1 | ☐ Test trên cả 3 platform: Android tablet, iOS tablet, Windows |
| 2 | ☐ Test offline mode: app không crash khi mất mạng |
| 3 | ☐ Test với màn hình nhỏ (mobile) và lớn (tablet) |
| 4 | ☐ QR scanner hoạt động đúng trong điều kiện ánh sáng khác nhau |
| 5 | ☐ Face recognition test với nhiều nhân viên khác nhau |
| 6 | ☐ Push notification nhận đúng khi app background và foreground |
| 7 | ☐ Tất cả string tiếng Việt hiển thị đúng encoding |
| 8 | ☐ App không có memory leak (kiểm tra với Flutter DevTools) |
| 9 | ☐ Dark mode/Light mode (nếu hỗ trợ) hiển thị đúng |
| 10 | ☐ Xử lý token refresh đúng, không bị logout đột ngột |

---

## 13. Phê Duyệt Tài Liệu

| Vai Trò | Tên | Ngày Ký |
|---|---|---|
| Tech Lead / Senior Dev | | |
| Project Manager | | |
| Giám Đốc / Owner | | |

---

> 📌 Tài liệu này có hiệu lực kể từ ngày được phê duyệt. Mọi thay đổi phải được cập nhật vào tài liệu và phê duyệt lại trước khi áp dụng.
