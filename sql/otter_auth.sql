--
-- global replace _TEST with _dev or _live according to stream
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `otter_server_TEST` /*!40100 DEFAULT CHARACTER SET latin1 */;

USE `otter_server_TEST`;

--
-- Table structure for table `chi_server_sessions`
--

DROP TABLE IF EXISTS `chi_server_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `chi_server_sessions` (
  `key` varchar(72) NOT NULL,
  `value` text,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `auth_info`
--

DROP TABLE IF EXISTS `auth_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `auth_info` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `client_id` varchar(72) NOT NULL,
  `user_id` varchar(254) NOT NULL,
  `scope` text NOT NULL,
  `refresh_token` text,
  `code` text,
  `redirect_uri` text,
  `id_token` text,
  `userinfo_claims_serialised` text,
  `code_expires_at` int(11) DEFAULT NULL,
  `refresh_token_expires_at` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--- EOF
