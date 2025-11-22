USE MyDatabase;
-- uncomment to try the effect of function, procedure, trigger

-- -- function 1
-- SELECT dbo.fn_CalculateOrderTotal(5) 
-- -- function 2
-- SELECT dbo.fn_GetProductAverageRating(3)

-- -- procedure 1
-- EXEC sp_GetSellerMonthlyStats SEL0001, 3, 2025
-- -- procedure 2
-- EXEC sp_SearchProducts dress

-- -- trigger 1 & 2
-- INSERT INTO [Order] (customer_id, status_, total_amount, order_date) VALUES
-- ('CUS0003', N'PENDING', 30000000, '2025-03-12 09:15:00'); -- 6: 1 x MacBook

-- SELECT * FROM [Order] WHERE order_id = 6;

-- INSERT INTO OrderDetail (order_id, product_id, unit_price, quantity) VALUES
-- (6, 3, 30000000, 2);  -- od_id = 8

-- SELECT * FROM [Order] WHERE order_id = 6;

-- SELECT * FROM Product WHERE product_id = 3;
-- UPDATE [Order] SET status_ = N'CONFIRMED'
-- SELECT * FROM Product WHERE product_id = 3;