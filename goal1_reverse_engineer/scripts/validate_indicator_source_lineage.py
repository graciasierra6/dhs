"""Validate indicator rankings directly against the two upstream DHS estimate files.

This provenance check is intentionally separate from the routine R build because
reading the original Excel workbook requires Python with pandas/openpyxl. It does
not modify any project file.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd


COUNTRIES = ("DRC", "Ethiopia", "Nigeria")
INDICATOR_SOURCE = {
    "wasting": "nutrition_zd_malaria_under20agefirstBTH_estimates_DHS.csv",
    "anemia_women": "nutrition_zd_malaria_under20agefirstBTH_estimates_DHS.csv",
    "malaria_rdt_positive": "nutrition_zd_malaria_under20agefirstBTH_estimates_DHS.csv",
    "zero_dose": "nutrition_zd_malaria_under20agefirstBTH_estimates_DHS.csv",
    "first_birth_under20": "nutrition_zd_malaria_under20agefirstBTH_estimates_DHS.csv",
    "facility_delivery": "Health_systems_combinedindicators_allcountries_REVISED.xlsx",
    "fever_care_seeking": "Health_systems_combinedindicators_allcountries_REVISED.xlsx",
    "anc4plus": "Health_systems_combinedindicators_allcountries_REVISED.xlsx",
}
DIRECTIONS = {
    "wasting": "adverse",
    "anemia_women": "adverse",
    "malaria_rdt_positive": "adverse",
    "zero_dose": "adverse",
    "first_birth_under20": "adverse",
    "facility_delivery": "beneficial",
    "fever_care_seeking": "beneficial",
    "anc4plus": "beneficial",
}
EXPECTED_COUNTRY_ROWS = {"DRC": 208, "Ethiopia": 77, "Nigeria": 296}
TOLERANCE = 1e-7


def canonical_admin(country: str, value: object) -> str:
    replacements = {
        "DRC": {
            "Kasai Central": "Kasai-Central",
            "Kasai Oriental": "Kasai-Oriental",
            "Kasaï Central": "Kasai-Central",
            "Kasaï Oriental": "Kasai-Oriental",
            "Kasaï": "Kasai",
            "Haut Lomami": "Haut-Lomami",
            "Haut uele": "Haut-Uele",
            "Haut Uele": "Haut-Uele",
            "Nord Ubangi": "Nord-Ubangi",
            "Sud Ubangi": "Sud-Ubangi",
            "Tanganika": "Tanganyika",
        },
        "Ethiopia": {
            "Affar": "Afar",
            "Benishangul-Gumuz": "Benishangul",
            "Beneshangul Gumu": "Benishangul",
            "Hareri": "Harari",
            "Oromiya": "Oromia",
        },
        "Nigeria": {
            "FCT": "FCT Abuja",
            "Abuja Federal Capital Territory": "FCT Abuja",
        },
    }
    text = str(value)
    return replacements.get(country, {}).get(text, text)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def max_abs_error(left: pd.Series, right: pd.Series) -> float:
    difference = np.abs(pd.to_numeric(left) - pd.to_numeric(right))
    return float(np.nanmax(difference.to_numpy())) if len(difference) else 0.0


def validate_master_copy(source: pd.DataFrame, master: pd.DataFrame) -> None:
    key = ["country", "survey_year", "indicator", "admin_name"]
    numeric = ["estimate", "se", "ci_l", "ci_u", "unweighted_n"]
    text = ["survey_source", "survey_label"]
    source_rows = source[key + numeric + text].copy()
    master_rows = master[key + numeric + text].copy()
    require(not source_rows.duplicated(key).any(), "Upstream files contain duplicate standard-indicator endpoint keys.")
    require(not master_rows.duplicated(key).any(), "Combined master contains duplicate standard-indicator endpoint keys.")
    joined = source_rows.merge(
        master_rows,
        on=key,
        how="outer",
        suffixes=("_source", "_master"),
        indicator=True,
        validate="one_to_one",
    )
    require(len(joined) == 1520, f"Expected 1,520 upstream endpoint rows; found {len(joined):,}.")
    require((joined["_merge"] == "both").all(), "Combined master keys do not exactly match the upstream source union.")
    for column in numeric:
        error = max_abs_error(joined[f"{column}_source"], joined[f"{column}_master"])
        require(error <= TOLERANCE, f"Combined master differs from upstream {column}; maximum error {error}.")
        source_na = joined[f"{column}_source"].isna()
        master_na = joined[f"{column}_master"].isna()
        require(source_na.equals(master_na), f"Combined master has different missingness for {column}.")
    for column in text:
        left = joined[f"{column}_source"].fillna("").astype(str)
        right = joined[f"{column}_master"].fillna("").astype(str)
        require(left.equals(right), f"Combined master differs from upstream {column}.")


def endpoint_join(rankings: pd.DataFrame, source: pd.DataFrame, endpoint: str) -> pd.DataFrame:
    year_column = f"{endpoint}_year"
    source_endpoint = source[
        ["country", "indicator", "survey_year", "canonical_admin", "estimate", "source_file"]
    ].rename(
        columns={
            "survey_year": year_column,
            "estimate": f"source_{endpoint}_estimate",
            "source_file": f"{endpoint}_source_file",
        }
    )
    return rankings.merge(
        source_endpoint,
        on=["country", "indicator", year_column, "canonical_admin"],
        how="left",
        validate="many_to_one",
        indicator=f"{endpoint}_match",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Project root (defaults to the parent of scripts/).",
    )
    args = parser.parse_args()
    root = args.root.resolve()
    source_dir = root / "data" / "source"

    nutrition_name = "nutrition_zd_malaria_under20agefirstBTH_estimates_DHS.csv"
    health_name = "Health_systems_combinedindicators_allcountries_REVISED.xlsx"
    nutrition = pd.read_csv(source_dir / nutrition_name)
    health = pd.read_excel(source_dir / health_name, sheet_name="in")
    nutrition["source_file"] = nutrition_name
    health["source_file"] = health_name
    source = pd.concat([nutrition, health], ignore_index=True, sort=False)
    source = source[
        source["country"].isin(COUNTRIES) & source["indicator"].isin(INDICATOR_SOURCE)
    ].copy()
    source["survey_year"] = pd.to_numeric(source["survey_year"], errors="raise").astype(int)
    source["canonical_admin"] = [
        canonical_admin(country, admin)
        for country, admin in zip(source["country"], source["admin_name"])
    ]
    expected_sources = source["indicator"].map(INDICATOR_SOURCE)
    require(
        source["source_file"].equals(expected_sources),
        "At least one standard indicator came from the wrong upstream file.",
    )

    master = pd.read_csv(root / "data" / "count_map_input_combined_master.csv")
    master = master[
        master["country"].isin(COUNTRIES) & master["indicator"].isin(INDICATOR_SOURCE)
    ].copy()
    master["survey_year"] = pd.to_numeric(master["survey_year"], errors="raise").astype(int)
    validate_master_copy(source, master)

    rankings = pd.read_csv(root / "data" / "subnational_indicator_rankings.csv")
    rankings = rankings[
        rankings["country"].isin(COUNTRIES) & rankings["indicator"].isin(INDICATOR_SOURCE)
    ].copy()
    require(len(rankings) == 581, f"Expected 581 ranking rows; found {len(rankings):,}.")
    require(
        rankings.groupby("country").size().to_dict() == EXPECTED_COUNTRY_ROWS,
        "Country ranking-row coverage is incorrect.",
    )
    require(
        not rankings.duplicated(["country", "indicator", "admin_name"]).any(),
        "Ranking input contains duplicate country-indicator-area rows.",
    )
    rankings["baseline_year"] = pd.to_numeric(rankings["baseline_year"], errors="raise").astype(int)
    rankings["latest_year"] = pd.to_numeric(rankings["latest_year"], errors="raise").astype(int)
    rankings["canonical_admin"] = [
        canonical_admin(country, admin)
        for country, admin in zip(rankings["country"], rankings["admin_name"])
    ]
    expected_directions = rankings["indicator"].map(DIRECTIONS)
    require(
        rankings["direction"].equals(expected_directions),
        "Ranking directions do not match the documented indicator definitions.",
    )

    audit = endpoint_join(rankings, source, "baseline")
    audit = endpoint_join(audit, source, "latest")
    require((audit["baseline_match"] == "both").all(), "At least one ranking baseline endpoint is absent upstream.")
    require((audit["latest_match"] == "both").all(), "At least one ranking latest endpoint is absent upstream.")
    require(
        audit["baseline_source_file"].equals(audit["indicator"].map(INDICATOR_SOURCE))
        and audit["latest_source_file"].equals(audit["indicator"].map(INDICATOR_SOURCE)),
        "At least one ranking endpoint is linked to the wrong upstream file.",
    )

    raw_change = audit["source_latest_estimate"] - audit["source_baseline_estimate"]
    beneficial = audit["direction"].eq("beneficial")
    risk_change = raw_change.where(~beneficial, -raw_change)
    recoded_baseline = audit["source_baseline_estimate"].where(
        ~beneficial, 100 - audit["source_baseline_estimate"]
    )
    recoded_latest = audit["source_latest_estimate"].where(
        ~beneficial, 100 - audit["source_latest_estimate"]
    )
    comparisons = {
        "baseline_estimate": (audit["baseline_estimate"], audit["source_baseline_estimate"]),
        "observed_latest_estimate": (audit["observed_latest_estimate"], audit["source_latest_estimate"]),
        "pp_change_10yr": (audit["pp_change_10yr"], raw_change),
        "recoded_baseline_estimate": (audit["recoded_baseline_estimate"], recoded_baseline),
        "recoded_observed_latest": (audit["recoded_observed_latest"], recoded_latest),
        "pp_change_10yr_recoded": (audit["pp_change_10yr_recoded"], risk_change),
    }
    maximum_errors = {}
    for field, (actual, expected) in comparisons.items():
        error = max_abs_error(actual, expected)
        maximum_errors[field] = error
        require(error <= TOLERANCE, f"Ranking {field} differs from the upstream endpoints; maximum error {error}.")

    endpoint_summary = (
        audit.groupby(["country", "indicator", "baseline_year", "latest_year"], as_index=False)
        .size()
        .sort_values(["country", "indicator"])
    )
    print("Direct source-lineage validation passed.")
    print("Upstream standard-indicator endpoint rows: 1,520")
    print("Ranking area-indicator rows: 581")
    print("Maximum endpoint/change error: {:.3g}".format(max(maximum_errors.values())))
    print(endpoint_summary.to_string(index=False))


if __name__ == "__main__":
    main()
