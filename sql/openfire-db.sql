-- Create the Openfire database (separate from soapbox nfs_world)
CREATE DATABASE IF NOT EXISTS openfire_nfs
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON openfire_nfs.* TO 'nfs_user'@'%';
FLUSH PRIVILEGES;
