-- =============================================================
-- COVID-19 Data Exploration — Schema
-- Source: Our World in Data (OWID) COVID-19 dataset.
-- The wide OWID table is split into two tables that join on
-- (location, date) — the classic deaths-vs-vaccinations layout.
-- Column names match OWID exactly.

DROP TABLE IF EXISTS CovidDeaths;
DROP TABLE IF EXISTS CovidVaccinations;

CREATE TABLE CovidDeaths (
    iso_code      TEXT,
    continent     TEXT,           -- NULL for aggregate rows (World, continents, income groups)
    location      TEXT,
    date          TEXT,           -- 'YYYY-MM-DD'
    population    INTEGER,
    total_cases   REAL,
    new_cases     REAL,
    total_deaths  REAL,
    new_deaths    REAL
);

CREATE TABLE CovidVaccinations (
    iso_code                   TEXT,
    continent                  TEXT,
    location                   TEXT,
    date                       TEXT,
    population                 INTEGER,
    total_tests                REAL,
    new_tests                  REAL,
    positive_rate              REAL,
    total_vaccinations         REAL,
    people_vaccinated          REAL,
    people_fully_vaccinated    REAL,
    new_vaccinations           REAL,
    median_age                 REAL,
    gdp_per_capita             REAL,
    hospital_beds_per_thousand REAL,
    life_expectancy            REAL,
    human_development_index    REAL
);

CREATE INDEX idx_deaths_loc_date ON CovidDeaths(location, date);
CREATE INDEX idx_vacc_loc_date   ON CovidVaccinations(location, date);
CREATE INDEX idx_deaths_continent ON CovidDeaths(continent);
