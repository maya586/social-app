-- 初始化数据库脚本
-- 在容器首次启动时自动执行

-- 创建扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 设置时区
SET timezone = 'Asia/Shanghai';

-- 创建初始管理员用户密码 (需要应用层加密)
-- 密码: Admin123!
-- INSERT INTO users (id, phone, nickname, password_hash, status, created_at, updated_at)
-- VALUES (uuid_generate_v4(), 'admin', '系统管理员', '$2a$10$', 'active', NOW(), NOW());

-- 输出初始化完成信息
DO $$
BEGIN
    RAISE NOTICE '数据库初始化完成';
END $$;