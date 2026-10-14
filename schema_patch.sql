-- Run AFTER salty.sql (schema) and, optionally, Insert_info_salty_project.sql (mock data)
USE card_marketplace;

-- 1) A listing must be able to exist BEFORE anyone orders it.
--    (Original DDL had Listing.Order_ID NOT NULL and Items.Listing_ID NOT NULL,
--     which makes "create listing -> add to cart -> checkout" impossible.)
ALTER TABLE Listing MODIFY Order_ID   INT UNSIGNED NULL;
ALTER TABLE Items   MODIFY Listing_ID INT UNSIGNED NULL;

-- 2) Columns the UI uses that the schema does not have yet
ALTER TABLE Payment  ADD COLUMN method  VARCHAR(50)  NULL;
ALTER TABLE Shipment ADD COLUMN address VARCHAR(255) NULL;
ALTER TABLE Shipment MODIFY courier_name VARCHAR(100) NULL;   -- unknown until the seller ships

-- 3) Product photos (stored as data-URL text for now; move to files/S3 later)
ALTER TABLE Items ADD COLUMN Image MEDIUMTEXT NULL;
ALTER TABLE Gacha ADD COLUMN Image MEDIUMTEXT NULL;

-- 4) Helpful indexes
CREATE INDEX ix_listing_order  ON Listing (Order_ID);
CREATE INDEX ix_items_listing  ON Items (Listing_ID);
CREATE INDEX ix_open_gacha     ON Open (Gacha_ID);
