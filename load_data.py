"""
Loads the real Our World in Data COVID-19 CSV into covid.db, splitting the
wide source file into CovidDeaths and CovidVaccinations.

The CSV is downloaded automatically if it isn't already present.
"""

import csv
import os
import sqlite3
import urllib.request

CSV_PATH = "owid-covid-data.csv"
CSV_URL = ("https://raw.githubusercontent.com/owid/covid-19-data/"
           "master/public/data/owid-covid-data.csv")
DB_PATH = "covid.db"


def to_num(s):
    """Empty -> None, otherwise float."""
    if s is None or s == "":
        return None
    try:
        return float(s)
    except ValueError:
        return None


def to_int(s):
    v = to_num(s)
    return int(v) if v is not None else None


def main():
    if not os.path.exists(CSV_PATH):
        print(f"Downloading {CSV_URL} ...")
        urllib.request.urlretrieve(CSV_URL, CSV_PATH)

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    deaths_rows, vacc_rows = [], []
    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            continent = r["continent"] or None      # blank -> NULL for aggregate rows
            deaths_rows.append((
                r["iso_code"], continent, r["location"], r["date"],
                to_int(r["population"]), to_num(r["total_cases"]),
                to_num(r["new_cases"]), to_num(r["total_deaths"]),
                to_num(r["new_deaths"]),
            ))
            vacc_rows.append((
                r["iso_code"], continent, r["location"], r["date"],
                to_int(r["population"]), to_num(r["total_tests"]),
                to_num(r["new_tests"]), to_num(r["positive_rate"]),
                to_num(r["total_vaccinations"]), to_num(r["people_vaccinated"]),
                to_num(r["people_fully_vaccinated"]), to_num(r["new_vaccinations"]),
                to_num(r["median_age"]), to_num(r["gdp_per_capita"]),
                to_num(r["hospital_beds_per_thousand"]), to_num(r["life_expectancy"]),
                to_num(r["human_development_index"]),
            ))

    cur.executemany(
        "INSERT INTO CovidDeaths VALUES (?,?,?,?,?,?,?,?,?)", deaths_rows)
    cur.executemany(
        "INSERT INTO CovidVaccinations VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        vacc_rows)
    conn.commit()

    print(f"Loaded {len(deaths_rows):,} rows into CovidDeaths")
    print(f"Loaded {len(vacc_rows):,} rows into CovidVaccinations")
    conn.close()


if __name__ == "__main__":
    main()
