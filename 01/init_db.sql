CREATE DATABASE IF NOT EXISTS flaskapp_db;

CREATE USER 'flaskapp'@'localhost' IDENTIFIED BY 'flaskpass';
GRANT ALL PRIVILEGES ON flaskapp_db.* TO 'flaskapp'@'localhost';
FLUSH PRIVILEGES;

USE flaskapp_db;
CREATE TABLE servers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(100),
    os VARCHAR(100)
);

INSERT INTO servers (name, role, os) VALUES 
('web01', 'web', 'Ubuntu 24.04'),
('db01', 'database', 'Ubuntu 24.04');

