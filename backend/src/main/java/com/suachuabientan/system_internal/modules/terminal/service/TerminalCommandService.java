package com.suachuabientan.system_internal.modules.terminal.service;

import com.suachuabientan.system_internal.modules.attendance.entity.AttendanceRecord;
import com.suachuabientan.system_internal.modules.attendance.repository.AttendanceRecordRepository;
import com.suachuabientan.system_internal.modules.auth.entity.UserEntity;
import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import com.suachuabientan.system_internal.modules.repair.entity.RepairOrder;
import com.suachuabientan.system_internal.modules.repair.repository.RepairOrderRepository;
import com.suachuabientan.system_internal.modules.terminal.dto.SystemActivityDto;
import com.suachuabientan.system_internal.modules.terminal.dto.TerminalCommandResponse;
import com.suachuabientan.system_internal.modules.warehouse.repository.BoardItemRepository;
import com.suachuabientan.system_internal.modules.warehouse.repository.PartRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

import java.lang.management.ManagementFactory;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class TerminalCommandService {

    private final SystemActivityBuffer activityBuffer;
    private final UserRepository userRepository;
    private final RepairOrderRepository repairOrderRepository;
    private final AttendanceRecordRepository attendanceRecordRepository;
    private final BoardItemRepository boardItemRepository;
    private final PartRepository partRepository;

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm:ss").withZone(ZoneId.of("Asia/Ho_Chi_Minh"));
    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy").withZone(ZoneId.of("Asia/Ho_Chi_Minh"));

    public TerminalCommandResponse execute(String rawCommand, String currentUsername) {
        long start = System.currentTimeMillis();
        if (rawCommand == null || rawCommand.trim().isEmpty()) {
            return TerminalCommandResponse.error("", "Vui lòng nhập câu lệnh. Gõ \"help\" để xem hướng dẫn.", 0);
        }

        String input = rawCommand.trim();
        String[] parts = input.split("\\s+");
        String cmd = parts[0].toLowerCase();
        String[] args = parts.length > 1 ? Arrays.copyOfRange(parts, 1, parts.length) : new String[0];

        try {
            String output = switch (cmd) {
                case "help", "?" -> buildHelp();
                case "status", "sysinfo", "info" -> buildStatus();
                case "activity", "activities" -> buildActivity(args);
                case "users", "user" -> buildUsers(args);
                case "orders", "order" -> buildOrders(args);
                case "attendance", "chamcong" -> buildAttendance(args);
                case "warehouse", "kho" -> buildWarehouse(args);
                case "logs", "log" -> buildLogs(args);
                case "clear-buffer" -> {
                    activityBuffer.clear();
                    yield "✓ Bộ nhớ đệm nhật ký hoạt động đã được làm sạch.";
                }
                case "echo" -> String.join(" ", args);
                case "clear", "cls" -> "__CLEAR__";
                default -> "Lệnh không hợp lệ: \"" + cmd + "\". Gõ \"help\" để xem danh sách câu lệnh hỗ trợ.";
            };

            long timeMs = System.currentTimeMillis() - start;

            // Ghi nhận hoạt động gõ lệnh vào buffer
            if (!cmd.equals("clear") && !cmd.equals("cls")) {
                activityBuffer.record(SystemActivityDto.create(
                        "TERMINAL",
                        "EXEC",
                        "Lệnh: " + input,
                        currentUsername,
                        "ADMIN",
                        "127.0.0.1",
                        "SUCCESS",
                        timeMs
                ));
            }

            return TerminalCommandResponse.success(input, output, timeMs);
        } catch (Exception ex) {
            long timeMs = System.currentTimeMillis() - start;
            log.error("Lỗi khi thực thi lệnh terminal: {}", input, ex);
            return TerminalCommandResponse.error(input, "Lỗi thực thi lệnh: " + ex.getMessage(), timeMs);
        }
    }

    private String buildHelp() {
        return """
╔════════════════════════════════════════════════════════════════════════════════════════╗
║                        DANH SÁCH LỆNH TERMINAL HỆ THỐNG                                ║
╠════════════════════════════════════════════════════════════════════════════════════════╣
║  help | ?                 : Hiển thị danh sách câu lệnh hỗ trợ                         ║
║  status | sysinfo         : Xem thông số máy chủ, JVM, bộ nhớ, uptime                  ║
║  activity [số lượng]      : Liệt kê các hoạt động nghiệp vụ gần nhất (mặc định 15)     ║
║  users [--role R]         : Thống kê và danh sách người dùng trong hệ thống            ║
║  orders [--status S] [n]  : Tra cứu các đơn sửa chữa gần đây                           ║
║  attendance [--today]     : Xem tổng quan chấm công và đi công trình hôm nay           ║
║  warehouse                : Thống kê tồn kho bo mạch và linh kiện                      ║
║  logs [số lượng]          : Xem nhật ký HTTP requests gần nhất                         ║
║  clear-buffer             : Xóa trắng bộ nhớ đệm activity buffer                       ║
║  echo <nội dung>          : In lại nội dung đã nhập                                    ║
║  clear | cls              : Xóa sạch màn hình terminal                                 ║
╚════════════════════════════════════════════════════════════════════════════════════════╝
Mẹo: Dùng phím mũi tên LÊN/XUỐNG để duyệt lại lịch sử lệnh; phím TAB để tự động điền lệnh.
""";
    }

    private String buildStatus() {
        Runtime rt = Runtime.getRuntime();
        long totalMb = rt.totalMemory() / (1024 * 1024);
        long freeMb = rt.freeMemory() / (1024 * 1024);
        long usedMb = totalMb - freeMb;
        long maxMb = rt.maxMemory() / (1024 * 1024);

        long uptimeSec = ManagementFactory.getRuntimeMXBean().getUptime() / 1000;
        long hours = uptimeSec / 3600;
        long minutes = (uptimeSec % 3600) / 60;
        long seconds = uptimeSec % 60;

        int activeThreads = Thread.activeCount();
        int activeSubscribers = activityBuffer.getActiveSubscriberCount();
        int bufferCount = activityBuffer.getBufferSize();

        return String.format("""
[SYSTEM HEALTH & METRICS]
--------------------------------------------------------------------------------
  ● Máy chủ         : %s (%s)
  ● Java Runtime    : %s (Vendor: %s)
  ● Thời gian chạy  : %d giờ %d phút %d giây (Uptime)
  ● Bộ nhớ JVM Heap : %d MB đã dùng / %d MB đã cấp (Tối đa: %d MB)
  ● Luồng xử lý     : %d active threads
  ● Số CPU cores    : %d cores
  ● SSE Live Stream : %d client đang kết nối trực tiếp
  ● Buffer Activity : %d / 500 sự kiện được lưu trong RAM
--------------------------------------------------------------------------------
Trạng thái tổng thể: [OK] Hệ thống hoạt động ổn định.
""",
                System.getProperty("os.name"), System.getProperty("os.arch"),
                System.getProperty("java.version"), System.getProperty("java.vendor"),
                hours, minutes, seconds,
                usedMb, totalMb, maxMb,
                activeThreads,
                Runtime.getRuntime().availableProcessors(),
                activeSubscribers,
                bufferCount
        );
    }

    private String buildActivity(String[] args) {
        int limit = 15;
        String category = null;

        for (String arg : args) {
            if (arg.matches("^\\d+$")) {
                limit = Math.min(Integer.parseInt(arg), 100);
            } else if (!arg.startsWith("-")) {
                category = arg.toUpperCase();
            }
        }

        List<SystemActivityDto> list = activityBuffer.getRecent(limit, category);
        if (list.isEmpty()) {
            return "Chưa có hoạt động nào được ghi nhận trong bộ nhớ đệm.";
        }

        StringBuilder sb = new StringBuilder();
        sb.append(String.format("DANH SÁCH %d HOẠT ĐỘNG GẦN NHẤT:\n", list.size()));
        sb.append("--------------------------------------------------------------------------------------------------------\n");
        sb.append(String.format("%-10s | %-12s | %-16s | %-14s | %-32s | %s\n",
                "THỜI GIAN", "DANH MỤC", "TÀI KHOẢN", "THAO TÁC", "CHI TIẾT", "TRẠNG THÁI"));
        sb.append("--------------------------------------------------------------------------------------------------------\n");

        for (SystemActivityDto act : list) {
            String timeStr = TIME_FMT.format(act.timestamp());
            String details = act.details();
            if (details != null && details.length() > 32) {
                details = details.substring(0, 29) + "...";
            }
            sb.append(String.format("%-10s | %-12s | %-16s | %-14s | %-32s | [%s]\n",
                    timeStr,
                    act.category(),
                    act.username() != null ? act.username() : "system",
                    act.action(),
                    details != null ? details : "",
                    act.status()
            ));
        }
        sb.append("--------------------------------------------------------------------------------------------------------");
        return sb.toString();
    }

    private String buildUsers(String[] args) {
        List<UserEntity> users = userRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt"));
        long total = users.size();
        long active = users.stream().filter(u -> u.getStatus() != null && "ACTIVE".equalsIgnoreCase(u.getStatus().name())).count();
        long pending = users.stream().filter(u -> u.getStatus() != null && "PENDING".equalsIgnoreCase(u.getStatus().name())).count();

        Map<String, Long> roleCounts = users.stream()
                .filter(u -> u.getRole() != null)
                .collect(Collectors.groupingBy(u -> u.getRole().name(), Collectors.counting()));

        StringBuilder sb = new StringBuilder();
        sb.append(String.format("[THỐNG KÊ TÀI KHOẢN: %d tổng, %d hoạt động, %d chờ duyệt]\n", total, active, pending));
        sb.append("Phân quyền: ");
        roleCounts.forEach((role, count) -> sb.append(String.format("%s: %d  ", role, count)));
        sb.append("\n\nDANH SÁCH 12 TÀI KHOẢN GẦN NHẤT:\n");
        sb.append("------------------------------------------------------------------------------------\n");
        sb.append(String.format("%-14s | %-20s | %-14s | %-12s | %s\n",
                "USERNAME", "HỌ VÀ TÊN", "VAI TRÒ", "MÃ NV", "TRẠNG THÁI"));
        sb.append("------------------------------------------------------------------------------------\n");

        users.stream().limit(12).forEach(u -> {
            sb.append(String.format("%-14s | %-20s | %-14s | %-12s | %s\n",
                    u.getUsername(),
                    u.getFullName() != null ? (u.getFullName().length() > 20 ? u.getFullName().substring(0, 17) + "..." : u.getFullName()) : "",
                    u.getRole() != null ? u.getRole().name() : "N/A",
                    u.getEmployeeCode() != null ? u.getEmployeeCode() : "---",
                    u.getStatus() != null ? u.getStatus().name() : "ACTIVE"
            ));
        });
        sb.append("------------------------------------------------------------------------------------");
        return sb.toString();
    }

    private String buildOrders(String[] args) {
        List<RepairOrder> all = repairOrderRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt"));
        long total = all.size();

        Map<String, Long> statusCounts = all.stream()
                .filter(o -> o.getStatus() != null)
                .collect(Collectors.groupingBy(o -> o.getStatus().getLabel(), Collectors.counting()));

        StringBuilder sb = new StringBuilder();
        sb.append(String.format("[THỐNG KÊ ĐƠN SỬA CHỮA: %d đơn trong hệ thống]\n", total));
        sb.append("Trạng thái: ");
        statusCounts.forEach((st, count) -> sb.append(String.format("[%s: %d] ", st, count)));
        sb.append("\n\n10 ĐƠN SỬA CHỮA GẦN ĐÂY NHẤT:\n");
        sb.append("----------------------------------------------------------------------------------------------------\n");
        sb.append(String.format("%-16s | %-22s | %-18s | %-16s | %s\n",
                "MÃ ĐƠN", "THIẾT BỊ", "KHÁCH HÀNG", "TRẠNG THÁI", "NGÀY TẠO"));
        sb.append("----------------------------------------------------------------------------------------------------\n");

        all.stream().limit(10).forEach(o -> {
            String dev = o.getDeviceName() != null ? (o.getDeviceName().length() > 22 ? o.getDeviceName().substring(0, 19) + "..." : o.getDeviceName()) : "---";
            String cus = o.getCustomerName() != null ? (o.getCustomerName().length() > 18 ? o.getCustomerName().substring(0, 15) + "..." : o.getCustomerName()) : "---";
            String st = o.getStatus() != null ? o.getStatus().getLabel() : "---";
            String date = o.getCreatedAt() != null ? DATE_FMT.format(o.getCreatedAt()) : "---";
            sb.append(String.format("%-16s | %-22s | %-18s | %-16s | %s\n",
                    o.getOrderCode(), dev, cus, st, date
            ));
        });
        sb.append("----------------------------------------------------------------------------------------------------");
        return sb.toString();
    }

    private String buildAttendance(String[] args) {
        ZoneId zone = ZoneId.of("Asia/Ho_Chi_Minh");
        LocalDate today = LocalDate.now(zone);
        java.time.Instant startOfDay = today.atStartOfDay(zone).toInstant();
        java.time.Instant endOfDay = today.plusDays(1).atStartOfDay(zone).toInstant();

        List<AttendanceRecord> records = attendanceRecordRepository.findByCheckTimeBetween(startOfDay, endOfDay);

        long inCount = records.stream().filter(r -> r.getType() == com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType.IN).count();
        long outCount = records.stream().filter(r -> r.getType() == com.suachuabientan.system_internal.modules.attendance.enums.AttendanceType.OUT).count();
        long distinctEmployees = records.stream().map(AttendanceRecord::getEmployeeId).filter(Objects::nonNull).distinct().count();

        // Load employee names for display
        Map<UUID, String> employeeNames = new HashMap<>();
        userRepository.findAll().forEach(u -> employeeNames.put(u.getId(), u.getFullName() != null ? u.getFullName() : u.getUsername()));

        StringBuilder sb = new StringBuilder();
        sb.append(String.format("[TỔNG QUAN CHẤM CÔNG HÔM NAY: %s]\n", today.format(DateTimeFormatter.ofPattern("dd/MM/yyyy"))));
        sb.append(String.format("  ● Số nhân viên đã điểm danh : %d người\n", distinctEmployees));
        sb.append(String.format("  ● Tổng số lượt IN (vào ca)  : %d lượt\n", inCount));
        sb.append(String.format("  ● Tổng số lượt OUT (tan ca) : %d lượt\n", outCount));
        sb.append("------------------------------------------------------------------------------------\n");

        if (records.isEmpty()) {
            sb.append("Chưa có nhân viên nào điểm danh trong ngày hôm nay.");
        } else {
            sb.append(String.format("%-10s | %-24s | %-8s | %s\n", "GIỜ", "NHÂN VIÊN", "LOẠI", "GHI CHÚ / THIẾT BỊ"));
            sb.append("------------------------------------------------------------------------------------\n");
            // sort descending by checkTime
            records.stream().sorted((a, b) -> b.getCheckTime().compareTo(a.getCheckTime())).limit(12).forEach(r -> {
                String time = r.getCheckTime() != null ? TIME_FMT.format(r.getCheckTime()) : "--:--:--";
                String name = employeeNames.getOrDefault(r.getEmployeeId(), r.getEmployeeId() != null ? r.getEmployeeId().toString().substring(0, 8) : "N/A");
                if (name.length() > 24) name = name.substring(0, 21) + "...";
                String type = r.getType() != null ? r.getType().name() : "-";
                String note = r.getNote() != null ? r.getNote() : (r.getDeviceId() != null ? r.getDeviceId() : "");
                if (note.length() > 30) note = note.substring(0, 27) + "...";

                sb.append(String.format("%-10s | %-24s | %-8s | %s\n", time, name, type, note));
            });
        }
        return sb.toString();
    }

    private String buildWarehouse(String[] args) {
        long boardCount = boardItemRepository.count();
        long partCount = partRepository.count();

        return String.format("""
[BÁO CÁO KHO LINH KIỆN & BO MẠCH]
--------------------------------------------------------------------------------
  ● Số loại bo mạch quản lý : %d
  ● Số danh mục linh kiện   : %d
  ● Trạng thái kết nối kho  : [HOẠT ĐỘNG BÌNH THƯỜNG]
--------------------------------------------------------------------------------
Gõ \"activity WAREHOUSE\" để xem chi tiết các lượt mượn/trả linh kiện gần đây.
""", boardCount, partCount);
    }

    private String buildLogs(String[] args) {
        int limit = 15;
        if (args.length > 0 && args[0].matches("^\\d+$")) {
            limit = Math.min(Integer.parseInt(args[0]), 50);
        }

        List<SystemActivityDto> httpLogs = activityBuffer.getRecent(limit, "HTTP");
        if (httpLogs.isEmpty()) {
            return "Không tìm thấy request logs nào trong buffer.";
        }

        StringBuilder sb = new StringBuilder();
        sb.append(String.format("[NHẬT KÝ %d HTTP REQUESTS GẦN NHẤT]\n", httpLogs.size()));
        sb.append("------------------------------------------------------------------------------------\n");
        sb.append(String.format("%-10s | %-10s | %-12s | %-8s | %s\n",
                "TIME", "IP", "USER", "STATUS", "REQUEST"));
        sb.append("------------------------------------------------------------------------------------\n");

        for (SystemActivityDto log : httpLogs) {
            String time = TIME_FMT.format(log.timestamp());
            sb.append(String.format("%-10s | %-10s | %-12s | [%-6s] | %s (%dms)\n",
                    time,
                    log.ip() != null ? log.ip() : "-",
                    log.username() != null ? log.username() : "anon",
                    log.status(),
                    log.action(),
                    log.latencyMs() != null ? log.latencyMs() : 0
            ));
        }
        sb.append("------------------------------------------------------------------------------------");
        return sb.toString();
    }
}
