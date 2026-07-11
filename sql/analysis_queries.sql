-- ============================================================
-- Maji Ndogo Water Access Analytics — Business Analysis Queries
-- ============================================================

-- 1. Population served by source type
SELECT type_of_water_source,
       COUNT(*) AS n_sources,
       SUM(number_of_people_served) AS total_people
FROM water_source
GROUP BY type_of_water_source
ORDER BY total_people DESC;

-- 2. Average queue time by province (window function: rank provinces)
SELECT l.province_name,
       ROUND(AVG(v.time_in_queue), 1) AS avg_queue_minutes,
       COUNT(*) AS n_visits,
       RANK() OVER (ORDER BY AVG(v.time_in_queue) DESC) AS queue_rank
FROM visits v
JOIN location l ON SUBSTR(v.source_id, 1, LENGTH(v.source_id) - 3) = l.location_id
GROUP BY l.province_name
ORDER BY avg_queue_minutes DESC;

-- 3. "Basic water access" classification and population share.
-- Basic = working in-home tap, OR shared_tap/well with average queue
-- under 30 minutes (WHO/JMP-style threshold). Broken taps and river
-- (surface water) sources never count as basic access regardless of queue.
WITH source_queue AS (
    SELECT ws.source_id, ws.type_of_water_source, ws.number_of_people_served,
           AVG(v.time_in_queue) AS avg_queue
    FROM water_source ws
    LEFT JOIN visits v ON v.source_id = ws.source_id
    GROUP BY ws.source_id, ws.type_of_water_source, ws.number_of_people_served
),
classified AS (
    SELECT *,
        CASE
            WHEN type_of_water_source = 'tap_in_home' THEN 'Basic access'
            WHEN type_of_water_source = 'tap_in_home_broken' THEN 'No access (broken)'
            WHEN type_of_water_source = 'river' THEN 'No access (surface water)'
            WHEN avg_queue IS NULL OR avg_queue < 30 THEN 'Basic access'
            ELSE 'Limited access (queue 30min+)'
        END AS access_level
    FROM source_queue
)
SELECT access_level,
       SUM(number_of_people_served) AS people,
       ROUND(100.0 * SUM(number_of_people_served) / SUM(SUM(number_of_people_served)) OVER (), 1) AS pct_of_population
FROM classified
GROUP BY access_level
ORDER BY people DESC;

-- 4. Basic-access share BY PROVINCE (feeds the choropleth map)
WITH source_queue AS (
    SELECT ws.source_id, ws.type_of_water_source, ws.number_of_people_served,
           l.province_name,
           AVG(v.time_in_queue) AS avg_queue
    FROM water_source ws
    JOIN location l ON SUBSTR(ws.source_id, 1, LENGTH(ws.source_id) - 3) = l.location_id
    LEFT JOIN visits v ON v.source_id = ws.source_id
    GROUP BY ws.source_id, ws.type_of_water_source, ws.number_of_people_served, l.province_name
),
classified AS (
    SELECT *,
        CASE
            WHEN type_of_water_source = 'tap_in_home' THEN 1
            WHEN type_of_water_source IN ('tap_in_home_broken','river') THEN 0
            WHEN avg_queue IS NULL OR avg_queue < 30 THEN 1
            ELSE 0
        END AS has_basic_access
    FROM source_queue
)
SELECT province_name,
       SUM(number_of_people_served) AS total_population,
       SUM(number_of_people_served * has_basic_access) AS basic_access_population,
       ROUND(100.0 * SUM(number_of_people_served * has_basic_access) / SUM(number_of_people_served), 1) AS pct_basic_access
FROM classified
GROUP BY province_name
ORDER BY pct_basic_access ASC;

-- 5. Well contamination rate and type
SELECT results, COUNT(*) AS n, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM well_pollution
GROUP BY results
ORDER BY n DESC;

-- 6. Project completion status and cost by improvement type
SELECT improvement,
       COUNT(*) AS n_projects,
       ROUND(AVG(cost), 0) AS avg_cost_usd,
       ROUND(AVG(JULIANDAY(date_of_completion) - JULIANDAY(date_started)), 0) AS avg_days_to_complete
FROM project_progress
WHERE source_status = 'Complete'
GROUP BY improvement
ORDER BY n_projects DESC;

-- 7. Vendor performance ranking (ranking with window function)
SELECT v.company_name,
       COUNT(*) AS n_projects,
       ROUND(AVG(pp.cost), 0) AS avg_cost_usd,
       RANK() OVER (ORDER BY AVG(pp.cost) ASC) AS cost_efficiency_rank
FROM project_progress pp
JOIN vendors v ON pp.assigned_vendor = v.vendor_ID
WHERE pp.source_status = 'Complete'
GROUP BY v.company_name
HAVING COUNT(*) >= 50
ORDER BY avg_cost_usd ASC
LIMIT 10;

-- 8. Total infrastructure investment to date
SELECT ROUND(SUM(cost), 0) AS total_invested_usd,
       COUNT(*) AS n_projects
FROM project_progress
WHERE source_status = 'Complete';

-- 9. Queue demographic composition (average share of women/children queueing)
SELECT ROUND(AVG(percent_male), 1) AS avg_pct_male,
       ROUND(AVG(percent_female), 1) AS avg_pct_female,
       ROUND(AVG(percent_child), 1) AS avg_pct_child
FROM queue_composition;

-- 10. Crime near water sources by type (historical data, 2010-2020 —
-- see cleaning_queries.sql note #6 on the time-period gap vs. visits data)
SELECT crime_type, COUNT(*) AS n, victim_gender
FROM water_source_related_crime
GROUP BY crime_type, victim_gender
ORDER BY n DESC;
