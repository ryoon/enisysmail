-- MySQL dump 10.13  Distrib 5.1.69, for redhat-linux-gnu (i386)
--
-- Host: localhost    Database: enisysmail
-- ------------------------------------------------------
-- Server version	5.1.69

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping data for table `gw_webmail_address_groupings`
--


--
-- Dumping data for table `gw_webmail_address_groups`
--


--
-- Dumping data for table `gw_webmail_addresses`
--


--
-- Dumping data for table `gw_webmail_docs`
--


--
-- Dumping data for table `gw_webmail_filter_conditions`
--


--
-- Dumping data for table `gw_webmail_filters`
--


--
-- Dumping data for table `gw_webmail_mail_address_histories`
--


--
-- Dumping data for table `gw_webmail_mail_nodes`
--


--
-- Dumping data for table `gw_webmail_mailboxes`
--


--
-- Dumping data for table `gw_webmail_settings`
--


--
-- Dumping data for table `gw_webmail_signs`
--


--
-- Dumping data for table `gw_webmail_templates`
--


--
-- Dumping data for table `schema_migrations`
--


--
-- Dumping data for table `sessions`
--


--
-- Dumping data for table `sys_address_settings`
--

LOCK TABLES `sys_address_settings` WRITE;
/*!40000 ALTER TABLE `sys_address_settings` DISABLE KEYS */;
INSERT INTO `sys_address_settings` (`id`, `created_at`, `updated_at`, `key_name`, `sort_no`, `used`, `list_view`) VALUES 
(1,'2013-12-05 09:30:00','2013-12-05 09:30:00','name',1,'1','1'),
(2,'2013-12-05 09:30:00','2013-12-05 09:30:00','kana',2,'1','1'),
(3,'2013-12-05 09:30:00','2013-12-05 09:30:00','sort_no',3,'1','1'),
(4,'2013-12-05 09:30:00','2013-12-05 09:30:00','group_id',4,'1','0'),
(5,'2013-12-05 09:30:00','2013-12-05 09:30:00','state',5,'1','0'),
(6,'2013-12-05 09:30:00','2013-12-05 09:30:00','email',6,'1','1'),
(7,'2013-12-05 09:30:00','2013-12-05 09:30:00','mobile_tel',7,'1','0'),
(8,'2013-12-05 09:30:00','2013-12-05 09:30:00','uri',8,'1','0'),
(9,'2013-12-05 09:30:00','2013-12-05 09:30:00','tel',9,'1','0'),
(10,'2013-12-05 09:30:00','2013-12-05 09:30:00','fax',10,'1','0'),
(11,'2013-12-05 09:30:00','2013-12-05 09:30:00','zip_code',11,'1','0'),
(12,'2013-12-05 09:30:00','2013-12-05 09:30:00','address',12,'1','0'),
(13,'2013-12-05 09:30:00','2013-12-05 09:30:00','company_name',13,'1','0'),
(14,'2013-12-05 09:30:00','2013-12-05 09:30:00','company_kana',14,'1','0'),
(15,'2013-12-05 09:30:00','2013-12-05 09:30:00','official_position',15,'1','0'),
(16,'2013-12-05 09:30:00','2013-12-05 09:30:00','company_tel',16,'1','0'),
(17,'2013-12-05 09:30:00','2013-12-05 09:30:00','company_fax',17,'1','0'),
(18,'2013-12-05 09:30:00','2013-12-05 09:30:00','company_zip_code',18,'1','0'),
(19,'2013-12-05 09:30:00','2013-12-05 09:30:00','company_address',19,'1','0'),
(20,'2013-12-05 09:30:00','2013-12-05 09:30:00','memo',20,'1','0');
/*!40000 ALTER TABLE `sys_address_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `sys_creators`
--


--
-- Dumping data for table `sys_editable_groups`
--


--
-- Dumping data for table `sys_files`
--


--
-- Dumping data for table `sys_groups`
--


--
-- Dumping data for table `sys_languages`
--


--
-- Dumping data for table `sys_ldap_synchros`
--


--
-- Dumping data for table `sys_maintenances`
--


--
-- Dumping data for table `sys_messages`
--


--
-- Dumping data for table `sys_object_privileges`
--


--
-- Dumping data for table `sys_publishers`
--


--
-- Dumping data for table `sys_recognitions`
--


--
-- Dumping data for table `sys_role_names`
--


--
-- Dumping data for table `sys_sequences`
--


--
-- Dumping data for table `sys_tasks`
--


--
-- Dumping data for table `sys_unids`
--


--
-- Dumping data for table `sys_user_logins`
--


--
-- Dumping data for table `sys_users`
--


--
-- Dumping data for table `sys_users_groups`
--


--
-- Dumping data for table `sys_users_roles`
--

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-01-24 15:42:21
