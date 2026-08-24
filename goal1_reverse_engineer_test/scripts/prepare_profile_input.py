"""Create the build-ready indicator profile input from the archived source files.

This is a provenance utility, not a render-time dependency. The generated CSV is
committed under data/ so the R Markdown build does not require Python or Excel.
"""

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data" / "source"
OUTPUT = ROOT / "data" / "profile_indicator_estimates.csv"
STANDARD_INDICATORS = {
    "wasting",
    "anemia_women",
    "malaria_rdt_positive",
    "zero_dose",
    "first_birth_under20",
    "facility_delivery",
    "fever_care_seeking",
    "anc4plus",
}
COLUMNS = [
    "country",
    "survey_year",
    "survey_source",
    "survey_label",
    "indicator",
    "admin_name",
    "estimate",
    "ci_l",
    "ci_u",
]


def main() -> None:
    nutrition = pd.read_csv(
        SOURCE / "nutrition_zd_malaria_under20agefirstBTH_estimates_DHS.csv"
    )
    health_systems = pd.read_excel(
        SOURCE / "Health_systems_combinedindicators_allcountries_REVISED.xlsx",
        sheet_name="in",
    )
    combined = pd.concat([nutrition, health_systems], ignore_index=True)
    combined = combined.loc[
        combined["country"].isin(["DRC", "Ethiopia", "Nigeria"])
        & combined["indicator"].isin(STANDARD_INDICATORS),
        COLUMNS,
    ].copy()
    combined["survey_year"] = combined["survey_year"].astype(int)
    combined = combined.sort_values(
        ["country", "indicator", "survey_year", "admin_name"]
    )
    duplicate = combined.duplicated(
        ["country", "indicator", "survey_year", "admin_name"], keep=False
    )
    if duplicate.any():
        keys = combined.loc[
            duplicate, ["country", "indicator", "survey_year", "admin_name"]
        ]
        raise RuntimeError(f"Duplicate profile records:\n{keys.to_string(index=False)}")
    combined.to_csv(OUTPUT, index=False, lineterminator="\n")
    print(f"Wrote {len(combined):,} records to {OUTPUT}")


if __name__ == "__main__":
    main()
