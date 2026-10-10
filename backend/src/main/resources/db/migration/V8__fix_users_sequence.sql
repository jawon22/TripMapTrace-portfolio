-- 시드 데이터(id=1,2)로 인해 시퀀스가 밀려있는 문제 수정
-- 다음 insert부터 MAX(id)+1 부터 시작하도록 설정
SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));
