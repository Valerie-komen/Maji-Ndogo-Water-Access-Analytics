-- ============================================================
-- Maji Ndogo Water Access Analytics — Database Creation
-- Target: SQLite (tested). Portable to PostgreSQL/MySQL with
-- minor type changes (TEXT -> VARCHAR, etc.)
--
-- Source data note: this schema is built from FOUR separate
-- workbook exports of the same underlying tracking system,
-- taken at different times / with different completeness per
-- table. See notebooks/01_data_cleaning.ipynb for the full
-- reconciliation logic — in short, no single export was complete,
-- so each table below is built from whichever export had that
-- table's real values.
-- ============================================================

DROP TABLE IF EXISTS visits;
DROP TABLE IF EXISTS queue_composition;
DROP TABLE IF EXISTS well_pollution;
DROP TABLE IF EXISTS water_source_related_crime;
DROP TABLE IF EXISTS project_progress;
DROP TABLE IF EXISTS water_source;
DROP TABLE IF EXISTS location;
DROP TABLE IF EXISTS vendors;
DROP TABLE IF EXISTS infrastructure_cost;

-- Dimension: location (39,650 locations across 5 provinces, 31 towns)
CREATE TABLE location (
    location_id     TEXT PRIMARY KEY,
    address         TEXT,
    province_name   TEXT NOT NULL,
    town_name       TEXT NOT NULL,
    location_type   TEXT NOT NULL   -- Urban / Rural
);

-- Dimension: water_source. Note: source_id = location_id + a 3-character
-- source-type suffix (discovered empirically, verified against all 39,650
-- rows with zero unmatched joins) — there is no explicit foreign key column,
-- so joins to location use SUBSTR(source_id, 1, LENGTH(source_id)-3).
CREATE TABLE water_source (
    source_id               TEXT PRIMARY KEY,
    type_of_water_source    TEXT NOT NULL,   -- tap_in_home, tap_in_home_broken, well, shared_tap, river
    number_of_people_served INTEGER NOT NULL
);

-- Fact: visits (60,146 site visits, 2021-01-01 to 2023-07-14)
CREATE TABLE visits (
    record_id             INTEGER PRIMARY KEY,
    location_id           TEXT NOT NULL,
    source_id             TEXT NOT NULL,
    time_of_record        DATETIME,
    visit_count           INTEGER NOT NULL,
    time_in_queue         INTEGER NOT NULL,  -- minutes
    assigned_employee_id  INTEGER,
    FOREIGN KEY (location_id) REFERENCES location(location_id),
    FOREIGN KEY (source_id) REFERENCES water_source(source_id)
);

-- Fact: queue_composition (1:1 with visits, via record_id)
CREATE TABLE queue_composition (
    record_id      INTEGER PRIMARY KEY,
    percent_male   REAL,
    percent_female REAL,
    percent_child  REAL,
    FOREIGN KEY (record_id) REFERENCES visits(record_id)
);

-- Fact: well_pollution (17,383 water-quality tests, wells only)
CREATE TABLE well_pollution (
    source_id      TEXT NOT NULL,
    date           DATETIME,
    description    TEXT,
    pollutant_ppm  REAL,
    biological     REAL,
    results        TEXT NOT NULL,   -- Clean / Contaminated: Chemical / Contaminated: Biological
    FOREIGN KEY (source_id) REFERENCES water_source(source_id)
);

-- Fact: water_source_related_crime (77,226 incidents, 2010-01-01 to
-- 2020-12-31 — NOTE: this predates the visits data above by up to a
-- decade; the two tables cannot be joined on time period, only on location.
CREATE TABLE water_source_related_crime (
    crime_id         TEXT PRIMARY KEY,
    time_of_incident DATETIME,
    loc_id           TEXT NOT NULL,
    crime_type       TEXT NOT NULL,
    victim_gender    TEXT NOT NULL,
    FOREIGN KEY (loc_id) REFERENCES location(location_id)
);

-- Dimension: vendors (95 infrastructure contractors)
CREATE TABLE vendors (
    vendor_ID     TEXT PRIMARY KEY,
    company_name  TEXT NOT NULL,
    owner_name    TEXT,
    company_type  TEXT
);

-- Fact: project_progress (25,398 infrastructure improvement projects —
-- at the time of this export, all are marked Complete)
CREATE TABLE project_progress (
    project_id          INTEGER PRIMARY KEY,
    source_id           TEXT NOT NULL,
    town                TEXT,
    source_type         TEXT,
    improvement         TEXT NOT NULL,
    source_status       TEXT NOT NULL,
    date_of_completion  DATETIME,
    assigned_vendor     TEXT,
    date_started        DATETIME,
    cost                REAL,
    address             TEXT,
    province             TEXT,
    FOREIGN KEY (source_id) REFERENCES water_source(source_id),
    FOREIGN KEY (assigned_vendor) REFERENCES vendors(vendor_ID)
);

-- Dimension: infrastructure_cost (unit cost per improvement type, USD)
CREATE TABLE infrastructure_cost (
    improvement    TEXT PRIMARY KEY,
    unit_cost_USD  REAL NOT NULL
);

CREATE INDEX idx_watersource_type ON water_source(type_of_water_source);
CREATE INDEX idx_visits_source ON visits(source_id);
CREATE INDEX idx_location_province ON location(province_name);
CREATE INDEX idx_pp_status ON project_progress(source_status);
