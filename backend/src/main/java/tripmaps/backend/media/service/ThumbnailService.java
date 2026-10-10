package tripmaps.backend.media.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import tripmaps.backend.media.domain.Media;
import tripmaps.backend.media.repository.MediaRepository;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;

@Service
public class ThumbnailService {

    private static final Logger log = LoggerFactory.getLogger(ThumbnailService.class);

    private final S3Client s3Client;
    private final MediaRepository mediaRepository;

    @Value("${app.s3.bucket}")
    private String bucket;

    public ThumbnailService(S3Client s3Client, MediaRepository mediaRepository) {
        this.s3Client = s3Client;
        this.mediaRepository = mediaRepository;
    }

    /**
     * 영상 파일에서 FFmpeg로 첫 프레임을 추출해 썸네일로 저장.
     * FFmpeg 미설치 환경에서는 경고 로그만 남기고 종료 (미디어 상태 변경 없음).
     */
    @Async
    @Transactional
    public void generateVideoThumbnail(Long mediaId, Long tripId, String storageKey) {
        Path tmpVideo = null;
        Path tmpThumb = null;

        try {
            // 1) S3에서 영상 바이트 다운로드 후 임시 파일에 직접 쓰기
            // (SDK getObject(request, Path)는 파일이 이미 존재하면 FileAlreadyExistsException 발생)
            tmpVideo = Files.createTempFile("video_", "_src");
            byte[] videoBytes = s3Client.getObjectAsBytes(
                    GetObjectRequest.builder().bucket(bucket).key(storageKey).build()
            ).asByteArray();
            Files.write(tmpVideo, videoBytes);

            // 2) FFmpeg로 첫 프레임 추출 (출력 경로만 확보, 빈 파일 생성 후 삭제해 FFmpeg가 직접 생성)
            tmpThumb = Files.createTempFile("thumb_", ".jpg");
            Files.delete(tmpThumb); // FFmpeg -y 전에 삭제해 경로만 재사용
            ProcessBuilder pb = new ProcessBuilder(
                    "ffmpeg", "-y",
                    "-ss", "0",
                    "-i", tmpVideo.toAbsolutePath().toString(),
                    "-vframes", "1",
                    "-vf", "scale=400:-1",
                    tmpThumb.toAbsolutePath().toString()
            );
            pb.redirectErrorStream(true);
            Process process = pb.start();
            int exitCode = process.waitFor();

            if (exitCode != 0) {
                log.warn("FFmpeg 비정상 종료 (exitCode={}, mediaId={})", exitCode, mediaId);
                return;
            }

            // 3) 썸네일 S3 업로드
            byte[] thumbBytes = Files.readAllBytes(tmpThumb);
            String thumbKey = "thumbnails/" + tripId + "/" + UUID.randomUUID() + "_thumb.jpg";
            s3Client.putObject(
                    PutObjectRequest.builder()
                            .bucket(bucket)
                            .key(thumbKey)
                            .contentType("image/jpeg")
                            .contentLength((long) thumbBytes.length)
                            .build(),
                    RequestBody.fromBytes(thumbBytes)
            );

            // 4) DB 업데이트
            mediaRepository.findById(mediaId).ifPresent(media -> {
                media.updateThumbnailKey(thumbKey);
                mediaRepository.save(media);
            });

            log.info("영상 썸네일 생성 완료 (mediaId={}, thumbKey={})", mediaId, thumbKey);

        } catch (IOException | InterruptedException e) {
            log.warn("영상 썸네일 생성 실패 (mediaId={}): {}", mediaId, e.getMessage());
            Thread.currentThread().interrupt();
        } finally {
            deleteSilently(tmpVideo);
            deleteSilently(tmpThumb);
        }
    }

    private void deleteSilently(Path path) {
        if (path != null) {
            try {
                Files.deleteIfExists(path);
            } catch (IOException ignored) {}
        }
    }
}
