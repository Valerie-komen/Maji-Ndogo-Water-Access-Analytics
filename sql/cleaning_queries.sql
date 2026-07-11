-- ============================================================
-- Maji Ndogo Water Access Analytics — Data Cleaning / Validation
-- Mirrors the checks in notebooks/01_data_cleaning.ipynb.
-- ============================================================

-- 1. Duplicate primary keys
SELECT COUNT(*) AS dup_source_ids FROM (
    SELECT source_id, COUNT(*) c FROM water_source GROUP BY source_id HAVING c > 1
);
SELECT COUNT(*) AS dup_location_ids FROM (
    SELECT location_id, COUNT(*) c FROM location GROUP BY location_id HAVING c > 1
);

-- 2. Referential integrity: every visit points to a real location and source
SELECT COUNT(*) AS visits_missing_location
FROM visits v LEFT JOIN location l ON v.location_id = l.location_id
WHERE l.location_id IS NULL;

SELECT COUNT(*) AS visits_missing_source
FROM visits v LEFT JOIN water_source w ON v.source_id = w.source_id
WHERE w.source_id IS NULL;

-- 3. source_id / location_id key relationship (source_id = location_id +
-- a 3-character source-type suffix — verify this holds for every row)
SELECT COUNT(*) AS unmatched_via_suffix_rule
FROM water_source ws
LEFT JOIN location l ON SUBSTR(ws.source_id, 1, LENGTH(ws.source_id) - 3) = l.location_id
WHERE l.location_id IS NULL;

-- 4. Categorical domain checks
SELECT DISTINCT type_of_water_source FROM water_source ORDER BY 1;
SELECT DISTINCT province_name FROM location ORDER BY 1;
SELECT DISTINCT results FROM well_pollution ORDER BY 1;
SELECT DISTINCT source_status FROM project_progress ORDER BY 1;

-- 5. Column completeness (the raw exports had several 100%-null columns
-- in some source files that were backfilled from other exports at
-- the pandas merge step — see notebooks/01_data_cleaning.ipynb.
-- `comments` in project_progress remains genuinely empty in every
-- source file and is dropped rather than backfilled from nothing.)
SELECT
    SUM(CASE WHEN address IS NULL THEN 1 ELSE 0 END) AS null_address,
    COUNT(*) AS total
FROM location;

SELECT
    SUM(CASE WHEN time_of_record IS NULL THEN 1 ELSE 0 END) AS null_time_of_record,
    SUM(CASE WHEN assigned_employee_id IS NULL THEN 1 ELSE 0 END) AS null_employee_id,
    COUNT(*) AS total
FROM visits;

-- 6. Time-period mismatch flag: crime data (2010-2020) and visit data
-- (2021-2023) do not overlap — confirm the gap explicitly so no analysis
-- accidentally implies a causal same-period relationship between them.
SELECT MIN(time_of_incident), MAX(time_of_incident) FROM water_source_related_crime;
SELECT MIN(time_of_record), MAX(time_of_record) FROM visits;

-- 7. Project status distribution (in this export, is the backlog really
-- fully cleared, or is this an artifact of which snapshot we used?)
SELECT source_status, COUNT(*) FROM project_progress GROUP BY source_status;
