USE MyDatabase;
GO

------------------------------------------------------------
-- 1. TRIGGER: Cập nhật tổng tiền đơn hàng (Derived Column)
-- Khi thêm/sửa/xóa OrderDetail -> Cập nhật Order.total_amount
------------------------------------------------------------
IF OBJECT_ID('trg_UpdateOrderTotal', 'TR') IS NOT NULL
    DROP TRIGGER trg_UpdateOrderTotal;
GO

CREATE TRIGGER trg_UpdateOrderTotal
ON OrderDetail
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @order_id INT;

    -- Lấy danh sách order_id bị ảnh hưởng từ bảng inserted và deleted
    SELECT DISTINCT order_id INTO #AffectedOrders
    FROM (
        SELECT order_id FROM inserted
        UNION
        SELECT order_id FROM deleted
    ) AS Temp;

    -- Sử dụng CURSOR hoặc vòng lặp để cập nhật từng Order (vì hàm fn_CalculateOrderTotal là scalar)
    DECLARE cur CURSOR FOR SELECT order_id FROM #AffectedOrders;
    OPEN cur;
    FETCH NEXT FROM cur INTO @order_id;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Gọi Function đã viết ở trên để tính toán lại
        UPDATE [Order]
        SET total_amount = dbo.fn_CalculateOrderTotal(@order_id)
        WHERE order_id = @order_id;

        FETCH NEXT FROM cur INTO @order_id;
    END

    CLOSE cur;
    DEALLOCATE cur;
    
    DROP TABLE #AffectedOrders;
END;
GO

------------------------------------------------------------
-- 2. TRIGGER: Cập nhật tồn kho khi xác nhận đơn (Business Rule)
-- Semantic Constraint 2: Khi Order chuyển sang CONFIRMED -> Trừ Stock
------------------------------------------------------------
IF OBJECT_ID('trg_UpdateStockOnConfirm', 'TR') IS NOT NULL
    DROP TRIGGER trg_UpdateStockOnConfirm;
GO

CREATE TRIGGER trg_UpdateStockOnConfirm
ON [Order]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Chỉ xử lý khi trạng thái thay đổi thành 'CONFIRMED'
    -- Giả sử chuyển từ PENDING -> CONFIRMED
    IF UPDATE(status_)
    BEGIN
        -- Cập nhật tồn kho cho các sản phẩm trong các đơn hàng vừa được Confirm
        -- Logic: Product.Stock = Product.Stock - OrderDetail.Quantity
        UPDATE p
        SET p.stock_quantity = p.stock_quantity - od.quantity
        FROM Product p
        JOIN OrderDetail od ON p.product_id = od.product_id
        JOIN inserted i ON od.order_id = i.order_id
        JOIN deleted d ON i.order_id = d.order_id
        WHERE i.status_ = N'CONFIRMED' 
          AND d.status_ <> N'CONFIRMED'; -- Đảm bảo trạng thái cũ chưa phải là Confirm

        -- Kiểm tra logic: Nếu tồn kho bị âm -> Rollback (Optional, vì đã có Constraint check >= 0 ở DB)
        IF EXISTS (SELECT 1 FROM Product WHERE stock_quantity < 0)
        BEGIN
            RAISERROR ('Error: Not enough stock quantity for one or more products.', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;
GO