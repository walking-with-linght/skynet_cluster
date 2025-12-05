
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS `rank`;

USE rank;


-- ----------------------------
-- Table structure for rank_data
-- ----------------------------
DROP TABLE IF EXISTS `rank_data`;
CREATE TABLE `rank_data`  (
  `id` int NOT NULL AUTO_INCREMENT,
  `rank_type` varchar(64) CHARACTER SET utf8mb4  NOT NULL COMMENT '排行榜类型',
  `player_id` varchar(64) CHARACTER SET utf8mb4  NOT NULL COMMENT '玩家ID',
  `score` double NOT NULL DEFAULT 0 COMMENT '分数',
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `extra_data` varchar(2000) NULL COMMENT '玩家额外数据',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_rank_player`(`rank_type` ASC, `player_id` ASC) USING BTREE,
  INDEX `idx_rank_score`(`rank_type` ASC, `score` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4  COMMENT = '排行榜数据' ROW_FORMAT = Dynamic;


-- ----------------------------
-- Table structure for rank_config
-- ----------------------------
DROP TABLE IF EXISTS `rank_config`;
CREATE TABLE `rank_config`  (
  `id` int NOT NULL AUTO_INCREMENT,
  `rank_type` varchar(64) CHARACTER SET utf8mb4  NOT NULL COMMENT '排行榜类型',
  `config_json` json NOT NULL COMMENT '排行榜配置JSON',
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_rank_type`(`rank_type` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4  COMMENT = '排行榜配置' ROW_FORMAT = Dynamic;
