package tripmaps.backend.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

import javax.annotation.PostConstruct;
import java.io.FileInputStream;
import java.io.IOException;

@Configuration
public class FcmConfig {

    private static final Logger log = LoggerFactory.getLogger(FcmConfig.class);

    @Value("${app.fcm.service-account-key:}")
    private String serviceAccountKeyPath;

    @PostConstruct
    public void init() {
        if (serviceAccountKeyPath == null || serviceAccountKeyPath.isBlank()) {
            log.warn("FCM 비활성화: app.fcm.service-account-key 환경변수가 설정되지 않았습니다.");
            return;
        }
        if (!FirebaseApp.getApps().isEmpty()) {
            return;
        }
        try (FileInputStream serviceAccount = new FileInputStream(serviceAccountKeyPath)) {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();
            FirebaseApp.initializeApp(options);
            log.info("Firebase Admin SDK 초기화 완료");
        } catch (IOException e) {
            log.error("Firebase Admin SDK 초기화 실패: {}", e.getMessage());
        }
    }
}
