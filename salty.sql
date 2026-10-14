-- ============================================================
--  Card Marketplace  (MySQL 8.0.16+ : CHECK constraints enforced)
--
--  Business-rule enforcement summary
--    BR1, BR2, BR4, BR6 ........ FK / junction tables
--    BR3  (Listing -> exactly 1 Order) ..... Listing.Order_ID NOT NULL
--    BR14 (Item    -> exactly 1 Listing) ... Items.Listing_ID NOT NULL
--    BR10 ...................... CHECK (price > 0)
--    BR11 ...................... CHECK (total_amount > 0)
--    BR12 ...................... ENUM('Active','Closed')
--    BR13 ...................... composite FK (Item_ID, ItemType)
--    BR14 ...................... ENUM('Pending','Paid','Shipped','Cancelled','Completed')
--    BR15 (Item -> exactly 1 Listing) ... Items.Listing_ID NOT NULL
--    BR3, BR5, BR7, BR8, BR9 ... "at least one / exactly one" on the
--                                mandatory side cannot be declared in
--                                DDL -> enforce in a transaction or
--                                stored procedure (see example at end)
--
--  Insert order for a sale:  Orders -> Listing -> Items
-- ============================================================

DROP DATABASE IF EXISTS card_marketplace;
CREATE DATABASE card_marketplace;
USE card_marketplace;

-- ------------------------------------------------------------
--  1. Independent / top-level tables
-- ------------------------------------------------------------

CREATE TABLE Trader (
    Trader_ID   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    Trader_Name VARCHAR(100)  NOT NULL,
    Email       VARCHAR(150)  NOT NULL,
    Phone       VARCHAR(20)   NULL,
    Address     VARCHAR(255)  NULL,
    PRIMARY KEY (Trader_ID),
    UNIQUE (Email)
);

CREATE TABLE Gacha (
    Gacha_ID    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    Name        VARCHAR(100)  NOT NULL,
    Status      ENUM('Active', 'Inactive') NOT NULL DEFAULT 'Inactive',   -- BR12
    Price       DECIMAL(10,2) NOT NULL,
    Stock       INT UNSIGNED  NOT NULL DEFAULT 0,
    PRIMARY KEY (Gacha_ID)
);

-- ------------------------------------------------------------
--  2. Marketplace core: Orders -> Listing -> Items
-- ------------------------------------------------------------

-- Trader (buyer) PLACES an Order
CREATE TABLE Orders (
    Order_ID     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    Trader_ID    INT UNSIGNED  NOT NULL,                 -- buyer (BR1)
    orderDate    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10,2) NOT NULL,
    Status       ENUM('Pending', 'Paid', 'Shipped', 'Completed', 'Cancelled')
                               NOT NULL DEFAULT 'Pending',  --  BR14
    PRIMARY KEY (Order_ID),
    FOREIGN KEY (Trader_ID) REFERENCES Trader (Trader_ID),
    CONSTRAINT ck_orders_total CHECK (total_amount > 0)   -- BR11   
);

-- Trader (seller) CREATES a Listing; every Listing belongs to exactly one Order (BR2, BR3)
CREATE TABLE Listing (
    Listing_ID INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    Trader_ID  INT UNSIGNED  NOT NULL,                   -- seller
    Order_ID   INT UNSIGNED  NOT NULL,                   -- BR3
    price      DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (Listing_ID),
    FOREIGN KEY (Trader_ID) REFERENCES Trader (Trader_ID),
    FOREIGN KEY (Order_ID)  REFERENCES Orders (Order_ID),
    CONSTRAINT ck_listing_price CHECK (price > 0)        --  BR10
);

CREATE TABLE Items (
    Item_ID     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    Listing_ID  INT UNSIGNED  NOT NULL,      -- BR15           
    ItemType    ENUM('Card', 'Boxset') NOT NULL,
    ItemName    VARCHAR(150)  NOT NULL,
    Series      VARCHAR(100)  NULL,
    Description TEXT          NULL,
    PRIMARY KEY (Item_ID),
    UNIQUE (Item_ID, ItemType),                          -- target of BR13 composite FKs
    FOREIGN KEY (Listing_ID) REFERENCES Listing (Listing_ID)
);

-- ------------------------------------------------------------
--  3. Subtypes of Items (disjoint, shared primary key)  -- BR13
-- ------------------------------------------------------------

CREATE TABLE Card (
    Item_ID   INT UNSIGNED  NOT NULL,
    ItemType  ENUM('Card', 'Boxset') NOT NULL DEFAULT 'Card',
    Rarity    VARCHAR(30)   NOT NULL,
    CardType  VARCHAR(50)   NOT NULL,
    PRIMARY KEY (Item_ID),
    CONSTRAINT ck_card_type CHECK (ItemType = 'Card'),
    FOREIGN KEY (Item_ID, ItemType) REFERENCES Items (Item_ID, ItemType)
);

CREATE TABLE Boxset (
    Item_ID     INT UNSIGNED  NOT NULL,
    ItemType    ENUM('Card', 'Boxset') NOT NULL DEFAULT 'Boxset',
    ReleaseDate DATE          NULL,
    TotalCards  INT UNSIGNED  NOT NULL DEFAULT 1,
    PRIMARY KEY (Item_ID),
    CONSTRAINT ck_boxset_type CHECK (ItemType = 'Boxset'),
    FOREIGN KEY (Item_ID, ItemType) REFERENCES Items (Item_ID, ItemType)
);

-- ------------------------------------------------------------
--  4. Gacha and inventory relationships
-- ------------------------------------------------------------

-- Gacha INCLUDES Items (prize pool)  (BR5)
CREATE TABLE Includes (
    Gacha_ID    INT UNSIGNED  NOT NULL,
    Item_ID     INT UNSIGNED  NOT NULL,
    probability DECIMAL(5,4)  NOT NULL DEFAULT 0,        -- e.g. 0.0250 = 2.5%
    PRIMARY KEY (Gacha_ID, Item_ID),
    FOREIGN KEY (Gacha_ID) REFERENCES Gacha (Gacha_ID),
    FOREIGN KEY (Item_ID)  REFERENCES Items (Item_ID),
    CONSTRAINT ck_includes_rate CHECK (probability BETWEEN 0 AND 1)
);

-- Trader OWNS Items (inventory)  (BR6)
CREATE TABLE Own (
    Trader_ID INT UNSIGNED NOT NULL,
    Item_ID   INT UNSIGNED NOT NULL,
    quantity  INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (Trader_ID, Item_ID),
    FOREIGN KEY (Trader_ID) REFERENCES Trader (Trader_ID),
    FOREIGN KEY (Item_ID)   REFERENCES Items (Item_ID),
    CONSTRAINT ck_own_qty CHECK (quantity > 0)
);

-- Trader OPENS Gacha (each pull is one row -> surrogate key)  (BR4)
CREATE TABLE Open (
    Open_ID     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    Trader_ID   INT UNSIGNED NOT NULL,
    Gacha_ID    INT UNSIGNED NOT NULL,
    Item_ID     INT UNSIGNED NOT NULL,                   -- item received
    date_opened TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (Open_ID),
    FOREIGN KEY (Trader_ID) REFERENCES Trader (Trader_ID),
    FOREIGN KEY (Gacha_ID)  REFERENCES Gacha (Gacha_ID),
    FOREIGN KEY (Item_ID)   REFERENCES Items (Item_ID)
);

-- ------------------------------------------------------------
--  5. Order details (weak entities of Orders)
-- ------------------------------------------------------------

-- Order has exactly one Payment  (BR7)
CREATE TABLE Payment (
    Order_ID       INT UNSIGNED  NOT NULL,
    amount         DECIMAL(10,2) NOT NULL,
    payment_status ENUM('Pending', 'Success', 'Failed', 'Refunded')
                                 NOT NULL DEFAULT 'Pending',
    payment_date   DATETIME      NULL,
    PRIMARY KEY (Order_ID),
    FOREIGN KEY (Order_ID) REFERENCES Orders (Order_ID),
    CONSTRAINT ck_payment_amount CHECK (amount >= 0)
);

-- Order has exactly one Shipment  (BR8)
CREATE TABLE Shipment (
    Order_ID     INT UNSIGNED NOT NULL,
    tracking_no  VARCHAR(100) NULL,
    status       ENUM('Preparing', 'Shipped', 'Delivered', 'Returned')
                              NOT NULL DEFAULT 'Preparing',
    courier_name VARCHAR(100) NOT NULL,
    PRIMARY KEY (Order_ID),
    FOREIGN KEY (Order_ID) REFERENCES Orders (Order_ID)
);


-- ------------------------------------------------------------
--  6. EXAMPLE (commented out): creating a sale in one transaction
--     BR3, BR7, BR8, BR9 are satisfied because everything is
--     inserted together in the order  Orders -> Payment/Shipment
--     -> Listing -> Items.   Assumes Trader 1 (buyer) and
--     Trader 2 (seller) already exist.
-- ------------------------------------------------------------
/*
START TRANSACTION;

INSERT INTO Orders (Trader_ID, total_amount) VALUES (1, 500.00);
SET @oid = LAST_INSERT_ID();

INSERT INTO Payment  (Order_ID, amount)                VALUES (@oid, 500.00);   -- BR7
INSERT INTO Shipment (Order_ID, courier_name)          VALUES (@oid, 'Kerry');  -- BR8

INSERT INTO Listing (Trader_ID, Order_ID, price)       VALUES (2, @oid, 500.00);
SET @lid = LAST_INSERT_ID();

INSERT INTO Items (Listing_ID, ItemType, ItemName)     VALUES (@lid, 'Card', 'Dragon');  -- BR9
SET @iid = LAST_INSERT_ID();
INSERT INTO Card (Item_ID, Rarity, CardType)           VALUES (@iid, 'SSR', 'Monster');

COMMIT;
*/