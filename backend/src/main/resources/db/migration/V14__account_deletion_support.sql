-- trips.created_by: ON DELETE SET NULL (탈퇴 유저가 만든 여행은 creator 정보만 제거)
ALTER TABLE trips DROP CONSTRAINT trips_created_by_fkey;
ALTER TABLE trips ALTER COLUMN created_by DROP NOT NULL;
ALTER TABLE trips ADD CONSTRAINT trips_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

-- media.uploader_id: ON DELETE SET NULL (탈퇴 유저 미디어는 익명화)
ALTER TABLE media DROP CONSTRAINT media_uploader_id_fkey;
ALTER TABLE media ALTER COLUMN uploader_id DROP NOT NULL;
ALTER TABLE media ADD CONSTRAINT media_uploader_id_fkey
    FOREIGN KEY (uploader_id) REFERENCES users(id) ON DELETE SET NULL;
