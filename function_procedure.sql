USE MyDatabase;
GO

------------------------------------------------------------
-- 1. FUNCTION: Tính tổng tiền đơn hàng (Semantic Constraint 1)
-- Yêu cầu: Derived column calculation logic
------------------------------------------------------------
IF OBJECT_ID('fn_CalculateOrderTotal', 'FN') IS NOT NULL
    DROP FUNCTION fn_CalculateOrderTotal;
GO

CREATE FUNCTION fn_CalculateOrderTotal (@order_id INT)
RETURNS DECIMAL(12, 2)
AS
BEGIN
    DECLARE @total DECIMAL(12, 2) = 0;
    DECLARE @subtotal DECIMAL(12, 2) = 0;
    DECLARE @discount DECIMAL(12, 2) = 0;
    DECLARE @shipment_fee DECIMAL(12, 2) = 0;

    -- 1. Tính tổng tiền hàng (Subtotal)
    SELECT @subtotal = SUM(quantity * unit_price)
    FROM OrderDetail
    WHERE order_id = @order_id;

    -- 2. Lấy giá trị giảm giá từ Voucher (nếu có)
    -- Semantic Constraint 1: Total_Amount = SUM(...) - Voucher + Shipment
    SELECT @discount = v.discount_value
    FROM Order_Voucher ov
    JOIN Voucher v ON ov.voucher_code = v.code
    WHERE ov.order_id = @order_id;

    -- 3. Lấy phí vận chuyển (nếu có)
    SELECT @shipment_fee = shipment_fee
    FROM Shipment
    WHERE order_id = @order_id;

    -- Xử lý NULL (nếu không có record thì coi là 0)
    SET @subtotal = ISNULL(@subtotal, 0);
    SET @discount = ISNULL(@discount, 0);
    SET @shipment_fee = ISNULL(@shipment_fee, 0);

    -- Tính tổng cuối cùng
    SET @total = @subtotal - @discount + @shipment_fee;

    -- Đảm bảo không âm
    IF @total < 0 SET @total = 0;

    RETURN @total;
END;
GO

------------------------------------------------------------
-- 2. FUNCTION: Tính điểm đánh giá trung bình của sản phẩm
-- Yêu cầu: Aggregate function
------------------------------------------------------------
IF OBJECT_ID('fn_GetProductAverageRating', 'FN') IS NOT NULL
    DROP FUNCTION fn_GetProductAverageRating;
GO

CREATE FUNCTION fn_GetProductAverageRating (@product_id INT)
RETURNS DECIMAL(3, 2)
AS
BEGIN
    DECLARE @avg_rating DECIMAL(3, 2);

    SELECT @avg_rating = CAST(AVG(rating * 1.0) AS DECIMAL(3, 2))
    FROM Review
    WHERE product_id = @product_id;

    RETURN ISNULL(@avg_rating, 0);
END;
GO

------------------------------------------------------------
-- 3. STORED PROCEDURE: Báo cáo doanh thu tháng của Seller
-- Yêu cầu: Input validation, Aggregate, GROUP BY, HAVING, JOIN
------------------------------------------------------------
IF OBJECT_ID('sp_GetSellerMonthlyStats', 'P') IS NOT NULL
    DROP PROCEDURE sp_GetSellerMonthlyStats;
GO

CREATE PROCEDURE sp_GetSellerMonthlyStats
    @seller_id VARCHAR(8),
    @month INT,
    @year INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate Input Parameter
    IF NOT EXISTS (SELECT 1 FROM Seller WHERE seller_id = @seller_id)
    BEGIN
        PRINT 'Error: Seller ID does not exist.';
        RETURN;
    END

    IF @month < 1 OR @month > 12
    BEGIN
        PRINT 'Error: Invalid month.';
        RETURN;
    END

    -- Thực hiện thống kê
    SELECT 
        p.product_id,
        p.name AS product_name,
        SUM(od.quantity) AS total_sold_quantity,
        SUM(od.unit_price * od.quantity) AS total_revenue
    FROM Product p
    JOIN OrderDetail od ON p.product_id = od.product_id
    JOIN [Order] o ON od.order_id = o.order_id
    WHERE p.seller_id = @seller_id
      AND MONTH(o.order_date) = @month
      AND YEAR(o.order_date) = @year
      AND o.status_ = N'DELIVERED' -- Chỉ tính đơn đã giao thành công
    GROUP BY p.product_id, p.name
    HAVING SUM(od.quantity) > 0 -- Chỉ lấy sản phẩm có bán được
    ORDER BY total_revenue DESC;
END;
GO

------------------------------------------------------------
-- 4. STORED PROCEDURE: Tìm kiếm sản phẩm nâng cao
-- Yêu cầu: WHERE with multiple tables, Control statements
------------------------------------------------------------
IF OBJECT_ID('sp_SearchProducts', 'P') IS NOT NULL
    DROP PROCEDURE sp_SearchProducts;
GO

CREATE PROCEDURE sp_SearchProducts
    @keyword NVARCHAR(100) = NULL,
    @min_price DECIMAL(12,2) = 0,
    @max_price DECIMAL(12,2) = 999999999,
    @category_name NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.product_id,
        p.name,
        p.price,
        p.stock_quantity,
        s.store_name,
        c.name AS category_name
    FROM Product p
    JOIN Seller s ON p.seller_id = s.seller_id
    LEFT JOIN Product_Category pc ON p.product_id = pc.product_id
    LEFT JOIN Category c ON pc.category_id = c.category_id
    WHERE 
        p.price BETWEEN @min_price AND @max_price
        AND (@keyword IS NULL OR p.name LIKE '%' + @keyword + '%' OR p.description LIKE '%' + @keyword + '%')
        AND (@category_name IS NULL OR c.name = @category_name);
END;
GO