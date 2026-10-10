package tripmaps.backend.user.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

@Entity
@Table(name = "users")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true)
    private String email;

    @Column(name = "password_hash")
    private String passwordHash;

    @Column(length = 50)
    private String nickname;

    @Column(length = 20)
    private String provider;

    @Column(name = "provider_id", length = 255)
    private String providerId;

    @Column(name = "profile_image_url")
    private String profileImageUrl;

    @Column(name = "fcm_token")
    private String fcmToken;

    @Column(name = "push_agreed", nullable = false)
    private boolean pushAgreed = false;

    @Column(name = "marketing_agreed", nullable = false)
    private boolean marketingAgreed = false;

    @Column(name = "onboarding_done", nullable = false)
    private boolean onboardingDone = false;

    @Column(name = "notify_upload", nullable = false)
    private boolean notifyUpload = true;

    @Column(name = "notify_join", nullable = false)
    private boolean notifyJoin = true;

    @Column(name = "notify_role_change", nullable = false)
    private boolean notifyRoleChange = true;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public static User create(String email, String encodedPassword, String nickname,
                              boolean pushAgreed, boolean marketingAgreed) {
        User user = new User();
        user.email = email;
        user.passwordHash = encodedPassword;
        user.nickname = nickname;
        user.pushAgreed = pushAgreed;
        user.marketingAgreed = marketingAgreed;
        return user;
    }

    public static User createOAuthUser(String email, String provider, String providerId,
                                       String nickname, String profileImageUrl) {
        User user = new User();
        user.email = email;
        user.provider = provider;
        user.providerId = providerId;
        user.nickname = nickname;
        user.profileImageUrl = profileImageUrl;
        return user;
    }

    public void updatePasswordHash(String encodedPassword) {
        this.passwordHash = encodedPassword;
    }

    public void updateProfileImageUrl(String profileImageUrl) {
        this.profileImageUrl = profileImageUrl;
    }

    public void updateNickname(String nickname) {
        this.nickname = nickname;
    }

    public void updateFcmToken(String fcmToken) {
        this.fcmToken = fcmToken;
    }

    public void updateNotificationSettings(boolean notifyUpload, boolean notifyJoin, boolean notifyRoleChange) {
        this.notifyUpload = notifyUpload;
        this.notifyJoin = notifyJoin;
        this.notifyRoleChange = notifyRoleChange;
    }

    public void completeOnboarding() {
        this.onboardingDone = true;
    }
}
