-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: localhost    Database: auramind
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `breathing_sessions`
--

DROP TABLE IF EXISTS `breathing_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `breathing_sessions` (
  `id` varchar(64) NOT NULL,
  `user_id` text,
  `technique` text,
  `duration_seconds` int DEFAULT NULL,
  `cycles_completed` int DEFAULT NULL,
  `background_sound` text,
  `mood_after` text,
  `created_at` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `breathing_sessions`
--

LOCK TABLES `breathing_sessions` WRITE;
/*!40000 ALTER TABLE `breathing_sessions` DISABLE KEYS */;
INSERT INTO `breathing_sessions` VALUES ('4d686a37-40dd-448a-890c-a3c91c88b308','2ec51f49136a4337a3f2a491192cc0ef','Box Breathing',14,1,'Silent Mode','Calmer 🧘','2026-08-23T05:28:48.922432'),('59a9b71c-aae8-4b2c-a34c-de9cbef487c8','3db3b00eeb964fa1b28e505c477ba0b6','Box Breathing',14,1,'Ocean Waves','Calmer 🧘','2026-08-23T05:55:17.793963');
/*!40000 ALTER TABLE `breathing_sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `community_comment_reports`
--

DROP TABLE IF EXISTS `community_comment_reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `community_comment_reports` (
  `id` varchar(64) NOT NULL,
  `comment_id` text NOT NULL,
  `reporter_user_id` text NOT NULL,
  `reason` text,
  `created_at` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `community_comment_reports`
--

LOCK TABLES `community_comment_reports` WRITE;
/*!40000 ALTER TABLE `community_comment_reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `community_comment_reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `community_comments`
--

DROP TABLE IF EXISTS `community_comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `community_comments` (
  `id` varchar(64) NOT NULL,
  `post_id` text NOT NULL,
  `user_id` text NOT NULL,
  `body` text NOT NULL,
  `created_at` text NOT NULL,
  `is_hidden` int DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `community_comments`
--

LOCK TABLES `community_comments` WRITE;
/*!40000 ALTER TABLE `community_comments` DISABLE KEYS */;
INSERT INTO `community_comments` VALUES ('5217a915725443e3b79de6fd2d3c9cb6','e094b511da654928ad98dad3278760d0','2ec51f49136a4337a3f2a491192cc0ef','Hello','2026-08-23T05:27:53.742167',0),('5641a55d1a9c488f9a0ad20adfdff129','e094b511da654928ad98dad3278760d0','3db3b00eeb964fa1b28e505c477ba0b6','me too','2026-08-23T05:30:52.071788',0);
/*!40000 ALTER TABLE `community_comments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `community_posts`
--

DROP TABLE IF EXISTS `community_posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `community_posts` (
  `id` varchar(64) NOT NULL,
  `user_id` text NOT NULL,
  `body` text NOT NULL,
  `created_at` text NOT NULL,
  `is_hidden` int DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `community_posts`
--

LOCK TABLES `community_posts` WRITE;
/*!40000 ALTER TABLE `community_posts` DISABLE KEYS */;
INSERT INTO `community_posts` VALUES ('7b5720cb7b7a4cfb9fd30eacc42f7a2d','3db3b00eeb964fa1b28e505c477ba0b6','I am feeling stressed today','2026-08-23T05:58:50.268780',0),('e094b511da654928ad98dad3278760d0','2ec51f49136a4337a3f2a491192cc0ef','I feel very exhausted from all the work.','2026-08-22T20:29:07.082317',0);
/*!40000 ALTER TABLE `community_posts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `community_reports`
--

DROP TABLE IF EXISTS `community_reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `community_reports` (
  `id` varchar(64) NOT NULL,
  `post_id` text NOT NULL,
  `reporter_user_id` text NOT NULL,
  `reason` text,
  `created_at` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `community_reports`
--

LOCK TABLES `community_reports` WRITE;
/*!40000 ALTER TABLE `community_reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `community_reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `grounding_entries`
--

DROP TABLE IF EXISTS `grounding_entries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `grounding_entries` (
  `id` varchar(64) NOT NULL,
  `session_id` text,
  `category` text,
  `item_text` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `grounding_entries`
--

LOCK TABLES `grounding_entries` WRITE;
/*!40000 ALTER TABLE `grounding_entries` DISABLE KEYS */;
INSERT INTO `grounding_entries` VALUES ('1374846f2233424cb82f08b46068ff27','b5d0f7994330412b869dffd722acf648','sight','mouse'),('1cee9a3d3c6448899a5063fcd0e2bcd1','939ad7a2c16940cb992ee272c126de3e','sight','Laptop'),('1f91d199b25747cfa4c42a33ed45bda9','939ad7a2c16940cb992ee272c126de3e','touch','Glasses'),('2208548280a7408e80300afee70eac70','b5d0f7994330412b869dffd722acf648','touch','keyboard'),('30f387dd03e54cb2b434edf41d0e61a7','b5d0f7994330412b869dffd722acf648','hear','fan'),('3b47493f00c8473ab08901aafc5e79f0','b5d0f7994330412b869dffd722acf648','touch','table'),('3e09332b422c4e3588bcd0fb05db62f0','b5d0f7994330412b869dffd722acf648','smell','perfume'),('474a93028c7e4285b631b89219a76747','b5d0f7994330412b869dffd722acf648','sight','keyboard'),('5c48b57dea2e4dfab9403120f727503f','939ad7a2c16940cb992ee272c126de3e','sight','Paper'),('5cea0b0049a245fabd535027006d4cde','939ad7a2c16940cb992ee272c126de3e','touch','Table'),('6c2e7cc22bc94e0b8ccfc5d6dbe1fb28','939ad7a2c16940cb992ee272c126de3e','touch','Floor'),('782149563c5648a086dd2f4fa3cd0ce7','b5d0f7994330412b869dffd722acf648','sight','computer'),('7829c464f9e24053988f28e7b65031bb','939ad7a2c16940cb992ee272c126de3e','taste','Tea'),('788632dd51be40f9b8b147909dcb8e29','939ad7a2c16940cb992ee272c126de3e','hear','Fan'),('8081f72ab9844d36a8c53885b608798a','939ad7a2c16940cb992ee272c126de3e','smell','Chicken'),('80e4ca0d19424b9bb19e08992f6c3612','939ad7a2c16940cb992ee272c126de3e','hear','Clock'),('86fd2d57e37546ba8afbf62545d6c060','b5d0f7994330412b869dffd722acf648','sight','chair'),('8f59d95c86f54f3cb433f4acbd6da982','b5d0f7994330412b869dffd722acf648','taste','water'),('9fe8e89534ec4159ad6c2c7eed667e5a','939ad7a2c16940cb992ee272c126de3e','hear','Typing'),('a9894b43d72144e6b3c211f3cc5e3a34','b5d0f7994330412b869dffd722acf648','sight','laptop'),('af23f3b4dced446291154d6b2a22f956','939ad7a2c16940cb992ee272c126de3e','sight','Box'),('b39bc972686c4efca37600ec8b97700c','b5d0f7994330412b869dffd722acf648','touch','shoes'),('b5c1e580b725418c937c4bc86deb5628','939ad7a2c16940cb992ee272c126de3e','smell','Air'),('b98f6727af204d6d85c62e238804a58d','b5d0f7994330412b869dffd722acf648','smell','air'),('c08d84f25def485b9ffb44e05b705688','b5d0f7994330412b869dffd722acf648','touch','laptop'),('c47c68007f074b3e99d7e56ebd4470d2','b5d0f7994330412b869dffd722acf648','hear','manhser kotha'),('c4e1234409f6465fa5536967bff51c72','b5d0f7994330412b869dffd722acf648','hear','typing'),('e7e20b07111d45959b0e04dafabf8c68','939ad7a2c16940cb992ee272c126de3e','sight','Pen'),('ef600da61b684c329adfe5e99a618eb4','939ad7a2c16940cb992ee272c126de3e','sight','Cup'),('fac9081728b64c81a044472dd5f1cc6b','939ad7a2c16940cb992ee272c126de3e','touch','Laptop');
/*!40000 ALTER TABLE `grounding_entries` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `grounding_sessions`
--

DROP TABLE IF EXISTS `grounding_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `grounding_sessions` (
  `id` varchar(64) NOT NULL,
  `user_id` text,
  `created_at` text,
  `completed` int DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `grounding_sessions`
--

LOCK TABLES `grounding_sessions` WRITE;
/*!40000 ALTER TABLE `grounding_sessions` DISABLE KEYS */;
INSERT INTO `grounding_sessions` VALUES ('8ae3def8374844dba292b0ba9a34fe37','2ec51f49136a4337a3f2a491192cc0ef','2026-08-23T05:29:14.937137',0),('939ad7a2c16940cb992ee272c126de3e','2ec51f49136a4337a3f2a491192cc0ef','2026-08-22T20:29:27.228235',1),('b5d0f7994330412b869dffd722acf648','3db3b00eeb964fa1b28e505c477ba0b6','2026-08-23T05:50:32.224977',1);
/*!40000 ALTER TABLE `grounding_sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mood_checkins`
--

DROP TABLE IF EXISTS `mood_checkins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mood_checkins` (
  `id` varchar(64) NOT NULL,
  `user_id` text,
  `answers` text,
  `created_at` text,
  `mood_score` double DEFAULT NULL,
  `dominant_category` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mood_checkins`
--

LOCK TABLES `mood_checkins` WRITE;
/*!40000 ALTER TABLE `mood_checkins` DISABLE KEYS */;
INSERT INTO `mood_checkins` VALUES ('0b90ef118ed8490392b2126db962b6dd','3db3b00eeb964fa1b28e505c477ba0b6','{\"1\": 1, \"2\": 3, \"3\": 2, \"4\": 2, \"5\": 3, \"6\": 3, \"7\": 2, \"8\": 3, \"9\": 1, \"10\": 0, \"11\": 2, \"12\": 2}','2026-08-23T05:47:37.638318',5,'anxiety'),('b327e3c85b484f21921fdda3058966c7','3db3b00eeb964fa1b28e505c477ba0b6','{\"1\": 0, \"2\": 1, \"3\": 0, \"4\": 1, \"5\": 0, \"6\": 1, \"7\": 0, \"8\": 1, \"9\": 0, \"10\": 0, \"11\": 1, \"12\": 0}','2026-08-23T05:30:35.839264',8.96,'depression'),('b872d383217d4449ae9c2108436b9079','2ec51f49136a4337a3f2a491192cc0ef','{\"1\": 0, \"2\": 4, \"3\": 4, \"4\": 4, \"5\": 4, \"6\": 4, \"7\": 4, \"8\": 4, \"9\": 4, \"10\": 1, \"11\": 0, \"12\": 1}','2026-08-23T05:27:25.480838',2.92,'anxiety'),('e2b72faaa3834bd19a042f5164882310','2ec51f49136a4337a3f2a491192cc0ef','{\"1\": 0, \"2\": 1, \"3\": 0, \"4\": 1, \"5\": 0, \"6\": 1, \"7\": 0, \"8\": 1, \"9\": 3, \"10\": 2, \"11\": 4, \"12\": 3}','2026-08-22T20:28:30.288910',6.67,'stress');
/*!40000 ALTER TABLE `mood_checkins` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sleep_logs`
--

DROP TABLE IF EXISTS `sleep_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sleep_logs` (
  `id` varchar(64) NOT NULL,
  `user_id` text,
  `date` text,
  `sleep_hours` int DEFAULT NULL,
  `sleep_minutes` int DEFAULT NULL,
  `quality` int DEFAULT NULL,
  `post_wake_feeling` int DEFAULT NULL,
  `notes` text,
  `created_at` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sleep_logs`
--

LOCK TABLES `sleep_logs` WRITE;
/*!40000 ALTER TABLE `sleep_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `sleep_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `theme_palettes`
--

DROP TABLE IF EXISTS `theme_palettes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `theme_palettes` (
  `id` varchar(64) NOT NULL,
  `name` text,
  `category` text,
  `primary_color` text,
  `secondary_color` text,
  `accent_color` text,
  `background_color` text,
  `surface_color` text,
  `on_primary` text,
  `on_background` text,
  `thumbnail_gradient` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `theme_palettes`
--

LOCK TABLES `theme_palettes` WRITE;
/*!40000 ALTER TABLE `theme_palettes` DISABLE KEYS */;
INSERT INTO `theme_palettes` VALUES ('aqua','Aqua','stress','#4ABFBF','#E0E8E8','#7DD4D4','#F5FAFA','#FFFFFF','#FFFFFF','#1A4545','[\"#7DD4D4\", \"#4ABFBF\", \"#E0E8E8\"]'),('coral_soft','Coral Soft','depression','#E8786A','#FFFFFF','#F0A090','#FFF8F7','#FFFFFF','#FFFFFF','#5C2D28','[\"#F0A090\", \"#E8786A\", \"#FFFFFF\"]'),('lavender_air','Lavender Air','anxiety','#9B8EC4','#E8E4EF','#B8A9D9','#F9F7FC','#FFFFFF','#FFFFFF','#3D3555','[\"#B8A9D9\", \"#9B8EC4\", \"#E8E4EF\"]'),('mint_breeze','Mint Breeze','stress','#5CB8A8','#FFFFFF','#8DD4C8','#F5FFFC','#FFFFFF','#FFFFFF','#1A4A42','[\"#8DD4C8\", \"#5CB8A8\", \"#FFFFFF\"]'),('ocean_calm','Ocean Calm','anxiety','#4A90D9','#E8F4FD','#87CEEB','#F5FAFF','#FFFFFF','#FFFFFF','#1A3A5C','[\"#87CEEB\", \"#4A90D9\", \"#E8F4FD\"]'),('peach_light','Peach Light','depression','#E8A090','#F5EDE8','#F0C4B8','#FFFAF8','#FFFFFF','#FFFFFF','#5C3D35','[\"#F0C4B8\", \"#E8A090\", \"#F5EDE8\"]'),('sage_forest','Sage Forest','anxiety','#6B8F71','#F5F0E8','#9CAF88','#F8FAF5','#FFFFFF','#FFFFFF','#2D4A32','[\"#9CAF88\", \"#6B8F71\", \"#F5F0E8\"]'),('soft_green','Soft Green','stress','#6BAF7A','#F5F0E8','#9DD4A8','#F8FAF5','#FFFFFF','#FFFFFF','#2D4A35','[\"#9DD4A8\", \"#6BAF7A\", \"#F5F0E8\"]'),('sunrise','Sunrise','depression','#E8A838','#FDF6E8','#F5C563','#FFFBF5','#FFFFFF','#FFFFFF','#5C4A1A','[\"#F5C563\", \"#E8A838\", \"#FDF6E8\"]');
/*!40000 ALTER TABLE `theme_palettes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_theme`
--

DROP TABLE IF EXISTS `user_theme`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_theme` (
  `user_id` varchar(64) NOT NULL,
  `palette_id` text,
  `selected_at` text,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_theme`
--

LOCK TABLES `user_theme` WRITE;
/*!40000 ALTER TABLE `user_theme` DISABLE KEYS */;
INSERT INTO `user_theme` VALUES ('3db3b00eeb964fa1b28e505c477ba0b6','lavender_air','2026-08-23T05:47:49.011283');
/*!40000 ALTER TABLE `user_theme` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` varchar(64) NOT NULL,
  `name` text,
  `email` varchar(255) DEFAULT NULL,
  `password` text,
  `token` text,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES ('2ec51f49136a4337a3f2a491192cc0ef','Nusu ','124@test.com','1234567','d89966bc4517499eaef3710ed92932fa'),('3db3b00eeb964fa1b28e505c477ba0b6','Nusaiba','123@test.com','123456','c6ffc05d56344b5b861b23a3c2efb893');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wellbeing_warnings`
--

DROP TABLE IF EXISTS `wellbeing_warnings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `wellbeing_warnings` (
  `id` varchar(64) NOT NULL,
  `user_id` text,
  `title` text,
  `message` text,
  `created_at` text,
  `is_dismissed` int DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wellbeing_warnings`
--

LOCK TABLES `wellbeing_warnings` WRITE;
/*!40000 ALTER TABLE `wellbeing_warnings` DISABLE KEYS */;
/*!40000 ALTER TABLE `wellbeing_warnings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `journal_entries`
--

DROP TABLE IF EXISTS `journal_entries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `journal_entries` (
  `id` varchar(64) NOT NULL,
  `user_id` varchar(64) NOT NULL,
  `title` text,
  `content` text NOT NULL,
  `mood_tag` text,
  `created_at` text NOT NULL,
  `updated_at` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `journal_entries`
--

LOCK TABLES `journal_entries` WRITE;
/*!40000 ALTER TABLE `journal_entries` DISABLE KEYS */;
/*!40000 ALTER TABLE `journal_entries` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 'auramind'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-08-26 13:32:46
