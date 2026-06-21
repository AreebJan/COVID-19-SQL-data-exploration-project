
-- 1. First look at the data (countries only, most recent rows).
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date
LIMIT 20;

-- 2. Total Cases vs Total Deaths.
--    Rough chance of dying if you caught COVID, over time, in one country.
SELECT location, date, total_cases, total_deaths,
       ROUND(total_deaths / total_cases * 100, 2) AS death_pct
FROM CovidDeaths
WHERE location = 'United States' AND total_cases > 0
ORDER BY date DESC
LIMIT 15;

-- 3. Total Cases vs Population — share of population infected over time.
SELECT location, date, population, total_cases,
       ROUND(total_cases / population * 100, 4) AS pct_infected
FROM CovidDeaths
WHERE location = 'Denmark' AND total_cases > 0
ORDER BY date DESC
LIMIT 15;

-- 4. Countries with the highest infection rate vs population.
SELECT location, population,
       MAX(total_cases) AS highest_infection_count,
       ROUND(MAX(total_cases) / population * 100, 2) AS pct_population_infected
FROM CovidDeaths
WHERE continent IS NOT NULL AND population > 0
GROUP BY location, population
ORDER BY pct_population_infected DESC
LIMIT 15;

-- 5. Countries with the highest total death count.
SELECT location, MAX(total_deaths) AS total_death_count
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY total_death_count DESC
LIMIT 15;

-- 6. Continents with the highest death count.
--    Aggregate continent rows are stored with continent = NULL and the
--    continent name in `location`, so we read them directly.
SELECT location AS continent, MAX(total_deaths) AS total_death_count
FROM CovidDeaths
WHERE continent IS NULL
  AND location IN ('Africa','Asia','Europe','North America',
                   'South America','Oceania')
GROUP BY location
ORDER BY total_death_count DESC;

-- 7. Global numbers: total cases, total deaths and overall death rate.
SELECT SUM(new_cases)  AS total_cases,
       SUM(new_deaths) AS total_deaths,
       ROUND(SUM(new_deaths) / SUM(new_cases) * 100, 2) AS global_death_pct
FROM CovidDeaths
WHERE continent IS NOT NULL;

-- 8. JOIN deaths + vaccinations: running total of vaccinations per country.
--    Window function: SUM(...) OVER (PARTITION BY location ORDER BY date).
SELECT d.continent, d.location, d.date, d.population,
       v.new_vaccinations,
       SUM(v.new_vaccinations) OVER (
           PARTITION BY d.location ORDER BY d.date
       ) AS rolling_people_vaccinated
FROM CovidDeaths d
JOIN CovidVaccinations v
     ON d.location = v.location AND d.date = v.date
WHERE d.continent IS NOT NULL AND d.location = 'Denmark'
ORDER BY d.date
LIMIT 20;

-- 9. CTE on the rolling count: % of population vaccinated to date.
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
SELECT location, date, population, rolling_people_vaccinated,
       ROUND(rolling_people_vaccinated / population * 100, 2) AS rolling_pct
FROM pop_vs_vac
WHERE location = 'Denmark' AND rolling_people_vaccinated IS NOT NULL
ORDER BY date DESC
LIMIT 10;

-- 10. Most vaccinated countries (people fully vaccinated as a share of pop).
SELECT d.location, d.population,
       MAX(v.people_fully_vaccinated) AS fully_vaccinated,
       ROUND(MAX(v.people_fully_vaccinated) / d.population * 100, 2) AS pct_fully_vaccinated
FROM CovidDeaths d
JOIN CovidVaccinations v
     ON d.location = v.location AND d.date = v.date
WHERE d.continent IS NOT NULL AND d.population > 100000
GROUP BY d.location, d.population
HAVING fully_vaccinated IS NOT NULL
ORDER BY pct_fully_vaccinated DESC
LIMIT 15;

-- 11. Does wealth track with deaths? Death rate vs GDP per capita.
WITH country_stats AS (
    SELECT d.location,
           MAX(d.total_deaths) AS deaths,
           d.population,
           (SELECT MAX(gdp_per_capita) FROM CovidVaccinations
            WHERE location = d.location) AS gdp_per_capita
    FROM CovidDeaths d
    WHERE d.continent IS NOT NULL AND d.population > 1000000
    GROUP BY d.location, d.population
)
SELECT location,
       ROUND(deaths / population * 1000000.0, 1) AS deaths_per_million,
       ROUND(gdp_per_capita) AS gdp_per_capita
FROM country_stats
WHERE deaths IS NOT NULL AND gdp_per_capita IS NOT NULL
ORDER BY deaths_per_million DESC
LIMIT 15;

-- 12. VIEW for a BI tool (e.g. Tableau / Power BI): rolling vaccination %.
DROP VIEW IF EXISTS PercentPopulationVaccinated;
CREATE VIEW PercentPopulationVaccinated AS
SELECT d.continent, d.location, d.date, d.population,
       v.new_vaccinations,
       SUM(v.new_vaccinations) OVER (
           PARTITION BY d.location ORDER BY d.date
       ) AS rolling_people_vaccinated
FROM CovidDeaths d
JOIN CovidVaccinations v
     ON d.location = v.location AND d.date = v.date
WHERE d.continent IS NOT NULL;

SELECT * FROM PercentPopulationVaccinated
WHERE location = 'Germany'
ORDER BY date DESC
LIMIT 5;
