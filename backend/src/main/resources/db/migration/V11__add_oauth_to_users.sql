ALTER TABLE users
  ADD COLUMN provider VARCHAR(20),
  ADD COLUMN provider_id VARCHAR(255),
  ADD COLUMN profile_image_url TEXT;

-- 소셜 전용 유저는 비밀번호 없음
ALTER TABLE users
  ALTER COLUMN password_hash DROP NOT NULL;

-- 소셜 전용 유저(카카오)는 이메일 없을 수 있음
ALTER TABLE users
  ALTER COLUMN email DROP NOT NULL;

-- 이메일 유니크 제약을 부분 인덱스로 교체 (null 허용)
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_email_key;
CREATE UNIQUE INDEX idx_users_email ON users(email) WHERE email IS NOT NULL;

-- provider + provider_id 복합 유니크 인덱스
CREATE UNIQUE INDEX idx_users_provider ON users(provider, provider_id)
  WHERE provider IS NOT NULL;
