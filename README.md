# COVID-19 Data Exploration (SQL)

An exploratory SQL analysis of the global COVID-19 pandemic using the real
**[Our World in Data](https://github.com/owid/covid-19-data) COVID-19 dataset** —
255 locations, daily from **Jan 2020 to Aug 2024** (~429,000 rows).

The wide source file is split into two tables — `CovidDeaths` and
`CovidVaccinations` — that join on `(location, date)`, then queried to work out
infection rates, mortality, and the vaccination rollout.

**Skills shown:** `JOIN`, `GROUP BY`, aggregate functions, `HAVING`, subqueries,
window functions, CTEs, and a `VIEW` for BI tools.

---

## Tables

`CovidDeaths` — `iso_code, continent, location, date, population, total_cases,
new_cases, total_deaths, new_deaths`

`CovidVaccinations` — `iso_code, continent, location, date, population, total_tests,
new_tests, positive_rate, total_vaccinations, people_vaccinated,
people_fully_vaccinated, new_vaccinations, median_age, gdp_per_capita,
hospital_beds_per_thousand, life_expectancy, human_development_index`

> Aggregate rows (`World`, continents, income groups) have a **NULL `continent`**,
> so country-level queries filter `WHERE continent IS NOT NULL`. This is a real
> quirk of the OWID file, handled explicitly in every query.

---

## Sample queries & output

All numbers below are the **actual output** from the full dataset.

### 1. Global summary — cases, deaths and overall death rate

```sql
SELECT SUM(new_cases)  AS total_cases,
       SUM(new_deaths) AS total_deaths,
       ROUND(SUM(new_deaths) / SUM(new_cases) * 100, 2) AS death_pct
FROM CovidDeaths
WHERE continent IS NOT NULL;
```

| total_cases | total_deaths | death_pct |
|-------------|--------------|-----------|
| 775,935,057 | 7,060,988    | 0.91      |

Worldwide, about **0.91%** of reported cases ended in a reported death.

### 2. Countries with the highest total death count

```sql
SELECT location, MAX(total_deaths) AS total_deaths
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY total_deaths DESC
LIMIT 8;
```

| location        | total_deaths |
|-----------------|--------------|
| United States   | 1,193,165    |
| Brazil          | 702,116      |
| India           | 533,623      |
| Russia          | 403,188      |
| Mexico          | 334,551      |
| United Kingdom  | 232,112      |
| Peru            | 220,975      |
| Italy           | 197,307      |

### 3. Highest infection rate vs population

```sql
SELECT location, population,
       MAX(total_cases) AS highest_infection_count,
       ROUND(MAX(total_cases) / population * 100, 2) AS pct_population_infected
FROM CovidDeaths
WHERE continent IS NOT NULL AND population > 1000000
GROUP BY location, population
ORDER BY pct_population_infected DESC
LIMIT 8;
```

| location    | population | pct_population_infected |
|-------------|------------|-------------------------|
| Austria     | 8,939,617  | 68.04                   |
| South Korea | 51,815,808 | 66.72                   |
| Slovenia    | 2,119,843  | 63.99                   |
| Denmark     | 5,882,259  | 58.41                   |
| France      | 67,813,000 | 57.51                   |
| Portugal    | 10,270,857 | 55.15                   |
| Greece      | 10,384,972 | 54.63                   |
| Singapore   | 5,637,022  | 53.33                   |

### 4. Rolling vaccinations — JOIN + window function

Joins the two tables on `(location, date)` and keeps a running total of doses
with `SUM(...) OVER (PARTITION BY location ORDER BY date)`, then expresses it as a
share of population.

```sql
WITH pop_vs_vac AS (
    SELECT d.location, d.date, d.population, v.new_vaccinations,
           SUM(v.new_vaccinations) OVER (
               PARTITION BY d.location ORDER BY d.date
           ) AS rolling_people_vaccinated
    FROM CovidDeaths d
    JOIN CovidVaccinations v
         ON d.location = v.location AND d.date = v.date
    WHERE d.continent IS NOT NULL
)
SELECT location, date, rolling_people_vaccinated,
       ROUND(rolling_people_vaccinated / population * 100, 1) AS rolling_pct
FROM pop_vs_vac
WHERE location = 'India' AND rolling_people_vaccinated IS NOT NULL
ORDER BY date DESC
LIMIT 4;
```

| location | date       | rolling_people_vaccinated | rolling_pct |
|----------|------------|---------------------------|-------------|
| India    | 2024-08-12 | 2,112,144,067             | 149.0       |
| India    | 2024-08-11 | 2,112,144,060             | 149.0       |
| India    | 2024-08-10 | 2,112,144,053             | 149.0       |
| India    | 2024-08-09 | 2,112,144,037             | 149.0       |

India administered ~2.1 billion doses — about **149% of its population**, since
the running total counts every dose, not every person.

### 5. Most fully vaccinated countries

```sql
SELECT d.location,
       ROUND(MAX(v.people_fully_vaccinated) / d.population * 100, 2) AS pct_fully_vaccinated
FROM CovidDeaths d
JOIN CovidVaccinations v
     ON d.location = v.location AND d.date = v.date
WHERE d.continent IS NOT NULL AND d.population > 1000000
GROUP BY d.location, d.population
HAVING MAX(v.people_fully_vaccinated) IS NOT NULL
ORDER BY pct_fully_vaccinated DESC
LIMIT 8;
```

| location             | pct_fully_vaccinated |
|----------------------|----------------------|
| Qatar                | 105.83               |
| United Arab Emirates | 103.72               |
| Hong Kong            | 90.85                |
| Singapore            | 90.85                |
| Chile                | 90.29                |
| Cuba                 | 89.67                |
| China                | 89.54                |
| Nicaragua            | 88.17                |

**Data caveat worth knowing:** percentages above 100% (Qatar, UAE) happen because
doses given to non-residents are counted against the resident population — a good
reminder to sanity-check denominators rather than trust them blindly.

The full query set (12 queries, including continent roll-ups, death-rate vs
GDP, and a reusable `VIEW`) is in [`queries.sql`](queries.sql).

---

## Run it

A 12 MB **sample database** (`covid_sample.db`, 32 representative countries +
continents, full timeline) is included, so you can start immediately:

```bash
sqlite3 covid_sample.db ".read queries.sql"
```

To build the **complete dataset** (downloads the ~94 MB OWID CSV automatically):

```bash
sqlite3 covid.db < schema.sql
python3 load_data.py
sqlite3 covid.db ".read queries.sql"
```

The same `queries.sql` runs on both — the full database just returns the
complete country rankings.

---

## Files

| File | Purpose |
|------|---------|
| `schema.sql` | The two tables and their indexes |
| `load_data.py` | Downloads the OWID CSV and loads the full dataset |
| `queries.sql` | 12 worked analyses |
| `covid_sample.db` | Ready-to-query sample (32 locations, full timeline) |

*(The full `covid.db` and the raw CSV aren't committed — they're large and
rebuilt by `load_data.py`.)*

---

---

*Data source: Our World in Data (OWID), [owid/covid-19-data](https://github.com/owid/covid-19-data).*
