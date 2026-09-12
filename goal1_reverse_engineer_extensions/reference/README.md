# Optional large reference file

The original `reference_dashboard.html` benchmark is visual provenance only.
It is stored outside the browser-uploadable project in the local
`goal1_reverse_engineer_large_reference_backup` folder because it exceeds the
repository's 10 MB per-file rule.

The normal `render.R` and `validate.R` workflows do not require it. Restore it
to this directory only when rerunning the one-time
`scripts/extract_reference_assets.py` decomposition helper.
