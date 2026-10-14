-- ============================================================
--  Card Marketplace : Mock data (20 rows / table)
--  ต้องรันไฟล์ DDL (สร้างตาราง) ก่อน แล้วค่อยรันไฟล์นี้
--
--  ลำดับ insert (ตาม FK):
--  Trader -> Gacha -> Orders -> Payment -> Shipment -> Listing
--  -> Items -> Card / Boxset -> Includes -> Own -> Open
--
--  หมายเหตุ:
--  * Items 20 แถว = Card 14 แถว (Item 1-14) + Boxset 6 แถว (Item 15-20)
--    เพราะเป็น disjoint subtype ที่ใช้ PK ร่วมกับ Items
--  * Order i <-> Listing i <-> Item i (1:1:1) ผู้ขายไม่ใช่ผู้ซื้อเสมอ
--  * Includes: Gacha 1-5 มีของรางวัลกาชาละ 4 ชิ้น (รวม 20 แถว)
--    ผลรวม probability ของแต่ละกาชา = 1.0000
--  * Open ใช้ Item ที่อยู่ใน prize pool ของกาชานั้นจริง
-- ============================================================

USE card_marketplace;

-- ------------------------------------------------------------
--  1. Trader
-- ------------------------------------------------------------
INSERT INTO Trader (Trader_ID, Trader_Name, Email, Phone, Address) VALUES
( 1, 'Somchai Jaidee',      'somchai.j@example.com',    '081-234-5678', '12/3 Nimman Rd, Chiang Mai 50200'),
( 2, 'Suda Rattanakul',     'suda.r@example.com',       '082-345-6789', '88 Sukhumvit 24, Bangkok 10110'),
( 3, 'Anan Wongsawat',      'anan.w@example.com',       '083-456-7890', '45 Phahonyothin Rd, Bangkok 10400'),
( 4, 'Pimchanok Srisuk',    'pimchanok.s@example.com',  '084-567-8901', '9 Thapae Rd, Chiang Mai 50000'),
( 5, 'Kittisak Thongdee',   'kittisak.t@example.com',   NULL,           '221 Mittraphap Rd, Khon Kaen 40000'),
( 6, 'Naree Chaiyaphum',    'naree.c@example.com',      '086-789-0123', '5 Ratchadamnoen Rd, Bangkok 10200'),
( 7, 'Wichai Prasert',      'wichai.p@example.com',     '087-890-1234', '77 Chang Klan Rd, Chiang Mai 50100'),
( 8, 'Orawan Boonmee',      'orawan.b@example.com',     '088-901-2345', '31 Beach Rd, Pattaya, Chonburi 20150'),
( 9, 'Thanakorn Meesuk',    'thanakorn.m@example.com',  NULL,           '14 Nimmanhaemin Soi 9, Chiang Mai 50200'),
(10, 'Jiraporn Saetang',    'jiraporn.s@example.com',   '090-123-4567', '60 Thanon Wua Lai, Chiang Mai 50100'),
(11, 'Prasit Kaewmanee',    'prasit.k@example.com',     '091-234-5678', '102 Rama IV Rd, Bangkok 10500'),
(12, 'Manee Phromwong',     'manee.p@example.com',      '092-345-6789', '18 Yommarat Rd, Phitsanulok 65000'),
(13, 'Chatchai Intharat',   'chatchai.i@example.com',   '093-456-7890', '7 Kad Suan Kaew Rd, Chiang Mai 50300'),
(14, 'Ratchanee Dechsiri',  'ratchanee.d@example.com',  NULL,           '250 Charoen Krung Rd, Bangkok 10120'),
(15, 'Sakda Limpiyakorn',   'sakda.l@example.com',      '095-678-9012', '33 Hat Yai-Songkhla Rd, Songkhla 90110'),
(16, 'Araya Phetcharat',    'araya.p@example.com',      '096-789-0123', '48 Khao Tao Rd, Hua Hin, Prachuap Khiri Khan 77110'),
(17, 'Boonlert Sakulthai',  'boonlert.s@example.com',   '097-890-1234', '15 Mueang Rd, Udon Thani 41000'),
(18, 'Chanida Wattana',     'chanida.w@example.com',    NULL,           '92 Nakhon Ratchasima Rd, Nakhon Ratchasima 30000'),
(19, 'Dusit Pongpan',       'dusit.p@example.com',      '099-012-3456', '3 Sri Phuwanart Rd, Lampang 52000'),
(20, 'Ekkachai Munkong',    'ekkachai.m@example.com',   '080-123-4567', '26 Phet Kasem Rd, Nakhon Pathom 73000');

-- ------------------------------------------------------------
--  2. Gacha
-- ------------------------------------------------------------
INSERT INTO Gacha (Gacha_ID, Name, Status, Price, Stock) VALUES
( 1, 'Dragon Saga Gacha',        'Active',   100.00, 200),
( 2, 'Frozen Realm Gacha',       'Active',   120.00, 150),
( 3, 'Night Blade Gacha',        'Active',    90.00, 300),
( 4, 'Storm Chronicle Gacha',    'Active',   150.00,  80),
( 5, 'Forest Tales Gacha',       'Inactive',  60.00,   0),
( 6, 'Steel Legion Gacha',       'Active',   110.00, 120),
( 7, 'Deep Blue Gacha',          'Active',   130.00,  95),
( 8, 'Golden Phoenix Special',   'Inactive', 250.00,  10),
( 9, 'Starter Pack Gacha',       'Active',    50.00, 500),
(10, 'Mystery Box Gacha',        'Active',   199.00,  60),
(11, 'Summer Festival Gacha',    'Inactive',  80.00,   0),
(12, 'Legendary Hero Gacha',     'Active',   300.00,  25),
(13, 'Shadow Realm Gacha',       'Active',    95.00, 175),
(14, 'Crystal Garden Gacha',     'Inactive',  70.00,  40),
(15, 'Anniversary Gacha',        'Active',   180.00, 100),
(16, 'Crimson Knight Gacha',     'Active',   140.00,  70),
(17, 'Azure Sky Gacha',          'Active',   125.00, 110),
(18, 'Ancient Relic Gacha',      'Inactive', 220.00,   5),
(19, 'Lucky Clover Gacha',       'Active',    65.00, 400),
(20, 'Royal Court Gacha',        'Active',   210.00,  45);

-- ------------------------------------------------------------
--  3. Orders  (Trader_ID = ผู้ซื้อ)
-- ------------------------------------------------------------
INSERT INTO Orders (Order_ID, Trader_ID, orderDate, total_amount, Status) VALUES
( 1,  1, '2026-08-01 10:15:00',  500.00, 'Completed'),
( 2,  2, '2026-08-03 14:30:00', 1200.00, 'Completed'),
( 3,  3, '2026-08-05 09:00:00',  350.00, 'Shipped'),
( 4,  4, '2026-08-07 18:45:00', 2500.00, 'Paid'),
( 5,  5, '2026-08-09 11:20:00',  800.00, 'Pending'),
( 6,  6, '2026-08-10 16:05:00',  150.00, 'Completed'),
( 7,  7, '2026-08-12 13:40:00', 4200.00, 'Shipped'),
( 8,  8, '2026-08-14 20:10:00',  650.00, 'Cancelled'),
( 9,  9, '2026-08-15 08:55:00',  990.00, 'Completed'),
(10, 10, '2026-08-18 19:30:00',  300.00, 'Paid'),
(11, 11, '2026-08-20 12:00:00', 1800.00, 'Completed'),
(12, 12, '2026-08-22 15:15:00',   75.00, 'Pending'),
(13, 13, '2026-08-25 10:50:00', 3100.00, 'Shipped'),
(14, 14, '2026-08-27 17:25:00',  450.00, 'Completed'),
(15, 15, '2026-08-29 21:00:00', 1500.00, 'Cancelled'),
(16, 16, '2026-08-30 09:30:00',  650.00, 'Completed'),
(17, 17, '2026-08-31 14:00:00', 2200.00, 'Shipped'),
(18, 18, '2026-09-01 11:10:00',  420.00, 'Paid'),
(19, 19, '2026-09-02 16:40:00', 1750.00, 'Completed'),
(20, 20, '2026-09-03 19:20:00',  280.00, 'Pending');

-- ------------------------------------------------------------
--  4. Payment  (1 order : 1 payment, amount = total_amount)
-- ------------------------------------------------------------
INSERT INTO Payment (Order_ID, amount, payment_status, payment_date) VALUES
( 1,  500.00, 'Success',  '2026-08-01 10:20:00'),
( 2, 1200.00, 'Success',  '2026-08-03 14:35:00'),
( 3,  350.00, 'Success',  '2026-08-05 09:10:00'),
( 4, 2500.00, 'Success',  '2026-08-07 18:50:00'),
( 5,  800.00, 'Pending',  NULL),
( 6,  150.00, 'Success',  '2026-08-10 16:10:00'),
( 7, 4200.00, 'Success',  '2026-08-12 13:45:00'),
( 8,  650.00, 'Failed',   NULL),
( 9,  990.00, 'Success',  '2026-08-15 09:00:00'),
(10,  300.00, 'Success',  '2026-08-18 19:35:00'),
(11, 1800.00, 'Success',  '2026-08-20 12:05:00'),
(12,   75.00, 'Pending',  NULL),
(13, 3100.00, 'Success',  '2026-08-25 10:55:00'),
(14,  450.00, 'Success',  '2026-08-27 17:30:00'),
(15, 1500.00, 'Refunded', '2026-08-30 09:00:00'),
(16,  650.00, 'Success',  '2026-08-30 09:35:00'),
(17, 2200.00, 'Success',  '2026-08-31 14:05:00'),
(18,  420.00, 'Success',  '2026-09-01 11:15:00'),
(19, 1750.00, 'Success',  '2026-09-02 16:45:00'),
(20,  280.00, 'Pending',  NULL);

-- ------------------------------------------------------------
--  5. Shipment  (1 order : 1 shipment)
-- ------------------------------------------------------------
INSERT INTO Shipment (Order_ID, tracking_no, status, courier_name) VALUES
( 1, 'KER1000000001TH', 'Delivered', 'Kerry'),
( 2, 'FLS2000000002TH', 'Delivered', 'Flash'),
( 3, 'JNT3000000003TH', 'Shipped',   'J&T'),
( 4, NULL,              'Preparing', 'Kerry'),
( 5, NULL,              'Preparing', 'Flash'),
( 6, 'THP6000000006TH', 'Delivered', 'Thailand Post'),
( 7, 'KER7000000007TH', 'Shipped',   'Kerry'),
( 8, NULL,              'Preparing', 'J&T'),
( 9, 'FLS9000000009TH', 'Delivered', 'Flash'),
(10, NULL,              'Preparing', 'SCG Express'),
(11, 'SCG1100000011TH', 'Delivered', 'SCG Express'),
(12, NULL,              'Preparing', 'Thailand Post'),
(13, 'JNT1300000013TH', 'Shipped',   'J&T'),
(14, 'KER1400000014TH', 'Delivered', 'Kerry'),
(15, 'FLS1500000015TH', 'Returned',  'Flash'),
(16, 'KER1600000016TH', 'Delivered', 'Kerry'),
(17, 'FLS1700000017TH', 'Shipped',   'Flash'),
(18, NULL,              'Preparing', 'J&T'),
(19, 'THP1900000019TH', 'Delivered', 'Thailand Post'),
(20, NULL,              'Preparing', 'SCG Express');

-- ------------------------------------------------------------
--  6. Listing  (Trader_ID = ผู้ขาย, price = total_amount ของ order)
-- ------------------------------------------------------------
INSERT INTO Listing (Listing_ID, Trader_ID, Order_ID, price) VALUES
( 1,  2,  1,  500.00),
( 2,  3,  2, 1200.00),
( 3,  4,  3,  350.00),
( 4,  5,  4, 2500.00),
( 5,  6,  5,  800.00),
( 6,  7,  6,  150.00),
( 7,  8,  7, 4200.00),
( 8,  9,  8,  650.00),
( 9, 10,  9,  990.00),
(10, 11, 10,  300.00),
(11, 12, 11, 1800.00),
(12, 13, 12,   75.00),
(13, 14, 13, 3100.00),
(14, 15, 14,  450.00),
(15, 16, 15, 1500.00),
(16, 17, 16,  650.00),
(17, 18, 17, 2200.00),
(18, 19, 18,  420.00),
(19, 20, 19, 1750.00),
(20,  1, 20,  280.00);

-- ------------------------------------------------------------
--  7. Items  (Item 1-14 = Card, Item 15-20 = Boxset)
-- ------------------------------------------------------------
INSERT INTO Items (Item_ID, Listing_ID, ItemType, ItemName, Series, Description) VALUES
( 1,  1, 'Card',   'Flame Dragon',               'Dragon Saga',      'Fire dragon with 3000 ATK'),
( 2,  2, 'Card',   'Ice Witch',                  'Frozen Realm',     'Freezes one opponent card for 2 turns'),
( 3,  3, 'Card',   'Shadow Assassin',            'Night Blade',      'Can attack directly from the shadows'),
( 4,  4, 'Card',   'Golden Phoenix',             'Dragon Saga',      'Revives once per match'),
( 5,  5, 'Card',   'Thunder Mage',               'Storm Chronicle',  'Deals chain lightning damage'),
( 6,  6, 'Card',   'Healing Fairy',              'Forest Tales',     'Restores 500 HP each turn'),
( 7,  7, 'Card',   'Iron Golem',                 'Steel Legion',     'High defense, immune to spells'),
( 8,  8, 'Card',   'Moonlight Blade',            'Night Blade',      'Legendary sword, +1000 ATK'),
( 9,  9, 'Card',   'Ocean Guardian',             'Deep Blue',        'Protects all allied monsters'),
(10, 10, 'Card',   'Cursed Mirror',              'Night Blade',      'Reflects the next attack'),
(11, 11, 'Card',   'Crimson Knight',             'Steel Legion',     'Gains +500 ATK each time it attacks'),
(12, 12, 'Card',   'Frost Wolf',                 'Frozen Realm',     'Summons a wolf token every turn'),
(13, 13, 'Card',   'Storm Caller',               'Storm Chronicle',  'Draw 2 cards when a spell is played'),
(14, 14, 'Card',   'Shield of Dawn',             'Dragon Saga',      'Negates the next 1000 damage'),
(15, 15, 'Boxset', 'Dragon Saga Starter Box',    'Dragon Saga',      'Starter deck with 40 cards'),
(16, 16, 'Boxset', 'Frozen Realm Booster Box',   'Frozen Realm',     'Booster box with 60 cards'),
(17, 17, 'Boxset', 'Night Blade Collector Box',  'Night Blade',      'Collector edition with 36 cards'),
(18, 18, 'Boxset', 'Storm Chronicle Deluxe Set', 'Storm Chronicle',  'Deluxe set with 50 cards'),
(19, 19, 'Boxset', 'Forest Tales Mini Box',      'Forest Tales',     'Mini box with 20 cards'),
(20, 20, 'Boxset', 'Deep Blue Premium Box',      'Deep Blue',        'Premium box with 45 cards');

-- ------------------------------------------------------------
--  8. Card  (subtype, 14 แถว)
-- ------------------------------------------------------------
INSERT INTO Card (Item_ID, ItemType, Rarity, CardType) VALUES
( 1, 'Card', 'SSR', 'Monster'),
( 2, 'Card', 'SR',  'Spell'),
( 3, 'Card', 'R',   'Monster'),
( 4, 'Card', 'UR',  'Monster'),
( 5, 'Card', 'SR',  'Monster'),
( 6, 'Card', 'N',   'Support'),
( 7, 'Card', 'R',   'Monster'),
( 8, 'Card', 'SSR', 'Equipment'),
( 9, 'Card', 'SR',  'Monster'),
(10, 'Card', 'R',   'Trap'),
(11, 'Card', 'R',   'Monster'),
(12, 'Card', 'SR',  'Monster'),
(13, 'Card', 'R',   'Spell'),
(14, 'Card', 'SR',  'Equipment');

-- ------------------------------------------------------------
--  9. Boxset  (subtype, 6 แถว)
-- ------------------------------------------------------------
INSERT INTO Boxset (Item_ID, ItemType, ReleaseDate, TotalCards) VALUES
(15, 'Boxset', '2024-03-15', 40),
(16, 'Boxset', '2024-07-01', 60),
(17, 'Boxset', '2025-01-20', 36),
(18, 'Boxset', '2025-05-10', 50),
(19, 'Boxset', '2025-09-05', 20),
(20, 'Boxset', '2025-12-12', 45);

-- ------------------------------------------------------------
-- 10. Includes  (prize pool, ผลรวม probability ต่อกาชา = 1.0000)
--     Gacha 1 = Item 1-4, Gacha 2 = Item 5-8, Gacha 3 = Item 9-12,
--     Gacha 4 = Item 13-16, Gacha 5 = Item 17-20
-- ------------------------------------------------------------
INSERT INTO Includes (Gacha_ID, Item_ID, probability) VALUES
(1,  1, 0.0500),
(1,  2, 0.1500),
(1,  3, 0.3000),
(1,  4, 0.5000),
(2,  5, 0.0100),
(2,  6, 0.0900),
(2,  7, 0.3000),
(2,  8, 0.6000),
(3,  9, 0.0500),
(3, 10, 0.1500),
(3, 11, 0.2500),
(3, 12, 0.5500),
(4, 13, 0.1000),
(4, 14, 0.2000),
(4, 15, 0.3000),
(4, 16, 0.4000),
(5, 17, 0.0500),
(5, 18, 0.1000),
(5, 19, 0.3500),
(5, 20, 0.5000);

-- ------------------------------------------------------------
-- 11. Own  (inventory)
-- ------------------------------------------------------------
INSERT INTO Own (Trader_ID, Item_ID, quantity) VALUES
( 1,  1, 1),
( 1,  3, 3),
( 2,  2, 2),
( 3,  4, 1),
( 4,  5, 1),
( 5,  6, 5),
( 6,  7, 1),
( 7,  8, 1),
( 8,  9, 2),
( 9, 10, 4),
(10, 11, 1),
(11, 12, 1),
(12, 13, 1),
(13, 14, 2),
(14, 15, 1),
(15, 16, 1),
(16, 17, 3),
(17, 18, 1),
(18, 19, 2),
(19, 20, 1);

-- ------------------------------------------------------------
-- 12. Open  (การเปิดกาชา 1 แถว = 1 ครั้ง, Item ต้องอยู่ใน pool ของกาชานั้น)
-- ------------------------------------------------------------
INSERT INTO Open (Open_ID, Trader_ID, Gacha_ID, Item_ID, date_opened) VALUES
( 1,  1, 1,  3, '2026-09-05 10:00:00'),
( 2,  2, 1,  2, '2026-09-05 11:30:00'),
( 3,  3, 1,  1, '2026-09-06 09:15:00'),
( 4,  4, 1,  4, '2026-09-06 14:20:00'),
( 5,  5, 2,  8, '2026-09-07 16:45:00'),
( 6,  6, 2,  7, '2026-09-08 12:10:00'),
( 7,  7, 2,  5, '2026-09-08 18:00:00'),
( 8,  8, 2,  6, '2026-09-09 20:30:00'),
( 9,  9, 3, 12, '2026-09-10 08:40:00'),
(10, 10, 3, 11, '2026-09-10 13:25:00'),
(11, 11, 3,  9, '2026-09-11 15:50:00'),
(12, 12, 3, 10, '2026-09-12 19:05:00'),
(13, 13, 4, 16, '2026-09-13 10:35:00'),
(14, 14, 4, 15, '2026-09-14 17:15:00'),
(15, 15, 4, 13, '2026-09-15 21:45:00'),
(16, 16, 4, 14, '2026-09-16 09:50:00'),
(17, 17, 5, 20, '2026-09-17 11:40:00'),
(18, 18, 5, 19, '2026-09-18 14:55:00'),
(19, 19, 5, 17, '2026-09-19 18:20:00'),
(20, 20, 5, 18, '2026-09-20 22:10:00');