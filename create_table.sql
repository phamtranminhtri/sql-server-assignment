USE master;
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
