UPDATE PARAMETER SET `VALUE` = 'false'                                    WHERE `NAME` = 'ENABLE_REDIS';
UPDATE PARAMETER SET `VALUE` = '1'                                        WHERE `NAME` = 'STARTING_LEVEL_NUMBER';
UPDATE PARAMETER SET `VALUE` = 'http://${SERVER_IP}:${SERVER_PORT}'       WHERE `NAME` = 'SERVER_ADDRESS';
UPDATE PARAMETER SET `VALUE` = '${OPENFIRE_TOKEN}'                        WHERE `NAME` = 'OPENFIRE_TOKEN';
UPDATE PARAMETER SET `VALUE` = 'http://openfire:9090/plugins/restapi/v1'  WHERE `NAME` = 'OPENFIRE_ADDRESS';
UPDATE PARAMETER SET `VALUE` = '${SERVER_IP}'                             WHERE `NAME` = 'UDP_FREEROAM_IP';
UPDATE PARAMETER SET `VALUE` = '${SERVER_IP}'                             WHERE `NAME` = 'UDP_RACE_IP';
UPDATE PARAMETER SET `VALUE` = '${SERVER_IP}'                             WHERE `NAME` = 'XMPP_IP';
INSERT INTO PARAMETER (`NAME`, `VALUE`) VALUES ('XMPP_DOMAIN', 'openfire') ON DUPLICATE KEY UPDATE `VALUE` = VALUES(`VALUE`);
UPDATE PARAMETER SET `VALUE` = '5222'                                     WHERE `NAME` = 'XMPP_PORT';
INSERT INTO PARAMETER (`NAME`, `VALUE`) VALUES ('MODDING_ENABLED',    'true')                      ON DUPLICATE KEY UPDATE `VALUE` = VALUES(`VALUE`);
INSERT INTO PARAMETER (`NAME`, `VALUE`) VALUES ('MODDING_BASE_PATH',  'http://${SERVER_IP}:8000')  ON DUPLICATE KEY UPDATE `VALUE` = VALUES(`VALUE`);
INSERT INTO PARAMETER (`NAME`, `VALUE`) VALUES ('MODDING_FEATURES',   '')                          ON DUPLICATE KEY UPDATE `VALUE` = VALUES(`VALUE`);
INSERT INTO PARAMETER (`NAME`, `VALUE`) VALUES ('MODDING_SERVER_ID',  '${MODDING_SERVER_ID}')      ON DUPLICATE KEY UPDATE `VALUE` = VALUES(`VALUE`);

-- ============================================================
-- CARD PACKS — final design
-- ============================================================

-- T1/T2/T3/T4 item1 reward tables: добавить custom и elite стили, выравнять до 0.2
UPDATE REWARD_TABLE_ITEM SET dropWeight = 0.2
WHERE rewardTableEntity_ID IN (1506, 1511, 1516, 1551); -- t1_bronze/silver/gold/platinumA item1

INSERT INTO REWARD_TABLE_ITEM (ID, dropWeight, script, rewardTableEntity_ID) VALUES
  (90010, 0.2, 'generator.weightedRandomTableItem(''street_custom_parts'')', 1506),
  (90011, 0.2, 'generator.weightedRandomTableItem(''street_elite_parts'')',  1506),
  (90012, 0.2, 'generator.weightedRandomTableItem(''race_custom_parts'')',   1511),
  (90013, 0.2, 'generator.weightedRandomTableItem(''race_elite_parts'')',    1511),
  (90014, 0.2, 'generator.weightedRandomTableItem(''pro_custom_parts'')',    1516),
  (90015, 0.2, 'generator.weightedRandomTableItem(''pro_elite_parts'')',     1516),
  (90016, 0.2, 'generator.weightedRandomTableItem(''ultra_custom_parts'')',  1551),
  (90017, 0.2, 'generator.weightedRandomTableItem(''ultra_elite_parts'')',   1551)
ON DUPLICATE KEY UPDATE dropWeight = VALUES(dropWeight), script = VALUES(script);

-- T1/T2/T3/T4: слоты 3-5 → item1 (только детали, без паверапов)
UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''cardpack_t1_bronze_item1'')'    WHERE ID IN (108,109,110);
UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''cardpack_t1_silver_item1'')'    WHERE ID IN (113,114,115);
UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''cardpack_t1_gold_item1'')'      WHERE ID IN (118,119,120);
UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''cardpack_t1_platinumA_item1'')' WHERE ID IN (153,154,155);

-- Black Diamond item1: равные веса ~33% на каждый из 3 стилей
UPDATE REWARD_TABLE_ITEM rti
JOIN REWARD_TABLE rt ON rti.rewardTableEntity_ID = rt.ID
SET rti.dropWeight = 0.333
WHERE rt.name = 'cardpack_blackdiamond_item1';

-- Black Diamond: слоты 3-5 → item1
UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''cardpack_blackdiamond_item1'')' WHERE ID IN (433,434,435);

-- Powerup Pack (cardpack_silver, серебряная карточка): 2× bronze + 2× silver + 1× gold
UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''powerups_bronze'')' WHERE ID IN (356,357);
UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''powerups_silver'')' WHERE ID IN (358,359);
UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''powerups_gold'')'   WHERE ID = 360;

-- Premium Powerup Pack (cardpack_gold, золотая карточка): 2× platinum + 2× diamond + 1× diamond_upper
UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''powerups_platinum'')'     WHERE ID IN (361,362);
UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''powerups_diamond'')'       WHERE ID IN (363,364);
UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''powerups_diamond_upper'')' WHERE ID = 365;

-- Skillmods Mystery Pack: только скилл-моды ★1–★5, без паверапов
DELETE FROM REWARD_TABLE_ITEM WHERE id IN (18666, 18667); -- удалить powerups_mystery, powerups_bronze
UPDATE REWARD_TABLE_ITEM SET dropWeight = 0.30 WHERE id = 18661; -- skillmods_1star
UPDATE REWARD_TABLE_ITEM SET dropWeight = 0.30 WHERE id = 18662; -- skillmods_2star
UPDATE REWARD_TABLE_ITEM SET dropWeight = 0.25 WHERE id = 18663; -- skillmods_3star
UPDATE REWARD_TABLE_ITEM SET dropWeight = 0.12 WHERE id = 18664; -- skillmods_4star
UPDATE REWARD_TABLE_ITEM SET dropWeight = 0.03 WHERE id = 18665; -- skillmods_5star

-- Premium Powerup Pack (cardpack_blue): УДАЛЁН — заменён на cardpack_gold
-- INSERT INTO CARD_PACK_ITEM ... (не нужен)

-- Aftermarket Pack: создать 5 слотов (CARD_PACK ID=1)
INSERT INTO CARD_PACK_ITEM (ID, script, cardPackEntity_ID) VALUES
  (910, 'generator.weightedRandomTableItem(''cardpack_aftermarket_item1'')', 1),
  (911, 'generator.weightedRandomTableItem(''cardpack_aftermarket_item1'')', 1),
  (912, 'generator.weightedRandomTableItem(''cardpack_aftermarket_item1'')', 1),
  (913, 'generator.weightedRandomTableItem(''cardpack_aftermarket_item1'')', 1),
  (914, 'generator.weightedRandomTableItem(''cardpack_aftermarket_item1'')', 1)
ON DUPLICATE KEY UPDATE script = VALUES(script);

-- Цены, названия, включение/выключение паков + порядок отображения (priority ASC = первый)
UPDATE PRODUCT SET productTitle='T1 Parts Pack',         price= 70000, currency='CASH', enabled=1, priority= 100 WHERE entitlementTag='cardpack_t1_bronze'         AND categoryName='BoosterPacks';
UPDATE PRODUCT SET productTitle='T2 Parts Pack',         price=130000, currency='CASH', enabled=1, priority= 200 WHERE entitlementTag='cardpack_t1_silver'         AND categoryName='BoosterPacks';
UPDATE PRODUCT SET productTitle='T3 Parts Pack',         price=200000, currency='CASH', enabled=1, priority= 300 WHERE entitlementTag='cardpack_t1_gold'           AND categoryName='BoosterPacks';
UPDATE PRODUCT SET productTitle='T4 Parts Pack',         price=350000, currency='CASH', enabled=1, priority= 400 WHERE entitlementTag='cardpack_t1_platinumA'      AND categoryName='BoosterPacks';
UPDATE PRODUCT SET                                        price=500000, currency='CASH', enabled=1, priority= 500 WHERE entitlementTag='cardpack_blackdiamond'      AND categoryName='BoosterPacks';
UPDATE PRODUCT SET productTitle='Powerup Pack',          price= 75000, currency='CASH', enabled=1, priority= 600 WHERE entitlementTag='cardpack_silver'            AND categoryName='BoosterPacks';
UPDATE PRODUCT SET productTitle='Premium Powerup Pack',  price=200000, currency='CASH', enabled=1, priority= 700 WHERE entitlementTag='cardpack_gold'              AND categoryName='BoosterPacks';
UPDATE PRODUCT SET                                        price= 80000, currency='CASH', enabled=1, priority= 800 WHERE entitlementTag='cardpack_skillmods_mystery' AND categoryName='BoosterPacks';
UPDATE PRODUCT SET                                        price= 65000, currency='CASH', enabled=1, priority=  40 WHERE entitlementTag='cardpack_aftermarket'       AND categoryName='BoosterPacks';

-- Отключить неиспользуемые паки
UPDATE PRODUCT SET enabled=0 WHERE entitlementTag IN ('cardpack_bronze','cardpack_platinum','cardpack_mystery','cardpack_blue','cardpack_skillmods_bronze');
-- Отключить дубли STORE_BOOSTERPACKS
UPDATE PRODUCT SET enabled=0 WHERE categoryName='STORE_BOOSTERPACKS' AND entitlementTag IN
  ('cardpack_silver','cardpack_gold','cardpack_mystery','cardpack_blue',
   'cardpack_t1_bronze','cardpack_t1_silver','cardpack_t1_gold','cardpack_t1_platinumA',
   'cardpack_blackdiamond','cardpack_aftermarket','cardpack_skillmods_mystery');

-- Bronze Skill Pack: отключён (оставлен только Mystery Skill Pack)
-- Фикс слотов оставлен на случай будущего включения:
-- UPDATE CARD_PACK_ITEM SET script = 'generator.weightedRandomTableItem(''cardpack_skillmods_bronze_item1'')' WHERE ID IN (473,474,475);
