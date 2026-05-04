package com.suachuabientan.system_internal.common.util;

import com.suachuabientan.system_internal.modules.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.flywaydb.core.internal.util.StringUtils;
import org.springframework.stereotype.Component;

import java.time.Year;

@Slf4j
@Component
@RequiredArgsConstructor
public class EmployeeCodeGenerator {
    private final UserRepository userRepository;

    public synchronized String generate(String department) {
        String deptCode = buildDeptCode(department);
        int year = Year.now().getValue();
        int nextSeq = resolveNextSequence(deptCode, year);

        String code = String.format("%s-%d-%03d", deptCode, year, nextSeq);

        while(userRepository.existsByEmployeeCodeAndIsDeletedFalse(code)) {
            log.warn("Employee code collision: {} - thử sequence tiếp theo", code);
            nextSeq++;
            code = String.format("%s-%d-%03d", deptCode, year, nextSeq);
        }

        log.debug("Sinh mã nhân viên: dept='{}' → code='{}'", department, code);
        return code;
    }

    /**
     * Chuyển tên phòng ban → PascalCase không dấu.
     *
     * Bước xử lý:
     *   1. Normalize NFD → tách ký tự base + combining diacritical marks
     *   2. Strip tất cả combining marks (bỏ dấu)
     *   3. Xử lý ký tự đặc biệt tiếng Việt không normalize được: đ→d, Đ→D
     *   4. Ghép PascalCase từng từ (viết hoa chữ đầu, thường các chữ còn lại)
     *   5. Chỉ giữ lại [a-zA-Z0-9]
     *
     * Ví dụ:
     *   "Kế Toán"      → "KeToan"
     *   "Kỹ Thuật"     → "KyThuat"
     *   "Kinh Doanh"   → "KinhDoanh"
     *   "IT"           → "IT"
     *   "Kho"          → "Kho"
     *   null / ""      → "NhanVien"
     */
    String buildDeptCode(String department) {
        if (!StringUtils.hasText(department)) {
            return "NhanVien";
        }

        String[] words = department.trim().split("\\s+");
        StringBuilder result = new StringBuilder();

        for (String word : words) {
            if (word.isEmpty()) continue;

            String normalized = removeDiacritics(word);
            if (normalized.isEmpty()) continue;

            // PascalCase: viết hoa chữ đầu, thường các chữ còn lại
            result.append(Character.toUpperCase(normalized.charAt(0)));
            if (normalized.length() > 1) {
                result.append(normalized.substring(1).toLowerCase());
            }
        }

        // Fallback nếu sau khi xử lý vẫn rỗng
        String code = result.toString().replaceAll("[^a-zA-Z0-9]", "");
        return code.isEmpty() ? "NhanVien" : code;
    }

    /**
     * Bỏ dấu tiếng Việt — normalize NFD rồi strip combining marks.
     * Xử lý thêm: đ/Đ không normalize được qua NFD nên phải replace thủ công.
     */
    private String removeDiacritics(String input) {
        // Xử lý đ/Đ trước (NFD không handle được)
        String result = input
                .replace('đ', 'd')
                .replace('Đ', 'D');

        // Normalize NFD: tách base char + diacritical marks
        String nfd = java.text.Normalizer.normalize(result, java.text.Normalizer.Form.NFD);

        // Strip tất cả combining diacritical marks (Unicode block)
        return nfd.replaceAll("\\p{InCombiningDiacriticalMarks}+", "");
    }

    /**
     * Tìm sequence tiếp theo cho (deptCode, year).
     * Query max sequence hiện tại rồi +1.
     */
    private int resolveNextSequence(String deptCode, int year) {
        // Pattern tìm kiếm: "IT-2024-%" hoặc "KHO-2024-%"
        String prefix = deptCode + "-" + year + "-";
        return userRepository.findMaxSequenceByPrefix(prefix)
                .map(max -> max + 1)
                .orElse(1); // Chưa có ai trong dept này năm này → bắt đầu từ 1
    }
}
