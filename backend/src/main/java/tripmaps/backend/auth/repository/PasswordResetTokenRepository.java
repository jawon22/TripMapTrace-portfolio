package tripmaps.backend.auth.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import tripmaps.backend.auth.domain.PasswordResetToken;

import java.util.Optional;

public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, Long> {
    Optional<PasswordResetToken> findByToken(String token);
}
