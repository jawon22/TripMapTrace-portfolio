package tripmaps.backend.auth.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

@Service
public class EmailService {

    private final JavaMailSender mailSender;
    private final String from;

    public EmailService(JavaMailSender mailSender,
                        @Value("${app.mail.from}") String from) {
        this.mailSender = mailSender;
        this.from = from;
    }

    public void sendPasswordResetEmail(String toEmail, String resetToken) {
        String deepLink = "tripmaptrace://reset-password?token=" + resetToken;
        String subject = "[TripMapTrace] 비밀번호 재설정 안내";
        String body = "<p>안녕하세요, TripMapTrace입니다.</p>"
                + "<p>비밀번호 재설정을 요청하셨습니다. 아래 버튼을 눌러 새 비밀번호를 설정하세요.</p>"
                + "<p><a href=\"" + deepLink + "\" style=\""
                + "display:inline-block;padding:12px 24px;background:#F59E0B;"
                + "color:#fff;text-decoration:none;border-radius:8px;"
                + "font-weight:bold;\">비밀번호 재설정</a></p>"
                + "<p>링크는 <strong>30분</strong> 동안 유효합니다.</p>"
                + "<p>본인이 요청하지 않으셨다면 이 메일을 무시하세요.</p>";

        try {
            var message = mailSender.createMimeMessage();
            var helper = new MimeMessageHelper(message, "UTF-8");
            helper.setFrom(from);
            helper.setTo(toEmail);
            helper.setSubject(subject);
            helper.setText(body, true);
            mailSender.send(message);
        } catch (Exception e) {
            throw new RuntimeException("이메일 발송 실패: " + e.getMessage(), e);
        }
    }
}
