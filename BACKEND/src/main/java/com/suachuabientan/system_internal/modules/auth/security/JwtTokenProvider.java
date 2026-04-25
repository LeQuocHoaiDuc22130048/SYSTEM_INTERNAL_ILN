package com.suachuabientan.system_internal.modules.auth.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import lombok.experimental.FieldDefaults;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Slf4j
@Component
@FieldDefaults(level = lombok.AccessLevel.PRIVATE)
public class JwtTokenProvider {

    @Value("${app.jwt.secret}")
    String jwtSecret;

    @Value("${app.jwt.expiration-ms}")
    Long jwtExpirationMs;


    // Tạo SecretKey từ chuỗi secret trong cấu hình
    private SecretKey getSigningKey() {
        byte[] encodedKey = jwtSecret.getBytes(StandardCharsets.UTF_8);
        return Keys.hmacShaKeyFor(encodedKey);
    }

    // Tạo Jwt token dựa trên Username
    public String generateToken(String username) {
        Date now = new Date();
        Date expiration = new Date(now.getTime() + jwtExpirationMs);

        return Jwts.builder()
                .setSubject(username)
                .setIssuedAt(now)
                .setExpiration(expiration)
                .signWith(getSigningKey(), SignatureAlgorithm.HS256)
                .compact();
    }

    // Lấy user từ trong JWT token
    public String getUsernameFromToken(String token) {
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody();
        return claims.getSubject();
    }


    // Lấy expiration date từ JWT token
    public Date getExpirationDateFromToken(String token) {
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody();
        return claims.getExpiration();
    }

    //Kiểm tra token có hợp lệ không
    public boolean validateToken(String token) {
        try {
            Jwts.parserBuilder()
                    .setSigningKey(getSigningKey())
                    .build()
                    .parseClaimsJws(token);
            return true;
        } catch (MalformedJwtException e) {
            log.error("Token không hợp lệ (Invalid JWT token)");
        } catch (ExpiredJwtException ex) {
            log.error("Token đã hết hạn (Expired JWT token)");
        } catch (UnsupportedJwtException ex) {
            log.error("Token không được hỗ trợ (Unsupported JWT token)");
        } catch (IllegalArgumentException ex) {
            log.error("Chuỗi Claims trống (JWT claims string is empty)");
        } catch (SignatureException ex) {
            log.error("Chữ ký Token không khớp (Invalid JWT signature)");
        }
        return false;
    }
}
