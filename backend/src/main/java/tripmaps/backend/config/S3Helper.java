package tripmaps.backend.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.time.Duration;

@Component
public class S3Helper {

    private static final Logger log = LoggerFactory.getLogger(S3Helper.class);

    private final S3Presigner presigner;
    private final S3Client s3Client;

    @Value("${app.s3.bucket}")
    private String bucket;

    public S3Helper(S3Presigner presigner, S3Client s3Client) {
        this.presigner = presigner;
        this.s3Client = s3Client;
    }

    public String createPresignedGetUrl(String key) {
        GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                .signatureDuration(Duration.ofHours(1))
                .getObjectRequest(GetObjectRequest.builder().bucket(bucket).key(key).build())
                .build();
        return presigner.presignGetObject(presignRequest).url().toString();
    }

    public void deleteObject(String key) {
        try {
            s3Client.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).build());
        } catch (Exception e) {
            log.warn("S3 오브젝트 삭제 실패 (key={}): {}", key, e.getMessage());
        }
    }
}
