-- ============================================================
--  Insert data into dim.date
--  Range: 2015-01-01 to 2030-12-31  (5,844 rows)
-- ============================================================

DELETE FROM dim.[date];
GO

WITH DateSeries AS
(
    SELECT CAST('2015-01-01' AS DATE) AS dt

    UNION ALL

    SELECT DATEADD(DAY, 1, dt)
    FROM   DateSeries
    WHERE  dt < CAST('2030-12-31' AS DATE)
)
INSERT INTO dim.[date]
(
    full_date,
    day_of_week,
    day_name,
    week_number,
    month_number,
    month_name,
    quarter,
    [year],
    is_weekend,
    is_holiday
)
SELECT
    dt,
    DATEPART(WEEKDAY,   dt),
    DATENAME(WEEKDAY,   dt),
    DATEPART(ISO_WEEK,  dt),
    MONTH(dt),
    DATENAME(MONTH,     dt),
    DATEPART(QUARTER,   dt),
    YEAR(dt),
    CASE WHEN DATEPART(WEEKDAY, dt) IN (1, 7) THEN 1 ELSE 0 END,
    0
FROM DateSeries
OPTION (MAXRECURSION 6000);
GO

-- Verification
SELECT
    MIN(full_date) AS first_date,
    MAX(full_date) AS last_date,
    COUNT(*)       AS total_rows
FROM dim.[date];
GO
