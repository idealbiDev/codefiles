-- =====================================================================
-- SQL Script for Database Configuration Storage
-- =====================================================================
-- This script creates two tables:
-- 1. `database_configs`: Stores the main configuration for each database type.
-- 2. `config_fields`: Stores the dynamic form fields for each configuration.
-- It then inserts the data for Redshift, MS SQL (Local), Azure SQL, and File System.
-- =====================================================================

-- Drop tables if they exist to ensure a clean setup
DROP TABLE IF EXISTS `config_fields`;
DROP TABLE IF EXISTS `database_configs`;

-- =====================================================================
-- Table Structure for `database_configs`
-- =====================================================================
CREATE TABLE `database_configs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `config_key` VARCHAR(50) NOT NULL UNIQUE,
    `display_name` VARCHAR(100) NOT NULL,
    `icon` VARCHAR(100),
    `color` VARCHAR(20),
    `driver` VARCHAR(100),
    `default_port` VARCHAR(10),
    `connection_string_template` TEXT,
    `misc_properties` JSON COMMENT 'For extra properties like file_extensions'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- Table Structure for `config_fields`
-- =====================================================================
CREATE TABLE `config_fields` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `database_config_id` INT NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `label` VARCHAR(255) NOT NULL,
    `field_type` VARCHAR(50) NOT NULL COMMENT 'Renamed from "type" to avoid SQL keyword conflict',
    `is_required` BOOLEAN DEFAULT FALSE,
    `default_value` VARCHAR(255),
    `attributes` JSON COMMENT 'For placeholder, help_text, min, max, options, etc.',
    
    FOREIGN KEY (`database_config_id`) REFERENCES `database_configs`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =====================================================================
-- INSERT DATA
-- =====================================================================

-- -----------------------------------------------------
-- 1. Amazon Redshift
-- -----------------------------------------------------
INSERT INTO `database_configs` (`config_key`, `display_name`, `icon`, `color`, `driver`, `default_port`, `connection_string_template`)
VALUES ('redshift', 'Amazon Redshift', 'fab fa-aws', '#FF4500', 'redshift+psycopg2', '5439', '{driver}://{username}:{password}@{hostname}:{port}/{database}');

SET @last_config_id = LAST_INSERT_ID();

INSERT INTO `config_fields` (`database_config_id`, `name`, `label`, `field_type`, `is_required`, `default_value`, `attributes`) VALUES
(@last_config_id, 'hostname', 'Cluster Endpoint', 'text', TRUE, NULL, JSON_OBJECT('placeholder', 'your-cluster-name.xxxxxx.us-west-2.redshift.amazonaws.com', 'help_text', 'Your Redshift cluster endpoint without the port number')),
(@last_config_id, 'port', 'Port', 'number', TRUE, '5439', JSON_OBJECT('min', 1024, 'max', 65535, 'help_text', 'Typically 5439 for Redshift')),
(@last_config_id, 'database', 'Database Name', 'text', TRUE, NULL, JSON_OBJECT('placeholder', 'dev', 'help_text', 'Initial database to connect to')),
(@last_config_id, 'username', 'Username', 'text', TRUE, NULL, JSON_OBJECT('placeholder', 'awsuser', 'help_text', 'Master username for the cluster')),
(@last_config_id, 'password', 'Password', 'password', TRUE, NULL, JSON_OBJECT('help_text', 'Password for the master user')),
(@last_config_id, 'timeout', 'Connection Timeout (seconds)', 'number', FALSE, '30', JSON_OBJECT('help_text', 'Optional connection timeout setting')),
(@last_config_id, 'sslmode', 'SSL Mode', 'select', FALSE, 'require', JSON_OBJECT('help_text', 'SSL encryption setting', 'options', JSON_ARRAY(JSON_OBJECT('value', 'require', 'label', 'Require'), JSON_OBJECT('value', 'verify-ca', 'label', 'Verify CA'), JSON_OBJECT('value', 'verify-full', 'label', 'Verify Full'), JSON_OBJECT('value', 'disable', 'label', 'Disable'))));

-- -----------------------------------------------------
-- 2. Microsoft SQL Server (Local)
-- -----------------------------------------------------
INSERT INTO `database_configs` (`config_key`, `display_name`, `icon`, `color`, `driver`, `default_port`, `connection_string_template`)
VALUES ('mssql_local', 'Microsoft SQL Server (Local)', 'fab fa-windows', '#005BAC', 'mssql+pyodbc', '1433', '{driver}://{username}:{password}@{hostname}:{port}/{database}?driver={odbc_driver}&TrustServerCertificate=yes');

SET @last_config_id = LAST_INSERT_ID();

INSERT INTO `config_fields` (`database_config_id`, `name`, `label`, `field_type`, `is_required`, `default_value`, `attributes`) VALUES
(@last_config_id, 'hostname', 'Server Name', 'text', TRUE, NULL, JSON_OBJECT('placeholder', 'localhost or server_name\\instance_name', 'help_text', 'SQL Server instance name, e.g., localhost or SERVER\\SQLEXPRESS')),
(@last_config_id, 'port', 'Port', 'number', TRUE, '1433', JSON_OBJECT('min', 1024, 'max', 65535, 'help_text', 'Typically 1433 for SQL Server')),
(@last_config_id, 'database', 'Database Name', 'text', TRUE, NULL, JSON_OBJECT('placeholder', 'mydb', 'help_text', 'Name of the database to connect to')),
(@last_config_id, 'username', 'Username', 'text', FALSE, NULL, JSON_OBJECT('placeholder', 'sa', 'help_text', 'SQL Server username (leave blank for Windows Authentication)')),
(@last_config_id, 'password', 'Password', 'password', FALSE, NULL, JSON_OBJECT('help_text', 'Password for SQL Server user (leave blank for Windows Authentication)')),
(@last_config_id, 'odbc_driver', 'ODBC Driver', 'select', TRUE, 'ODBC+Driver+17+for+SQL+Server', JSON_OBJECT('help_text', 'ODBC driver installed on your system', 'options', JSON_ARRAY(JSON_OBJECT('value', 'ODBC+Driver+17+for+SQL+Server', 'label', 'ODBC Driver 17 for SQL Server'), JSON_OBJECT('value', 'ODBC%20Driver%2018%20for%20SQL%20Server', 'label', 'ODBC Driver 18 for SQL Server'), JSON_OBJECT('value', 'SQL+Server', 'label', 'SQL Server')))),
(@last_config_id, 'trusted_connection', 'Use Windows Authentication', 'checkbox', FALSE, 'yes', JSON_OBJECT('help_text', 'Use Windows credentials for authentication')),
(@last_config_id, 'timeout', 'Connection Timeout (seconds)', 'number', FALSE, '30', JSON_OBJECT('help_text', 'Optional connection timeout setting')),
(@last_config_id, 'encrypt', 'Encrypt Connection', 'checkbox', FALSE, 'yes', JSON_OBJECT('help_text', 'Enable encryption for the connection'));

-- -----------------------------------------------------
-- 3. Azure SQL Database
-- -----------------------------------------------------
INSERT INTO `database_configs` (`config_key`, `display_name`, `icon`, `color`, `driver`, `default_port`, `connection_string_template`)
VALUES ('azure_sql', 'Azure SQL Database', 'fab fa-microsoft', '#00BCF2', 'mssql+pyodbc', '1433', '{driver}://{username}:{password}@{hostname}:{port}/{database}?driver={odbc_driver}&authentication={authentication}');

SET @last_config_id = LAST_INSERT_ID();

INSERT INTO `config_fields` (`database_config_id`, `name`, `label`, `field_type`, `is_required`, `default_value`, `attributes`) VALUES
(@last_config_id, 'hostname', 'Server Name', 'text', TRUE, NULL, JSON_OBJECT('placeholder', 'yourserver.database.windows.net', 'help_text', 'Fully qualified Azure SQL server name')),
(@last_config_id, 'port', 'Port', 'number', TRUE, '1433', JSON_OBJECT('min', 1024, 'max', 65535, 'help_text', 'Typically 1433 for Azure SQL Database')),
(@last_config_id, 'database', 'Database Name', 'text', TRUE, NULL, JSON_OBJECT('placeholder', 'mydb', 'help_text', 'Name of the Azure SQL database')),
(@last_config_id, 'username', 'Username', 'text', FALSE, NULL, JSON_OBJECT('placeholder', 'adminuser', 'help_text', 'SQL authentication username or Microsoft Entra ID user (leave blank for managed identity)')),
(@last_config_id, 'password', 'Password', 'password', FALSE, NULL, JSON_OBJECT('help_text', 'Password for SQL authentication (leave blank for Microsoft Entra ID or managed identity)')),
(@last_config_id, 'odbc_driver', 'ODBC Driver', 'select', TRUE, 'ODBC+Driver+18+for+SQL+Server', JSON_OBJECT('help_text', 'ODBC driver installed on your system', 'options', JSON_ARRAY(JSON_OBJECT('value', 'ODBC+Driver+17+for+SQL+Server', 'label', 'ODBC Driver 17 for SQL Server'), JSON_OBJECT('value', 'ODBC+Driver+18+for+SQL+Server', 'label', 'ODBC Driver 18 for SQL Server')))),
(@last_config_id, 'authentication', 'Authentication Type', 'select', TRUE, 'SqlPassword', JSON_OBJECT('help_text', 'Authentication method for Azure SQL Database', 'options', JSON_ARRAY(JSON_OBJECT('value', 'SqlPassword', 'label', 'SQL Authentication'), JSON_OBJECT('value', 'ActiveDirectoryPassword', 'label', 'Microsoft Entra ID Password'), JSON_OBJECT('value', 'ActiveDirectoryMSI', 'label', 'Microsoft Entra ID Managed Identity'), JSON_OBJECT('value', 'ActiveDirectoryInteractive', 'label', 'Microsoft Entra ID Interactive')))),
(@last_config_id, 'timeout', 'Connection Timeout (seconds)', 'number', FALSE, '30', JSON_OBJECT('help_text', 'Optional connection timeout setting')),
(@last_config_id, 'encrypt', 'Encrypt Connection', 'checkbox', FALSE, 'yes', JSON_OBJECT('help_text', 'Encryption is required for Azure SQL Database'));

-- -----------------------------------------------------
-- 4. File System
-- -----------------------------------------------------
INSERT INTO `database_configs` (`config_key`, `display_name`, `icon`, `color`, `driver`, `connection_string_template`, `misc_properties`)
VALUES ('file_system', 'File System', 'fas fa-folder-open', '#4CAF50', NULL, 'file://{directory_path}', JSON_OBJECT('file_extensions', JSON_ARRAY('txt', 'csv', 'parquet')));

SET @last_config_id = LAST_INSERT_ID();

INSERT INTO `config_fields` (`database_config_id`, `name`, `label`, `field_type`, `is_required`, `default_value`, `attributes`) VALUES
(@last_config_id, 'directory_path', 'Directory Path', 'text', TRUE, NULL, JSON_OBJECT('placeholder', './Uploads/', 'help_text', 'Path to the directory containing TXT, CSV, or Parquet files')),
(@last_config_id, 'file_type', 'File Type', 'select', TRUE, 'csv', JSON_OBJECT('help_text', 'Select the type of files to process', 'options', JSON_ARRAY(JSON_OBJECT('value', 'txt', 'label', 'Text (TXT)'), JSON_OBJECT('value', 'csv', 'label', 'CSV'), JSON_OBJECT('value', 'parquet', 'label', 'Parquet')))),
(@last_config_id, 'delimiter', 'Delimiter (for CSV/TXT)', 'text', FALSE, ',', JSON_OBJECT('placeholder', ',', 'help_text', 'Delimiter for CSV or TXT files (e.g., comma, tab, semicolon)')),
(@last_config_id, 'header', 'Has Header (for CSV/TXT)', 'checkbox', FALSE, 'yes', JSON_OBJECT('help_text', 'Check if the CSV/TXT file has a header row')),
(@last_config_id, 'infer_schema', 'Infer Schema (for Parquet)', 'checkbox', FALSE, 'yes', JSON_OBJECT('help_text', 'Check to automatically infer schema for Parquet files'));

-- -----------------------------------------------------
-- 5. SFTP Connection
-- -----------------------------------------------------
INSERT INTO `database_configs` (`config_key`, `display_name`, `icon`, `color`, `driver`, `default_port`, `connection_string_template`)
VALUES ('sftp', 'SFTP Connection', 'fas fa-server', '#5D6D7E', NULL, '22', 'sftp://{username}@{hostname}:{port}/{remote_path}');

SET @last_config_id = LAST_INSERT_ID();

INSERT INTO `config_fields` (`database_config_id`, `name`, `label`, `field_type`, `is_required`, `default_value`, `attributes`) VALUES
(@last_config_id, 'hostname', 'Hostname', 'text', TRUE, NULL, JSON_OBJECT('placeholder', 'sftp.example.com', 'help_text', 'The SFTP server address.')),
(@last_config_id, 'port', 'Port', 'number', TRUE, '22', JSON_OBJECT('min', 1, 'max', 65535, 'help_text', 'The port for the SFTP server, typically 22.')),
(@last_config_id, 'username', 'Username', 'text', TRUE, NULL, JSON_OBJECT('placeholder', 'user', 'help_text', 'Your SFTP username.')),
(@last_config_id, 'password', 'Password / Passphrase', 'password', FALSE, NULL, JSON_OBJECT('help_text', 'Your SFTP password or the passphrase for your private key. Leave blank if not needed.')),
(@last_config_id, 'private_key', 'Private Key (Optional)', 'textarea', FALSE, NULL, JSON_OBJECT('placeholder', '-----BEGIN OPENSSH PRIVATE KEY-----...', 'help_text', 'Paste your full private key here for key-based authentication.')),
(@last_config_id, 'remote_path', 'Remote Path', 'text', TRUE, NULL, JSON_OBJECT('placeholder', '/remote/data/directory/', 'help_text', 'The full path to the directory on the remote server.'));

