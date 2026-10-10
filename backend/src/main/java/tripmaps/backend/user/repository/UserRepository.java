package tripmaps.backend.user.repository;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import tripmaps.backend.user.domain.User;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
    List<User> findAllByIdIn(List<Long> ids);
    Optional<User> findByProviderAndProviderId(String provider, String providerId);

    /** 닉네임 부분일치(대소문자 무시) 또는 이메일 정확일치(대소문자 무시), 본인 제외 */
    @Query("SELECT u FROM User u WHERE u.id <> :selfId AND ("
            + "LOWER(u.nickname) LIKE LOWER(CONCAT('%', :q, '%')) "
            + "OR LOWER(u.email) = LOWER(:q))")
    List<User> searchByNicknameOrEmail(@Param("q") String q,
                                       @Param("selfId") Long selfId,
                                       Pageable pageable);
}
