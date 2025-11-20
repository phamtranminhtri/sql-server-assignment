------------------------------------------------------------
-- TẠO DATABASE
------------------------------------------------------------
USE master;

IF DB_ID('MyDatabase') IS NOT NULL
    DROP DATABASE MyDatabase;
GO

CREATE DATABASE MyDatabase;
GO

USE MyDatabase;
GO

SET QUOTED_IDENTIFIER ON;
GO

------------------------------------------------------------
-- USER & AUTHENTICATION
------------------------------------------------------------

CREATE TABLE [User](
    email               NVARCHAR(255) PRIMARY KEY,
    fname               NVARCHAR(100),
    mname               NVARCHAR(100),
    lname               NVARCHAR(100),
    phone               NVARCHAR(20),
    registration_date   DATE NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE User_Address(
    address_id          INT IDENTITY(1,1) PRIMARY KEY,
    email               NVARCHAR(255) NOT NULL,
    house_number        INT,
    street              NVARCHAR(100),
    commune_or_district NVARCHAR(100),
    province_or_city    NVARCHAR(100),
    is_default          BIT DEFAULT 0,

    CONSTRAINT fk_useraddress_user
        FOREIGN KEY (email) REFERENCES [User](email)
        ON DELETE CASCADE
);
GO


------------------------------------------------------------
-- CUSTOMER & SELLER
------------------------------------------------------------

CREATE TABLE Customer(
    customer_seq    INT IDENTITY(1,1) NOT NULL,
    customer_id     AS (CAST('CUS' + RIGHT('0000' + CAST(customer_seq as VARCHAR(4)), 4) AS VARCHAR(8))) PERSISTED,
    email           NVARCHAR(255) NOT NULL,
    PRIMARY KEY (customer_id),
    CONSTRAINT uq_customer_seq UNIQUE(customer_seq),
    CONSTRAINT uq_customer_email UNIQUE(email),
    CONSTRAINT fk_customer_user
        FOREIGN KEY (email) REFERENCES [User](email)
        ON DELETE CASCADE
);
GO

CREATE TABLE Seller(
    seller_seq   INT IDENTITY(1,1) NOT NULL,
    seller_id   AS (CAST('SEL' + RIGHT('0000' + CAST(seller_seq as VARCHAR(4)), 4) AS VARCHAR(8))) PERSISTED,
    email       NVARCHAR(255) NOT NULL,
    store_name  NVARCHAR(100) NOT NULL,
    join_date   DATE NOT NULL DEFAULT GETDATE(),

    PRIMARY KEY (seller_id),
    CONSTRAINT uq_seller_seq UNIQUE(seller_seq),
    CONSTRAINT uq_seller_email UNIQUE(email),
    CONSTRAINT fk_seller_user
        FOREIGN KEY (email) REFERENCES [User](email)
        ON DELETE CASCADE
);
GO


------------------------------------------------------------
-- CATEGORY & PRODUCT
------------------------------------------------------------

CREATE TABLE Category(
    category_id         INT IDENTITY(1,1) PRIMARY KEY,
    name                NVARCHAR(100) NOT NULL,
    parent_category_id  INT,

    CONSTRAINT uq_category_name UNIQUE(name),
    CONSTRAINT fk_category_parent
        FOREIGN KEY(parent_category_id) REFERENCES Category(category_id)
        ON DELETE NO ACTION
);
GO

CREATE TABLE Product(
    product_id      INT IDENTITY(1,1) PRIMARY KEY,
    seller_id       VARCHAR(8) NOT NULL,
    name            NVARCHAR(255) NOT NULL,
    description     NVARCHAR(MAX),
    price           DECIMAL(12,2) NOT NULL,
    stock_quantity  INT NOT NULL DEFAULT 0,
    upload_date     DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT fk_product_seller
        FOREIGN KEY(seller_id) REFERENCES Seller(seller_id),
    CONSTRAINT chk_product_price
        CHECK (price >= 0),
    CONSTRAINT chk_product_stock
        CHECK (stock_quantity >= 0)
);
GO

-- belong to --
CREATE TABLE Product_Category(
    product_id INT NOT NULL,
    category_id INT NOT NULL,

    PRIMARY KEY(product_id, category_id),
    CONSTRAINT fk_pc_product
        FOREIGN KEY(product_id) REFERENCES Product(product_id),
    CONSTRAINT fk_pc_category
        FOREIGN KEY(category_id) REFERENCES Category(category_id)
);
GO


------------------------------------------------------------
-- VOUCHER
------------------------------------------------------------

CREATE TABLE Voucher(
    code VARCHAR(10) PRIMARY KEY,
    min_value DECIMAL(12,2) NOT NULL DEFAULT 0,
    discount_value DECIMAL(12, 2) NOT NULL,
    quantity INT NOT NULL,
    start_date  DATE NOT NULL,
    end_date    DATE NOT NULL,
    validation_time INT, -- số ngày hiệu lực
    description NVARCHAR(500),

    CONSTRAINT chk_voucher_dates
        CHECK (end_date >= start_date),
    CONSTRAINT chk_voucher_discount
        CHECK (discount_value >= 0),
    CONSTRAINT chk_voucher_quantity
        CHECK (quantity >= 0)
);
GO

-- receive --
CREATE TABLE Customer_Voucher(
    customer_id VARCHAR(8) NOT NULL,
    voucher_code VARCHAR(10) NOT NULL,

    PRIMARY KEY (customer_id, voucher_code),
    CONSTRAINT fk_cv_customer
        FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    CONSTRAINT fk_cv_voucher
        FOREIGN KEY (voucher_code) REFERENCES Voucher(code)
);
GO



------------------------------------------------------------
-- ORDER & ORDER DETAIL
------------------------------------------------------------

CREATE TABLE [Order] (
    order_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id VARCHAR(8) NOT NULL,
    status_ NVARCHAR(50) NOT NULL DEFAULT N'PENDING',
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    order_date DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    CONSTRAINT chk_order_total
        CHECK (total_amount >= 0),
    CONSTRAINT chk_order_status
        CHECK (status_ IN (N'PENDING', N'CONFIRMED', N'SHIPPING', N'DELIVERED', N'CANCELLED'))
);
GO

CREATE TABLE OrderDetail(
    orderdetail_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    unit_price DECIMAL(12,2) NOT NULL,
    quantity INT NOT NULL,

    CONSTRAINT fk_orderdetail_order
        FOREIGN KEY (order_id) REFERENCES [Order](order_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_orderdetail_product
        FOREIGN KEY(product_id) REFERENCES Product(product_id),
    CONSTRAINT chk_orderdetail_price
        CHECK (unit_price >= 0),
    CONSTRAINT chk_orderdetail_quantity
        CHECK (quantity > 0)
);
GO

-- Include --
CREATE TABLE Product_OrderDetail (
    orderdetail_id  INT     NOT NULL,
    order_id        INT     NOT NULL,
    product_id      INT     NOT NULL,
    PRIMARY KEY (orderdetail_id, order_id, product_id),
    CONSTRAINT fk_po_orderdetail
        FOREIGN KEY (orderdetail_id)    REFERENCES OrderDetail(orderdetail_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_po_orderid
        FOREIGN KEY (order_id)    REFERENCES [Order](order_id),
    CONSTRAINT fk_po_productid
        FOREIGN KEY (product_id)    REFERENCES Product(product_id)
);
GO

-- Apply --
CREATE TABLE Order_Voucher(
    order_id INT NOT NULL,
    voucher_code VARCHAR(10) NOT NULL,

    PRIMARY KEY (order_id, voucher_code),
    CONSTRAINT fk_ov_order
        FOREIGN KEY (order_id) REFERENCES [Order](order_id),
    CONSTRAINT fk_ov_voucher
        FOREIGN KEY (voucher_code) REFERENCES Voucher(code)
);
GO


------------------------------------------------------------
-- PAYMENT
------------------------------------------------------------

CREATE TABLE Payment (
    payment_id    INT IDENTITY(1,1) PRIMARY KEY,
    order_id      INT NOT NULL,
    amount        DECIMAL(12,2) NOT NULL,
    method        NVARCHAR(20) NOT NULL,
    payment_date  DATETIME NOT NULL DEFAULT GETDATE(),
    status        NVARCHAR(20) NOT NULL DEFAULT 'UNPAID',
    
    CONSTRAINT uq_payment_order UNIQUE (order_id),
    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id) REFERENCES [Order](order_id)
        ON DELETE CASCADE,
    CONSTRAINT chk_payment_amount
        CHECK (amount >= 0),
    CONSTRAINT chk_payment_method
        CHECK (method IN ('CREDIT_CARD','CASH','WALLET','BANK_TRANSFER')),
    CONSTRAINT chk_payment_status
        CHECK (status IN ('UNPAID','PAID','FAILED'))
);
GO


------------------------------------------------------------
-- SHIPMENT & CARRIER
------------------------------------------------------------

CREATE TABLE Carrier_Company (
    company_name NVARCHAR(100) PRIMARY KEY,
    carrier_id   INT NOT NULL
);
GO

CREATE TABLE Shipment (
    shipment_id        INT IDENTITY(1,1) PRIMARY KEY,
    order_id           INT NOT NULL,
    company_name       NVARCHAR(100) NOT NULL,
    tracking_code      NVARCHAR(50),
    shipment_fee       DECIMAL(12,2) NOT NULL DEFAULT 0,
    is_cod             BIT DEFAULT 0,
    recipient_address  NVARCHAR(500) NOT NULL,
    recipient_name     NVARCHAR(200) NOT NULL,
    delivery_deadline  DATETIME,
    
    CONSTRAINT fk_shipment_order
        FOREIGN KEY (order_id) REFERENCES [Order](order_id),
    CONSTRAINT fk_shipment_carrier
        FOREIGN KEY (company_name) REFERENCES Carrier_Company(company_name),
    CONSTRAINT chk_shipment_fee
        CHECK (shipment_fee >= 0)
);
GO


------------------------------------------------------------
-- REVIEW
------------------------------------------------------------

CREATE TABLE Review (
    review_id    INT IDENTITY(1,1) NOT NULL,
    customer_id  VARCHAR(8) NOT NULL,
    product_id   INT NOT NULL,
    rating       INT NOT NULL,
    comment      NVARCHAR(MAX),
    review_date  DATETIME NOT NULL DEFAULT GETDATE(),

    PRIMARY KEY (review_id, customer_id),

    CONSTRAINT fk_review_customer
        FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    CONSTRAINT fk_review_product
        FOREIGN KEY (product_id) REFERENCES Product(product_id),
    CONSTRAINT chk_review_rating
        CHECK (rating BETWEEN 1 AND 5)
);
GO


------------------------------------------------------------
-- INSERT DATA
------------------------------------------------------------

------------------------------------------------------------
-- USER
------------------------------------------------------------

INSERT INTO [User] (email, fname, mname, lname, phone, registration_date) VALUES
('alice.nguyen@example.com',  N'Alice', NULL, N'Nguyen', '0901000001', '2025-01-05'),
('bob.tran@example.com',     N'Bob',   NULL, N'Tran',   '0901000002', '2025-01-10'),
('carol.le@example.com',    N'Carol', NULL, N'Le',     '0901000003', '2025-01-15'),
('david.pham@example.com',  N'David', NULL, N'Pham',   '0901000004', '2025-02-01'),
('eve.hoang@example.com',   N'Eve',   NULL, N'Hoang',  '0901000005', '2025-02-10'),
('frank.vo@example.com',    N'Frank', NULL, N'Vo',     '0901000006', '2025-02-12');
GO


------------------------------------------------------------
-- USER_ADDRESS
------------------------------------------------------------

INSERT INTO User_Address (email, house_number, street, commune_or_district, province_or_city, is_default) VALUES
('alice.nguyen@example.com',  123, N'Le Loi',       N'District 1',  N'Ho Chi Minh City', 1),
('alice.nguyen@example.com',   45, N'Nguyen Hue',   N'District 1',  N'Ho Chi Minh City', 0),
('bob.tran@example.com',       78, N'Pham Van Dong',N'Thu Duc',    N'Ho Chi Minh City', 1),
('carol.le@example.com',       12, N'Vo Van Ngan',  N'Thu Duc',    N'Ho Chi Minh City', 1),
('david.pham@example.com',     56, N'Tran Hung Dao',N'District 5', N'Ho Chi Minh City', 1),
('eve.hoang@example.com',      90, N'Nguyen Trai',  N'District 5', N'Ho Chi Minh City', 1);
GO


------------------------------------------------------------
-- CUSTOMER
------------------------------------------------------------

-- Sẽ sinh ra:
-- CUS0001, CUS0002, CUS0003, CUS0004
INSERT INTO Customer (email) VALUES
('alice.nguyen@example.com'),
('bob.tran@example.com'),
('carol.le@example.com'),
('eve.hoang@example.com');
GO


------------------------------------------------------------
-- SELLER
------------------------------------------------------------

-- Sẽ sinh ra: SEL0001, SEL0002, SEL0003
INSERT INTO Seller (email, store_name, join_date) VALUES
('carol.le@example.com',   N'Carol Tech Store', '2025-02-01'),
('david.pham@example.com', N'David Laptop Hub', '2025-02-05'),
('frank.vo@example.com',   N'Frank Fashion',    '2025-02-10');
GO


------------------------------------------------------------
-- CATEGORY
------------------------------------------------------------

-- Giả định IDENTITY chạy: 1..n theo thứ tự insert
INSERT INTO Category (name, parent_category_id) VALUES
(N'Electronics',       NULL),   -- 1
(N'Phones',            1),      -- 2
(N'Laptops',           1),      -- 3
(N'Fashion',           NULL),   -- 4
(N'Men''s Clothing',    4),      -- 5
(N'Women''s Clothing',  4);      -- 6
GO


------------------------------------------------------------
-- PRODUCT
------------------------------------------------------------

-- seller_id: SEL0001, SEL0002, SEL0003
INSERT INTO Product (seller_id, name, description, price, stock_quantity, upload_date) VALUES
('SEL0001', N'iPhone 15 128GB',      N'Apple iPhone 15 VN/A, full box, chính hãng.', 25000000, 10, '2025-03-01'),
('SEL0001', N'Samsung Galaxy S24',   N'Galaxy S24 5G, bảo hành chính hãng.',        22000000, 15, '2025-03-02'),
('SEL0002', N'MacBook Air M2 13"',   N'MacBook Air M2, 8GB RAM, 256GB SSD.',        30000000, 5,  '2025-03-05'),
('SEL0002', N'Dell XPS 13',          N'Ultrabook XPS 13, màn đẹp, mỏng nhẹ.',       28000000, 7,  '2025-03-06'),
('SEL0003', N'Uniqlo Men T-Shirt',   N'Áo thun nam Uniqlo cotton.',                  250000,  100,'2025-03-03'),
('SEL0003', N'Zara Women Dress',     N'Đầm nữ Zara, thiết kế trẻ trung.',           750000,  50, '2025-03-04');
GO
-- Giả định product_id: 1..6 theo thứ tự trên


------------------------------------------------------------
-- PRODUCT_CATEGORY
------------------------------------------------------------

INSERT INTO Product_Category (product_id, category_id) VALUES
(1, 2), -- iPhone -> Phones
(2, 2), -- Galaxy -> Phones
(3, 3), -- MacBook -> Laptops
(4, 3), -- Dell -> Laptops
(5, 5), -- Uniqlo T-Shirt -> Men's Clothing
(6, 6), -- Zara Dress -> Women's Clothing
(1, 1), -- iPhone cũng thuộc Electronics
(2, 1); -- Galaxy cũng thuộc Electronics
GO


------------------------------------------------------------
-- VOUCHER
------------------------------------------------------------

INSERT INTO Voucher (code, min_value, discount_value, quantity, start_date, end_date, validation_time, description) VALUES
('WELCOME10',  0,       100000, 100, '2025-01-01', '2025-12-31', 30, N'Voucher 100k cho khách hàng mới'),
('FREESHIP',   300000,   30000, 200, '2025-01-01', '2025-12-31', 7,  N'Hỗ trợ phí vận chuyển 30k'),
('VIP20',      10000000,500000,  50, '2025-02-01', '2025-12-31', 14, N'Voucher giảm cho đơn lớn'),
('WEEKEND5',   500000,   50000, 150, '2025-03-01', '2025-09-30', 3,  N'Voucher cuối tuần');
GO


------------------------------------------------------------
-- CUSTOMER_VOUCHER
------------------------------------------------------------

-- customer_id tương ứng với mail:
-- CUS0001: alice, CUS0002: bob, CUS0003: carol, CUS0004: eve
INSERT INTO Customer_Voucher (customer_id, voucher_code) VALUES
('CUS0001', 'WELCOME10'),
('CUS0001', 'FREESHIP'),
('CUS0002', 'WELCOME10'),
('CUS0002', 'WEEKEND5'),
('CUS0003', 'VIP20'),
('CUS0004', 'FREESHIP');
GO


------------------------------------------------------------
-- ORDER
------------------------------------------------------------

-- Giả định order_id sẽ là 1..5 theo thứ tự
INSERT INTO [Order] (customer_id, status_, total_amount, order_date) VALUES
('CUS0001', N'DELIVERED', 25000000, '2025-03-10 10:00:00'), -- 1: 1 x iPhone
('CUS0002', N'SHIPPING',  22500000, '2025-03-11 14:30:00'), -- 2: 1 x Galaxy + 2 x T-shirt
('CUS0003', N'CONFIRMED', 30000000, '2025-03-12 09:15:00'), -- 3: 1 x MacBook
('CUS0004', N'DELIVERED',   750000, '2025-03-13 16:45:00'), -- 4: 1 x Zara Dress
('CUS0001', N'PENDING',   50000000, '2025-03-14 11:20:00'); -- 5: 1 x Dell + 1 x Galaxy
GO


------------------------------------------------------------
-- ORDERDETAIL
------------------------------------------------------------

-- Giả định orderdetail_id: 1..7 theo thứ tự insert

-- Order 1: 1 x iPhone
INSERT INTO OrderDetail (order_id, product_id, unit_price, quantity) VALUES
(1, 1, 25000000, 1);

-- Order 2: 1 x Galaxy + 2 x T-Shirt
INSERT INTO OrderDetail (order_id, product_id, unit_price, quantity) VALUES
(2, 2, 22000000, 1),  -- od_id = 2
(2, 5,   250000, 2);  -- od_id = 3

-- Order 3: 1 x MacBook
INSERT INTO OrderDetail (order_id, product_id, unit_price, quantity) VALUES
(3, 3, 30000000, 1);  -- od_id = 4

-- Order 4: 1 x Zara Dress
INSERT INTO OrderDetail (order_id, product_id, unit_price, quantity) VALUES
(4, 6,   750000, 1);  -- od_id = 5

-- Order 5: 1 x Dell + 1 x Galaxy
INSERT INTO OrderDetail (order_id, product_id, unit_price, quantity) VALUES
(5, 4, 28000000, 1),  -- od_id = 6
(5, 2, 22000000, 1);  -- od_id = 7
GO


------------------------------------------------------------
-- PRODUCT_ORDERDETAIL
------------------------------------------------------------

-- Map 1-1 cho dễ hiểu
INSERT INTO Product_OrderDetail (orderdetail_id, order_id, product_id) VALUES
(1, 1, 1),
(2, 2, 2),
(3, 2, 5),
(4, 3, 3),
(5, 4, 6),
(6, 5, 4),
(7, 5, 2);
GO


------------------------------------------------------------
-- ORDER_VOUCHER
------------------------------------------------------------

INSERT INTO Order_Voucher (order_id, voucher_code) VALUES
(1, 'WELCOME10'),
(3, 'VIP20'),
(5, 'WEEKEND5');
GO


------------------------------------------------------------
-- PAYMENT
------------------------------------------------------------

INSERT INTO Payment (order_id, amount, method, payment_date, status) VALUES
(1, 25000000, 'CREDIT_CARD',  '2025-03-10 10:05:00', 'PAID'),
(2, 22500000, 'CASH',         '2025-03-11 15:00:00', 'UNPAID'),
(3, 30000000, 'BANK_TRANSFER','2025-03-12 10:00:00', 'PAID'),
(4,   750000, 'WALLET',       '2025-03-13 17:00:00', 'PAID'),
(5, 50000000, 'CREDIT_CARD',  '2025-03-14 11:30:00', 'FAILED');
GO


------------------------------------------------------------
-- CARRIER_COMPANY
------------------------------------------------------------

INSERT INTO Carrier_Company (company_name, carrier_id) VALUES
(N'Giao Hang Nhanh',     1),
(N'Giao Hang Tiet Kiem', 2),
(N'VNPost',              3);
GO


------------------------------------------------------------
-- SHIPMENT
------------------------------------------------------------

INSERT INTO Shipment (order_id, company_name, tracking_code, shipment_fee, is_cod, recipient_address, recipient_name, delivery_deadline) VALUES
(1, N'Giao Hang Nhanh',     N'GHN123456', 30000, 0, N'123 Le Loi, District 1, HCMC', N'Alice Nguyen', '2025-03-12 18:00:00'),
(2, N'Giao Hang Tiet Kiem', N'GHTK987654',25000, 1, N'78 Pham Van Dong, Thu Duc, HCMC', N'Bob Tran', '2025-03-15 18:00:00'),
(3, N'Giao Hang Nhanh',     N'GHN555888', 35000, 0, N'12 Vo Van Ngan, Thu Duc, HCMC', N'Carol Le', '2025-03-16 18:00:00'),
(4, N'VNPost',              N'VN123789',  20000, 0, N'90 Nguyen Trai, District 5, HCMC', N'Eve Hoang', '2025-03-17 18:00:00');
GO


------------------------------------------------------------
-- REVIEW
------------------------------------------------------------

INSERT INTO Review (customer_id, product_id, rating, comment, review_date) VALUES
('CUS0001', 1, 5, N'Điện thoại dùng rất mượt, pin tốt.', '2025-03-20 09:00:00'),
('CUS0002', 2, 4, N'Máy ổn, camera đẹp, pin tạm ổn.',    '2025-03-21 10:30:00'),
('CUS0003', 3, 5, N'MacBook chạy êm, màn đẹp.',          '2025-03-22 11:00:00'),
('CUS0004', 6, 3, N'Đầm đẹp nhưng form hơi nhỏ.',        '2025-03-23 14:20:00'),
('CUS0001', 5, 4, N'Áo thoáng mát, mặc rất ổn.',         '2025-03-24 16:10:00');
GO


------------------------------------------------------------
-- KẾT THÚC
------------------------------------------------------------
PRINT 'Database MyDatabase created and populated successfully!';
GO
