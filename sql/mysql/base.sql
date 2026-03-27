-- nfs_world is created automatically by MariaDB via MYSQL_DATABASE env var.
-- We only need the Openfire database and its grants here.
CREATE DATABASE IF NOT EXISTS `openfire_nfs`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON `openfire_nfs`.* TO 'nfs_user'@'%';
FLUSH PRIVILEGES;
