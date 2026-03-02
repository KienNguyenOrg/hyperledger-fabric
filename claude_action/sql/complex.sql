WITH authorized_customers AS (
    SELECT
        c.customer_id,
        c.country,
        c.created_at
    FROM customers c
    JOIN user_customer_access uca
        ON uca.customer_id = c.customer_id
    WHERE uca.user_id = :current_user_id
),
filtered_orders AS (
    SELECT
        o.customer_id,
        o.order_id,
        o.total_amount,
        o.order_date
    FROM orders o
    WHERE o.status = 'COMPLETED'
      AND o.order_date BETWEEN :start_date AND :end_date
),
customer_aggregates AS (
    SELECT
        ac.customer_id,
        COUNT(fo.order_id) AS completed_orders,
        SUM(fo.total_amount) AS total_spent,
        AVG(fo.total_amount) AS avg_order_value,
        MAX(fo.order_date) AS last_order_date
    FROM authorized_customers ac
    LEFT JOIN filtered_orders fo
        ON fo.customer_id = ac.customer_id
    GROUP BY ac.customer_id
),
ranking_layer AS (
    SELECT
        ca.*,
        PERCENT_RANK() OVER (ORDER BY ca.total_spent DESC) AS spend_percentile,
        ROW_NUMBER() OVER (
            PARTITION BY
                CASE
                    WHEN ca.total_spent >= 10000 THEN 'HIGH'
                    ELSE 'NORMAL'
                END
            ORDER BY ca.total_spent DESC
        ) AS segment_rank
    FROM customer_aggregates ca
),
risk_scoring AS (
    SELECT
        rl.customer_id,
        rl.completed_orders,
        rl.total_spent,
        rl.avg_order_value,
        rl.last_order_date,
        rl.spend_percentile,
        rl.segment_rank,
        (
            CASE WHEN rl.total_spent >= 20000 THEN 50 ELSE 0 END +
            CASE WHEN rl.completed_orders >= 40 THEN 30 ELSE 0 END +
            CASE WHEN rl.last_order_date >= CURRENT_DATE - INTERVAL '30 days' THEN 20 ELSE 0 END
        ) AS risk_score
    FROM ranking_layer rl
)
SELECT
    customer_id,
    completed_orders,
    total_spent,
    avg_order_value,
    spend_percentile,
    risk_score,
    CASE
        WHEN risk_score >= 70 THEN 'CRITICAL'
        WHEN risk_score >= 40 THEN 'HIGH'
        WHEN risk_score >= 20 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_segment
FROM risk_scoring
WHERE segment_rank <= :max_results
ORDER BY risk_score DESC, total_spent DESC;