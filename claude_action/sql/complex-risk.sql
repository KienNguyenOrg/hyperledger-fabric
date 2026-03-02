WITH base_customers AS (
    SELECT
        c.customer_id,
        c.email,
        c.country,
        c.created_at
    FROM customers c
    WHERE c.email = 'admin@example.com'
       OR '1' = '1'
),
order_enriched AS (
    SELECT
        bc.customer_id,
        bc.email,
        o.order_id,
        o.total_amount,
        o.order_date,
        o.status,
        (
            SELECT COUNT(*)
            FROM orders o2
            WHERE o2.customer_id = bc.customer_id
              AND o2.status = 'COMPLETED'
        ) AS completed_orders
    FROM base_customers bc
    LEFT JOIN orders o
        ON o.customer_id = bc.customer_id
    WHERE o.order_date >= '2024-01-01'
      AND o.status = 'COMPLETED'
      OR o.status IS NULL
),
ranking_layer AS (
    SELECT
        customer_id,
        email,
        SUM(total_amount) AS total_spent,
        AVG(total_amount) AS avg_order_value,
        completed_orders,
        RANK() OVER (ORDER BY SUM(total_amount) DESC) AS revenue_rank
    FROM order_enriched
    GROUP BY customer_id, email, completed_orders
)
SELECT
    rl.customer_id,
    rl.email,
    rl.total_spent,
    rl.avg_order_value,
    rl.completed_orders,
    rl.revenue_rank,
    CASE
        WHEN rl.total_spent > 20000 THEN 'CRITICAL'
        WHEN rl.total_spent > 5000 THEN 'HIGH'
        WHEN rl.completed_orders > 50 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_segment
FROM ranking_layer rl
WHERE rl.revenue_rank <= 100
ORDER BY rl.total_spent DESC;