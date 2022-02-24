SELECT * FROM coviddata.deaths
WHERE continent <> "" AND continent IS NOT NULL
ORDER BY 3,4;

SELECT * FROM coviddata.vaccinations
ORDER BY 3,4;

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM coviddata.deaths
ORDER BY 1,2;

-- Looking at Total Cases vs Total Deaths
-- Potential likelihood of death from Covid in a specific country/continent
SELECT location, date, total_cases, total_deaths, ((total_deaths / total_cases)*100) AS DeathPercentage
FROM coviddata.deaths
WHERE location LIKE "%states%"
ORDER BY 1,2;

-- Total Cases vs Population
SELECT location, date, total_cases, population, ((total_cases / population)*100) AS CasePercentage
FROM coviddata.deaths
WHERE location LIKE "%states%"
ORDER BY 1,2;

-- Countries with highest infection rate
SELECT location, MAX(total_cases) AS HightestInfectionCount, population, MAX(total_cases / population)*100 AS PercentInfected
FROM coviddata.deaths
GROUP BY location, population
ORDER BY PercentInfected desc;

SELECT location, MAX(total_cases) AS HightestInfectionCount, population, date, MAX(total_cases / population)*100 AS PercentInfected
FROM coviddata.deaths
GROUP BY location, population, date
ORDER BY PercentInfected desc;

-- Countries with highest death count per population
-- note: MySQL won't let you CAST AS INT you have to CAST AS SIGNED OR UNSIGNED; the data types for CASTing are different from columns (https://stackoverflow.com/questions/12126991/cast-from-varchar-to-int-mysql)
SELECT location, MAX(CAST(total_deaths AS UNSIGNED)) AS TotalDeathCount
FROM coviddata.deaths
WHERE continent <> "" AND continent IS NOT NULL
GROUP BY location
ORDER BY TotalDeathCount desc;

-- Breakdown by Continent
SELECT continent, MAX(CAST(total_deaths AS SIGNED)) AS TotalDeathCount
FROM coviddata.deaths
WHERE continent <> "" AND continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount desc;

SELECT location, MAX(CAST(total_deaths AS SIGNED)) AS TotalDeathCount
FROM coviddata.deaths
WHERE (continent IS NULL OR continent = "") AND location NOT LIKE "%income" AND location NOT IN ("World", "International", "European Union")
GROUP BY location
ORDER BY TotalDeathCount desc;

-- Global Numbers
-- 	Daily
SELECT date, SUM(new_cases) AS "DailyGlobalCases", SUM(CAST(new_deaths AS UNSIGNED)) AS "DailyGlobalDeaths", SUM(CAST(new_deaths AS UNSIGNED))/SUM(new_cases)*100 AS "DailyGlobalDeath%"
FROM coviddata.deaths
WHERE continent <> "" AND continent IS NOT NULL
GROUP BY date
ORDER BY 1,2;
-- 	Overall
SELECT SUM(new_cases) AS "GlobalCases", SUM(CAST(new_deaths AS SIGNED)) AS "GlobalDeaths", SUM(CAST(new_deaths AS SIGNED))/SUM(new_cases)*100 AS "GlobalDeath%"
FROM coviddata.deaths
WHERE continent <> "" AND continent IS NOT NULL
ORDER BY 1,2;



-- Joining Deaths and Vaccinations
SELECT *
FROM coviddata.deaths dea
JOIN coviddata.vaccinations vax ON dea.location = vax.location AND dea.date = vax.date;

-- Total Population vs Vaccinations
SELECT dea.continent, dea.location, dea.date, dea.population, vax.new_vaccinations
FROM coviddata.deaths dea
JOIN coviddata.vaccinations vax ON dea.location = vax.location AND dea.date = vax.date
WHERE dea.continent <> "" AND dea.continent IS NOT NULL
ORDER BY 2,3;


-- Create column to keep a rolling count of new vaccinations
SELECT dea.continent, dea.location, dea.date, dea.population, vax.new_vaccinations,
	SUM(CONVERT(new_vaccinations, UNSIGNED)) OVER (partition by dea.location ORDER by dea.location, dea.date) AS "RollingVaxCount"
FROM coviddata.deaths dea
JOIN coviddata.vaccinations vax ON dea.location = vax.location AND dea.date = vax.date
WHERE dea.continent <> "" AND dea.continent IS NOT NULL
ORDER BY 2,3;

-- Using a Common Table Expression (CTE) and creating a Rolling Vax Percentage column
WITH PercentVax (Continent, Location, Date, Population, NewVax, RollingVaxCount)
AS (
SELECT dea.continent, dea.location, dea.date, dea.population, vax.new_vaccinations,
	SUM(CONVERT(new_vaccinations, UNSIGNED)) OVER (partition by dea.location ORDER by dea.location, dea.date) AS "RollingVaxCount"
FROM coviddata.deaths dea
JOIN coviddata.vaccinations vax ON dea.location = vax.location AND dea.date = vax.date
WHERE dea.continent <> "" AND dea.continent IS NOT NULL
ORDER BY 2,3
)
SELECT *, (RollingVaxCount/Population)*100 AS "RollingVax%"
FROM PercentVax;

-- Creating a new table with a Rolling Vax Percentage column (alternate to above) *DID NOT WORK*
DROP TABLE IF EXISTS coviddata.PercentageVax;
CREATE TABLE coviddata.PercentageVax
	(Continent VARCHAR(255),
    Location VARCHAR(255),
    Date DATETIME,
    Population BIGINT,
    NewVax INT,
    RollingVaxCount INT);
    
INSERT INTO coviddata.PercentageVax (SELECT dea.continent, dea.location, dea.date, dea.population, vax.new_vaccinations,
	SUM(CONVERT(vax.new_vaccinations, UNSIGNED)) OVER (partition by dea.location ORDER by dea.location, dea.date) AS "RollingVaxCount"
FROM coviddata.deaths dea
JOIN coviddata.vaccinations vax ON dea.location = vax.location AND dea.date = vax.date
WHERE dea.continent <> "" AND dea.continent IS NOT NULL
ORDER BY 2,3);

SELECT *, (RollingVaxCount/Population)*100 AS "RollingVax%"
FROM coviddata.PercentageVax;


-- Create View for PercentVax
USE coviddata;
CREATE VIEW PercentVax AS (SELECT dea.continent, dea.location, dea.date, dea.population, vax.new_vaccinations,
	SUM(CONVERT(new_vaccinations, UNSIGNED)) OVER (partition by dea.location ORDER by dea.location, dea.date) AS "RollingVaxCount"
FROM coviddata.deaths dea
JOIN coviddata.vaccinations vax ON dea.location = vax.location AND dea.date = vax.date
WHERE dea.continent <> "" AND dea.continent IS NOT NULL);