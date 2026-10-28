"""Validate the high-ESS production source package without downloading or fitting."""
from pathlib import Path
from collections import Counter
import csv, hashlib, json, re, sys

root=Path(__file__).resolve().parents[1]
errors=[]
manifest=json.loads((root/'docs/SOURCE_MANIFEST.json').read_text(encoding='utf-8'))
for rec in manifest:
    p=root/rec['path']
    if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=rec['packaged_sha256']:
        errors.append('Missing or changed source: '+rec['path'])
    if p.suffix=='.html' and rec['source_sha256']!=rec['packaged_sha256']:
        errors.append('Frozen report changed')
source=(root/'production_report.Rmd').read_text(encoding='utf-8')
if 'joint_histflex_low_persist_global_full_ge2_high_ess.rds' not in source:
    errors.append('Full report does not use high-ESS cache')
if 'production_report.Rmd' not in (root/'run_pipeline.R').read_text(encoding='utf-8'):
    errors.append('Default pipeline does not render full report')
for p in [*root.glob('*.R'),*root.glob('*.Rmd'),*(root/'scripts').glob('*.R')]:
    if 'C:/Users/Owner' in p.read_text(encoding='utf-8'):
        errors.append('Nonportable path: '+p.name)
helper=(root/'scripts/fpet_model_helpers.R').read_text(encoding='utf-8')
if 'filter(n_surveys >= 3)' in helper or 'filter(n_surveys >= 2)' not in helper:
    errors.append('Wrong country inclusion rule')
with (root/'mcpr_data.csv').open(encoding='utf-8-sig',newline='') as f:
    data=list(csv.DictReader(f))
lookup_source=(root/'dhs_analysis_production.Rmd').read_text(encoding='utf-8').split('region_lookup <- c(',1)[1].split('\n)',1)[0]
lookup=dict(re.findall(r'"([^"]+)"\s*=\s*"([^"]+)"',lookup_source))
counts=Counter(r['country'] for r in data if r['country'] in lookup and r['mCPR'] not in ('','NA'))
included={c for c,n in counts.items() if n>=2}
if len(included)!=63:errors.append('Expected 63 eligible countries')
for p in root.rglob('*'):
    rel=p.relative_to(root)
    if any(t in ('.git','work','output','joint_ks_fpet_style') for t in rel.parts) or not p.is_file():continue
    if p.stat().st_size>=100*1024**2:errors.append('Over GitHub file limit: '+str(rel))
    if p.name in ('rdhs.json','.rdhs.json','.Renviron','auth.json') or p.suffix in ('.rds','.dta','.sav'):
        errors.append('Unexpected private/binary data: '+str(rel))
result={'passed':not errors,'source_files':len(manifest),'global_ge2_countries':len(included),'errors':errors}
print(json.dumps(result,indent=2))
sys.exit(bool(errors))
