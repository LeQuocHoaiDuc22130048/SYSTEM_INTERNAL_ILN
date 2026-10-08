# Ghi nhận ngày đi công trình

Nhân viên tự ghi nhận ngày hôm nay hoặc ngày trước đó. Ghi chú địa điểm/nội dung bắt buộc,
không quá 2000 ký tự. Không có bước duyệt. Nhân viên chỉ sửa dữ liệu của tài khoản đăng nhập.

## API (cần JWT)

- `PUT /api/attendance/me/field-work/{date}`: tích đi công trình hoặc sửa ghi chú.
  Ví dụ ngày: `2026-10-08`; body: `{"note":"Lắp đặt tại nhà máy ABC, Bình Dương"}`.
- `DELETE /api/attendance/me/field-work/{date}`: bỏ tích, xóa mềm; gọi lặp lại vẫn thành công.
- `GET /api/attendance/me/field-work?from=2026-10-01&to=2026-10-08`: danh sách ngày đã tích.
  Mặc định lấy từ đầu tháng đến hôm nay theo Asia/Ho_Chi_Minh.

PUT trả dữ liệu trong `data`: id, employeeId, workDate, note, createdAt, updatedAt.
Không nhận employeeId trong request. Ngày tương lai, note rỗng hoặc quá dài bị từ chối.

## Tổng hợp và Excel

- `/api/attendance/monthly`: ngày đi công trình có `dailyWorkDays[day] = 1.0`,
  `updateNotes[day]` chứa `Đi công trình — [note]`; `notes` có ngày tương ứng.
  Excel tháng hiện tại đã dùng các trường này để ghi số công và cột ghi chú.
- Ngày công trình dùng ký hiệu `p` trong dailyPattern để tương thích Excel hiện tại.
- `/api/attendance/{employeeId}/logs` và `/me/logs`: trạng thái `FIELD_WORK`, note theo ngày;
  tổng workDays tính đúng 1 công cho ngày này.
- Báo cáo ngày và `/me/today` trả thêm `employeeId`, `fieldWork` và `fieldWorkCredit` (1 hoặc 0).
  `fieldWorkCredit` chỉ là phần công từ công trình, không phải tổng công chấm công thông thường.
  Báo cáo ngày bao gồm nhân viên chỉ có ngày công trình nhưng không có bản ghi IN/OUT.
- Ngày công trình tính đúng 1 công kể cả Chủ nhật hoặc có IN/OUT; không tính muộn/vắng/về sớm.
  Giữ giờ vào/ra thực tế; không tạo giờ chấm công giả. Giờ thực làm chỉ tính khi có IN/OUT;
  đánh dấu công trình không tự tạo giờ làm hoặc tăng ca.
- Bỏ tích khiến báo cáo trở lại quy tắc chấm công thông thường.

Frontend/mobile cần nối các API để hiển thị checkbox, ngày và ô note.
Excel lịch sử cá nhân hiện đọc ghi chú từ events; nếu muốn xuất note công trình ở file này,
frontend cần đọc thêm trường `days[].note`. Backend không tạo sự kiện IN/OUT giả để lấp ghi chú.

## Dữ liệu

Flyway V67 tạo `field_work_days`. Một hàng duy nhất cho mỗi nhân viên/ngày,
kể cả đã xóa mềm; tích lại khôi phục hàng cũ. Mutation khóa hàng nhân viên trong transaction
để tránh tạo trùng khi gửi đồng thời. BaseEntity lưu người/thời điểm tạo, sửa và hủy.
Không có cơ chế khóa kỳ công trong chức năng này; cho phép bổ sung mọi ngày quá khứ.
