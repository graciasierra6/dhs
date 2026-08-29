(() => {
  const definitions = [{"id":"wasting","label":"Wasting","shortLabel":"Wasting","direction":"adverse"},{"id":"anemia_women","label":"Anemia (women)","shortLabel":"Anemia","direction":"adverse"},{"id":"malaria_rdt_positive","label":"Malaria RDT+","shortLabel":"Malaria RDT+","direction":"adverse"},{"id":"zero_dose","label":"Zero-dose","shortLabel":"Zero-dose","direction":"adverse"},{"id":"first_birth_under20","label":"First birth \u003c 20","shortLabel":"First birth \u003c20","direction":"adverse"},{"id":"facility_delivery","label":"Facility delivery","shortLabel":"Facility delivery","direction":"beneficial"},{"id":"fever_care_seeking","label":"Fever care seeking","shortLabel":"Fever care","direction":"beneficial"},{"id":"anc4plus","label":"ANC4+","shortLabel":"ANC4+","direction":"beneficial"}];
  const indicatorRows = {{INDICATOR_ROWS}};
  const classifications = {{CLASSIFICATIONS}};
  const mortalityRows = {{MORTALITY_ROWS}};
  const purpleScale = ["#F7FCFD","#E0ECF4","#BFD3E6","#9EBCDA","#8C96C6","#8C6BB1","#88419D","#810F7C","#4D004B"];
  const bivariateColors = {"improving:improving":"#F0EEE4","inside_threshold:improving":"#E8BC8D","worsening:improving":"#DF8A36","improving:inside_threshold":"#80B0A6","inside_threshold:inside_threshold":"#86856A","worsening:inside_threshold":"#8C592E","improving:worsening":"#107369","inside_threshold:worsening":"#254E48","worsening:worsening":"#3A2826"};
  const prevalenceRankBivariateColors = {"best:best":"#F0EEE4","middle:best":"#E8BC8D","worst:best":"#DF8A36","best:middle":"#80B0A6","middle:middle":"#86856A","worst:middle":"#8C592E","best:worst":"#107369","middle:worst":"#254E48","worst:worst":"#3A2826"};
  const statusLabels = {"improving":"Improving","inside_threshold":"Non-significant change","worsening":"Worsening","no_data":"No data"};
  const fmt = (value, digits = 1) => Number(value).toLocaleString("en-US", { minimumFractionDigits: digits, maximumFractionDigits: digits });
  const esc = (value) => String(value ?? "").replace(/[&<>"']/g, (character) => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[character]));
  const median = (values) => { const ordered = [...values].sort((a,b) => a-b); const middle = Math.floor(ordered.length/2); return ordered.length % 2 ? ordered[middle] : (ordered[middle-1] + ordered[middle]) / 2; };
  const colorForValue = (value, min, max, reverse = false) => { const progress = max === min ? .5 : (value-min)/(max-min); const index = Math.min(purpleScale.length-1, Math.floor(progress*purpleScale.length)); return purpleScale[reverse ? purpleScale.length-1-index : index]; };
  const rankBucketLabel = { best: "Best ranked", middle: "Middle ranked", worst: "Worst ranked" };
  const profileRankColors = { "Best fifth": "#BFD3E6", "Better half": "#8C96C6", "Worse half": "#88419D", "Worst fifth": "#4D004B" };
  const changeColors = { improving: "#2166AC", inside_threshold: "#8C8C8C", worsening: "#B2182B", no_data: "#8C8C8C" };
  const countryUnitCounts = Object.fromEntries(["drc","ethiopia","nigeria"].map((country) => [country, new Set(indicatorRows.filter((row) => row.country === country).map((row) => row.adminName)).size]));

  function rankBucket(rank, total) {
    if (!Number.isFinite(rank) || !Number.isFinite(total) || total <= 0) return null;
    const first = Math.ceil(total / 3);
    const second = Math.ceil((2 * total) / 3);
    if (rank <= first) return "best";
    if (rank <= second) return "middle";
    return "worst";
  }

  function ensureBivariateModeControl(section) {
    const controls = section.querySelector(".bivariate-controls");
    if (!controls || controls.querySelector('[data-role="biv-mode"]')) return;
    const resultBox = controls.querySelector(".bivariate-result");
    const modeLabel = document.createElement("label");
    modeLabel.className = "biv-mode-control";
    modeLabel.style.gridColumn = "1 / -1";
    modeLabel.style.maxWidth = "260px";
    modeLabel.innerHTML = '<span>Analysis Type</span><select data-role="biv-mode"><option value="change">Change over time</option><option value="prevalence_rank">Current rank</option></select>';
    if (resultBox) {
      controls.insertBefore(modeLabel, resultBox);
      const summary = resultBox.querySelector("span");
      if (summary && !summary.dataset.role) summary.dataset.role = "biv-summary-label";
    } else {
      controls.appendChild(modeLabel);
    }
  }

  function updateBivariateLegend(section, mode) {
    const title = section.querySelector(".bivariate-side-legend h4");
    if (title) title.textContent = mode === "prevalence_rank" ? "Prevalence Rank Classification" : "Risk-Aligned Change Classification";
    section.querySelectorAll(".biv-y-label small, .biv-x-label small").forEach((el) => {
      el.textContent = mode === "prevalence_rank" ? "Best ranked -> Worst ranked" : "Improving -> Worsening";
    });
    const swatches = [...section.querySelectorAll(".biv-grid i")];
    if (swatches.length !== 9) return;
    const keys = mode === "prevalence_rank"
      ? ["best:worst","middle:worst","worst:worst","best:middle","middle:middle","worst:middle","best:best","middle:best","worst:best"]
      : ["improving:worsening","inside_threshold:worsening","worsening:worsening","improving:inside_threshold","inside_threshold:inside_threshold","worsening:inside_threshold","improving:improving","inside_threshold:improving","worsening:improving"];
    const colors = mode === "prevalence_rank" ? prevalenceRankBivariateColors : bivariateColors;
    swatches.forEach((swatch, index) => {
      swatch.style.background = colors[keys[index]] || "#E7E2E8";
    });
  }

  function relabelChangeMapTooltips() {
    document.querySelectorAll('[id$="rank-change-shell"] .map-region').forEach((region) => {
      if (region.dataset.tip) {
        region.dataset.tip = region.dataset.tip
          .replace(/\bRank\b/g, "Change rank")
          .replace(/Composite score/g, "Composite change score");
      }
      const aria = region.getAttribute("aria-label");
      if (aria) {
        region.setAttribute("aria-label", aria
          .replace(/\bRank\b/g, "Change rank")
          .replace(/Composite score/g, "Composite change score"));
      }
    });
  }

  function resolveProfileImageType(region) {
    const section = region.closest("section");
    if (section?.classList.contains("bivariate-section")) {
      const mode = section.querySelector('[data-role="biv-mode"]')?.value || "change";
      return mode === "prevalence_rank" ? "prevalence" : "change";
    }
    const shellId = (region.closest(".map-shell")?.id || "").toLowerCase();
    if (shellId.includes("prevalence") || shellId.includes("indicator")) return "prevalence";
    if (shellId.includes("change") || shellId.includes("count")) return "change";
    const sectionId = (section?.id || "").toLowerCase();
    if (sectionId.includes("prevalence") || sectionId.includes("indicator")) return "prevalence";
    if (sectionId.includes("change") || sectionId.includes("count")) return "change";
    return "prevalence";
  }

  function bindTooltips() {
    document.addEventListener("pointerover", (event) => {
      const region = event.target.closest?.(".map-region");
      if (!region) return;
      const shell = region.closest(".map-shell");
      const tooltip = shell?.querySelector(".standalone-tooltip");
      if (!tooltip) return;
      tooltip.textContent = region.dataset.tip || region.dataset.name;
      tooltip.classList.add("visible");
    });
    document.addEventListener("pointermove", (event) => {
      const region = event.target.closest?.(".map-region");
      if (!region) return;
      const shell = region.closest(".map-shell");
      const tooltip = shell?.querySelector(".standalone-tooltip");
      if (!tooltip) return;
      const bounds = shell.getBoundingClientRect();
      tooltip.style.left = Math.min(event.clientX - bounds.left + 16, Math.max(20, bounds.width - 245)) + "px";
      tooltip.style.top = Math.max(event.clientY - bounds.top - 18, 10) + "px";
    });
    document.addEventListener("pointerout", (event) => {
      if (!event.target.closest?.(".map-region")) return;
      event.target.closest(".map-shell")?.querySelector(".standalone-tooltip")?.classList.remove("visible");
    });
    document.addEventListener("focusin", (event) => {
      const region = event.target.closest?.(".map-region"); if (!region) return;
      const tooltip = region.closest(".map-shell")?.querySelector(".standalone-tooltip");
      if (!tooltip) return; tooltip.textContent = region.dataset.tip || region.dataset.name; tooltip.style.left = "20px"; tooltip.style.top = "60px"; tooltip.classList.add("visible");
    });
    document.addEventListener("focusout", (event) => event.target.closest?.(".map-region")?.closest(".map-shell")?.querySelector(".standalone-tooltip")?.classList.remove("visible"));
    document.addEventListener("click", (event) => { const region = event.target.closest?.(".map-region"); if (!region) return; region.closest("svg")?.querySelectorAll(".is-selected").forEach((item) => item.classList.remove("is-selected")); region.classList.add("is-selected"); const country = region.closest("[data-country]")?.dataset.country || "drc"; const profileType = resolveProfileImageType(region); openProfile(region.dataset.name, country, profileType); });
    document.addEventListener("keydown", (event) => {
      const region = event.target.closest?.(".map-region");
      if (!region || !["Enter", " "].includes(event.key)) return;
      event.preventDefault();
      region.dispatchEvent(new MouseEvent("click", { bubbles: true }));
    });
  }

  function profileRankBand(rank, total) {
    const extreme = Math.ceil(total * 0.2);
    if (rank <= extreme) return "Best fifth";
    if (rank > total - extreme) return "Worst fifth";
    const betterEnd = extreme + Math.floor((total - 2 * extreme) / 2);
    return rank <= betterEnd ? "Better half" : "Worse half";
  }

  function profilePosition(value, min, max, direction, left, right, clamp = true) {
    const proportion = max === min ? 0.5 : (value - min) / (max - min);
    const aligned = direction === "beneficial" ? 1 - proportion : proportion;
    const plotted = clamp ? Math.max(0, Math.min(1, aligned)) : aligned;
    return left + plotted * (right - left);
  }

  function buildPrevalenceProfile(adminName, country) {
    const countryLabel = country === "drc" ? "DRC" : country[0].toUpperCase() + country.slice(1);
    const unitLabel = country === "drc" ? "province" : country === "nigeria" ? "state" : "region";
    const profileOrder = ["malaria_rdt_positive", "zero_dose", "facility_delivery", "anc4plus", "anemia_women", "fever_care_seeking", "wasting", "first_birth_under20"];
    const profileLabels = {
      malaria_rdt_positive: "Malaria RDT+",
      zero_dose: "Zero-dose",
      facility_delivery: "Facility delivery",
      anc4plus: "ANC4+",
      anemia_women: "Anemia, women",
      fever_care_seeking: "Fever care-seeking",
      wasting: "Wasting",
      first_birth_under20: "First birth <20"
    };
    const available = profileOrder
      .map((id) => definitions.find((definition) => definition.id === id))
      .filter((definition) => definition && indicatorRows.some((row) => row.country === country && row.adminName === adminName && row.indicator === definition.id));
    const width = 1180, height = 830;
    const labelX = 182, leftValueX = 280, left = 308, right = 782, rightValueX = 880, legendX = 1008;
    let marks = "";
    available.forEach((definition, index) => {
      const all = indicatorRows.filter((row) => row.country === country && row.indicator === definition.id);
      const selected = all.find((row) => row.adminName === adminName);
      if (!selected) return;
      const values = all.map((row) => Number(row.observedLatestEstimate));
      const min = Math.min(...values), max = Math.max(...values);
      const y = 72 + index * 63;
      const position = (value, clamp = true) => profilePosition(Number(value), min, max, definition.direction, left, right, clamp);
      const band = profileRankBand(Number(selected.prevalenceRank), all.length);
      const color = profileRankColors[band];
      const dots = all.map((row) => '<circle cx="' + position(row.observedLatestEstimate).toFixed(2) + '" cy="' + y + '" r="4.2" fill="#B8B8B8"/>').join("");
      const average = values.reduce((sum, value) => sum + value, 0) / values.length;
      const ciLeft = Math.min(position(selected.latestCiL, false), position(selected.latestCiU, false));
      const ciRight = Math.max(position(selected.latestCiL, false), position(selected.latestCiU, false));
      const selectedX = position(selected.observedLatestEstimate);
      const best = definition.direction === "beneficial" ? max : min;
      const worst = definition.direction === "beneficial" ? min : max;
      const showBest = Math.abs(Number(selected.observedLatestEstimate) - best) > 1e-8;
      const showWorst = Math.abs(Number(selected.observedLatestEstimate) - worst) > 1e-8;
      marks += '<g><text x="' + labelX + '" y="' + (y + 5) + '" text-anchor="end" class="profile-row-label">' + esc(profileLabels[definition.id]) + '</text>' +
        (showBest ? '<text x="' + leftValueX + '" y="' + (y + 5) + '" text-anchor="end" class="profile-end-value">' + fmt(best) + '%</text>' : '') +
        (showWorst ? '<text x="' + rightValueX + '" y="' + (y + 5) + '" text-anchor="end" class="profile-end-value">' + fmt(worst) + '%</text>' : '') +
        '<line x1="' + left + '" x2="' + right + '" y1="' + y + '" y2="' + y + '" class="profile-axis-line"/>' + dots +
        '<line x1="' + ciLeft.toFixed(2) + '" x2="' + ciRight.toFixed(2) + '" y1="' + y + '" y2="' + y + '" stroke="' + color + '" stroke-width="4" stroke-linecap="butt"/>' +
        '<line x1="' + position(average).toFixed(2) + '" x2="' + position(average).toFixed(2) + '" y1="' + (y - 13) + '" y2="' + (y + 13) + '" class="profile-average-tick"/>' +
        '<circle cx="' + selectedX.toFixed(2) + '" cy="' + y + '" r="9" fill="' + color + '"/>' +
        '<text x="' + selectedX.toFixed(2) + '" y="' + (y - 16) + '" text-anchor="middle" class="profile-selected-value">' + fmt(selected.observedLatestEstimate) + '%</text></g>';
    });
    const indicatorBottom = 72 + Math.max(0, available.length - 1) * 63;
    const mortalityStart = indicatorBottom + 98;
    ["U5MR", "NMR", "IMR"].forEach((indicator, index) => {
      const all = mortalityRows.filter((row) => row.country === country && row.indicator === indicator);
      const selected = all.find((row) => row.adminName === adminName);
      if (!selected || !all.length) return;
      const values = all.map((row) => Number(row.value));
      const min = Math.min(...values), max = Math.max(...values), y = mortalityStart + index * 62;
      const position = (value) => profilePosition(Number(value), min, max, "adverse", left, right);
      const average = values.reduce((sum, value) => sum + value, 0) / values.length;
      const showMin = Math.abs(Number(selected.value) - min) > 1e-8;
      const showMax = Math.abs(Number(selected.value) - max) > 1e-8;
      marks += '<g><text x="' + labelX + '" y="' + (y + 5) + '" text-anchor="end" class="profile-row-label">' + indicator + '</text>' +
        (showMin ? '<text x="' + leftValueX + '" y="' + (y + 5) + '" text-anchor="end" class="profile-end-value">' + fmt(min, 0) + '</text>' : '') +
        (showMax ? '<text x="' + rightValueX + '" y="' + (y + 5) + '" text-anchor="end" class="profile-end-value">' + fmt(max, 0) + '</text>' : '') +
        '<line x1="' + left + '" x2="' + right + '" y1="' + y + '" y2="' + y + '" class="profile-axis-line"/>' +
        all.map((row) => '<circle cx="' + position(row.value).toFixed(2) + '" cy="' + y + '" r="4.2" fill="#B8B8B8"/>').join("") +
        '<line x1="' + position(average).toFixed(2) + '" x2="' + position(average).toFixed(2) + '" y1="' + (y - 13) + '" y2="' + (y + 13) + '" class="profile-average-tick"/>' +
        '<circle cx="' + position(selected.value).toFixed(2) + '" cy="' + y + '" r="9" fill="#3B3B3B"/>' +
        '<text x="' + position(selected.value).toFixed(2) + '" y="' + (y - 16) + '" text-anchor="middle" class="profile-selected-value">' + fmt(selected.value, 0) + '</text></g>';
    });
    const legendOrder = ["Worst fifth", "Worse half", "Better half", "Best fifth"];
    const legend = legendOrder.map((label, index) => '<g transform="translate(' + legendX + ',' + (357 + index * 38) + ')"><circle r="8.5" fill="' + profileRankColors[label] + '"/><text x="23" y="6" class="profile-legend-text">' + label + '</text></g>').join("");
    return '<svg class="profile-chart profile-chart--prevalence" viewBox="0 0 ' + width + ' ' + height + '" role="img" aria-label="Prevalence and mortality profile for ' + esc(adminName) + '">' +
      '<title>' + esc(adminName) + ' subnational prevalence profile</title><desc>Indicator distributions compare ' + esc(adminName) + ' with all administrative areas in ' + countryLabel + '.</desc>' + marks +
      '<text x="' + legendX + '" y="296" class="profile-legend-title"><tspan x="' + legendX + '">Prevalence rank</tspan><tspan x="' + legendX + '" dy="24">within ' + countryLabel + '</tspan></text>' + legend +
      '<text x="' + left + '" y="' + (mortalityStart + 154) + '" text-anchor="middle" class="profile-axis-caption">best ' + unitLabel + '</text><text x="' + right + '" y="' + (mortalityStart + 154) + '" text-anchor="middle" class="profile-axis-caption">worst ' + unitLabel + '</text>' +
      '<text x="' + width / 2 + '" y="' + (height - 35) + '" text-anchor="middle" class="profile-footnote"><tspan x="' + width / 2 + '">Source: DHS. Each row is scaled to that indicator\'s own observed range across the ' + countryUnitCounts[country] + ' ' + unitLabel + 's; tick = average ' + unitLabel + '; bar = 95% CI on the highlighted ' + unitLabel + '.</tspan><tspan x="' + width / 2 + '" dy="17">Lower block: under-five, neonatal and infant mortality, deaths per 1,000 live births, 2020\u201324 window - dot only, no interval, not rank-coloured.</tspan></text></svg>';
  }

  function changeProfileDefinition(definition) {
    const labels = {
      facility_delivery: ["Births outside", "a facility"],
      fever_care_seeking: ["Fever, no", "care sought"],
      anc4plus: ["Fewer than 4", "ANC visits"],
      anemia_women: ["Anemia", "(women)"],
      malaria_rdt_positive: ["Malaria", "RDT+"],
      wasting: ["Wasting"],
      zero_dose: ["Zero-dose"],
      first_birth_under20: ["First birth", "<20"]
    };
    return labels[definition.id] || [definition.shortLabel];
  }

  function riskAlignedEndpoint(value, direction) {
    return direction === "beneficial" ? 100 - Number(value) : Number(value);
  }

  function buildChangeProfile(adminName, country) {
    const order = ["facility_delivery", "fever_care_seeking", "anc4plus", "anemia_women", "malaria_rdt_positive", "wasting", "zero_dose", "first_birth_under20"];
    const selectedRows = order.map((id) => indicatorRows.find((row) => row.country === country && row.adminName === adminName && row.indicator === id)).filter(Boolean);
    const width = 1180, height = 650, panelWidth = 260, panelHeight = 238, gapX = 14;
    let panels = "";
    selectedRows.forEach((row, index) => {
      const definition = definitions.find((item) => item.id === row.indicator);
      const classification = classifications.find((item) => item.country === country && item.adminName === adminName && item.indicator === row.indicator)?.classification || "no_data";
      const color = changeColors[classification];
      const column = index % 4, panelRow = Math.floor(index / 4), x0 = 64 + column * (panelWidth + gapX), y0 = 18 + panelRow * 260;
      const plotLeft = x0 + 42, plotRight = x0 + panelWidth - 18, plotTop = y0 + 58, plotBottom = y0 + panelHeight - 24;
      const y = (value) => plotBottom - Math.max(0, Math.min(100, value)) / 100 * (plotBottom - plotTop);
      const baseline = riskAlignedEndpoint(row.baselineEstimate, definition.direction), latest = riskAlignedEndpoint(row.observedLatestEstimate, definition.direction);
      const baselineLow = riskAlignedEndpoint(definition.direction === "beneficial" ? row.baselineCiU : row.baselineCiL, definition.direction);
      const baselineHigh = riskAlignedEndpoint(definition.direction === "beneficial" ? row.baselineCiL : row.baselineCiU, definition.direction);
      const latestLow = riskAlignedEndpoint(definition.direction === "beneficial" ? row.latestCiU : row.latestCiL, definition.direction);
      const latestHigh = riskAlignedEndpoint(definition.direction === "beneficial" ? row.latestCiL : row.latestCiU, definition.direction);
      const headerLines = changeProfileDefinition(definition);
      const grids = [0, 25, 50, 75, 100].map((tick) => '<line x1="' + plotLeft + '" x2="' + plotRight + '" y1="' + y(tick) + '" y2="' + y(tick) + '" class="change-grid"/>' + (column === 0 ? '<text x="' + (plotLeft - 9) + '" y="' + (y(tick) + 4) + '" text-anchor="end" class="change-tick">' + tick + '</text>' : '')).join("");
      panels += '<g><rect x="' + x0 + '" y="' + y0 + '" width="' + panelWidth + '" height="' + panelHeight + '" class="change-panel"/><rect x="' + x0 + '" y="' + y0 + '" width="' + panelWidth + '" height="42" class="change-panel-header"/>' +
        '<text x="' + (x0 + panelWidth / 2) + '" y="' + (y0 + 17) + '" text-anchor="middle" class="change-panel-title">' + headerLines.map((line, lineIndex) => '<tspan x="' + (x0 + panelWidth / 2) + '" dy="' + (lineIndex ? 15 : 0) + '">' + esc(line) + '</tspan>').join("") + '</text>' + grids +
        '<line x1="' + plotLeft + '" x2="' + plotLeft + '" y1="' + y(baselineLow) + '" y2="' + y(baselineHigh) + '" stroke="' + color + '" class="change-ci"/><line x1="' + plotRight + '" x2="' + plotRight + '" y1="' + y(latestLow) + '" y2="' + y(latestHigh) + '" stroke="' + color + '" class="change-ci"/>' +
        '<line x1="' + plotLeft + '" x2="' + plotRight + '" y1="' + y(baseline) + '" y2="' + y(latest) + '" stroke="' + color + '" class="change-line"/><circle cx="' + plotLeft + '" cy="' + y(baseline) + '" r="5" fill="' + color + '"/><circle cx="' + plotRight + '" cy="' + y(latest) + '" r="5" fill="' + color + '"/>' +
        '<text x="' + plotLeft + '" y="' + (plotBottom + 18) + '" text-anchor="middle" class="change-year">' + esc(row.baselineDisplayYear || row.baselineYear) + '</text><text x="' + plotRight + '" y="' + (plotBottom + 18) + '" text-anchor="middle" class="change-year">' + esc(row.latestDisplayYear || row.latestYear) + '</text></g>';
    });
    const legendItems = [["worsening", "Worsening"], ["inside_threshold", "Non-significant change"], ["improving", "Improving"]];
    const legend = legendItems.map(([key, label], index) => '<g transform="translate(' + (420 + index * 190) + ',580)"><circle r="6" fill="' + changeColors[key] + '"/><text x="15" y="4" class="profile-legend-text">' + label + '</text></g>').join("");
    return '<svg class="profile-chart profile-chart--change" viewBox="0 0 ' + width + ' ' + height + '" role="img" aria-label="Risk-aligned indicator change profile for ' + esc(adminName) + '"><title>' + esc(adminName) + ' risk-aligned indicator change profile</title><desc>Baseline and latest prevalence estimates with 95% confidence intervals. Beneficial coverage indicators are inverted so higher values consistently mean worse outcomes.</desc>' +
      '<text x="20" y="285" transform="rotate(-90 20 285)" text-anchor="middle" class="change-axis-title">Risk-aligned prevalence (%)</text>' + panels + legend +
      '<text x="35" y="625" class="profile-footnote">Source: DHS. Endpoints and 95% confidence intervals are generated from the validated profile input data.</text></svg>';
  }

  function buildProfileRows(adminName, country) {
    return definitions
      .filter((definition) => indicatorRows.some((entry) => entry.adminName === adminName && entry.indicator === definition.id && entry.country === country))
      .sort((a, b) => a.label.localeCompare(b.label))
      .map((definition) => {
      const row = indicatorRows.find((entry) => entry.adminName === adminName && entry.indicator === definition.id && entry.country === country);
      const classification = classifications.find((entry) => entry.adminName === adminName && entry.indicator === definition.id && entry.country === country);
      return {
        label: definition.label,
        baselineYear: row?.baselineYear ?? "",
        baselineEstimate: row?.baselineEstimate != null ? fmt(row.baselineEstimate) : "",
        latestYear: row?.latestYear ?? "",
        latestEstimate: row ? fmt(row.observedLatestEstimate) : "",
        change: row ? (row.ppChange10yrRecoded > 0 ? "+" : "") + fmt(row.ppChange10yrRecoded) : "",
        prevalenceRank: row?.prevalenceRank ?? "",
        changeRank: row?.changeRank ?? "",
        status: classification ? statusLabels[classification.classification] || classification.classification : ""
      };
    });
  }

  function openProfile(adminName, country, profileType = "prevalence") {
    if (!adminName) return;
    document.getElementById("profile-title").textContent = adminName;
    const imageWrap = document.getElementById("profile-image-wrap");
    const hasProfile = indicatorRows.some((row) => row.country === country && row.adminName === adminName);
    imageWrap.innerHTML = hasProfile
      ? (profileType === "change" ? buildChangeProfile(adminName, country) : buildPrevalenceProfile(adminName, country))
      : '<div class="profile-image-empty">No profile data available.</div>';
    document.getElementById("profile-panel-body").scrollTop = 0;
    const panel = document.getElementById("profile-panel");
    panel.dataset.adminName = adminName;
    panel.dataset.country = country;
    panel.dataset.profileType = profileType;
    panel.classList.add("open");
    panel.setAttribute("aria-hidden", "false");
    document.getElementById("profile-overlay").classList.add("open");
    document.getElementById("profile-close").focus();
  }

  function closeProfile() {
    document.getElementById("profile-panel").classList.remove("open");
    document.getElementById("profile-panel").setAttribute("aria-hidden", "true");
    document.getElementById("profile-overlay").classList.remove("open");
  }

  function downloadProfileCsv() {
    const panel = document.getElementById("profile-panel");
    const adminName = panel.dataset.adminName;
    const country = panel.dataset.country;
    if (!adminName) return;
    const rows = buildProfileRows(adminName, country);
    const csvEscape = (value) => { const text = String(value ?? ""); return /[",\n]/.test(text) ? '"' + text.replace(/"/g, '""') + '"' : text; };
    const header = ["Province", "Indicator", "Baseline year", "Baseline estimate", "Latest year", "Latest estimate", "Change (pp)", "Prevalence rank", "Status"];
    const lines = [header.join(",")].concat(rows.map((row) => [adminName, row.label, row.baselineYear, row.baselineEstimate, row.latestYear, row.latestEstimate, row.change, row.prevalenceRank, row.status].map(csvEscape).join(",")));
    const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = adminName.replace(/\s+/g, "_") + "_subnational_profile.csv";
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
  }

  document.getElementById("profile-close").addEventListener("click", closeProfile);
  document.getElementById("profile-overlay").addEventListener("click", closeProfile);
  document.getElementById("profile-download").addEventListener("click", downloadProfileCsv);
  document.addEventListener("keydown", (event) => { if (event.key === "Escape") closeProfile(); });

  function updateIndicator(id, section) {
    const country = section?.closest("[data-country]")?.dataset.country || "drc";
    const definition = definitions.find((item) => item.id === id) || definitions[0];
    const rows = indicatorRows.filter((row) => row.indicator === definition.id && row.country === country).sort((a,b) => b.observedLatestEstimate - a.observedLatestEstimate);
    const byName = new Map(rows.map((row) => [row.adminName, row]));
    const values = rows.map((row) => row.observedLatestEstimate);
    const min = Math.min(...values), max = Math.max(...values);
    const years = [...new Set(rows.map((row) => row.latestYear))].sort();
    const measure = definition.direction === "beneficial" ? "coverage" : "prevalence";
    section.querySelectorAll("[data-indicator]").forEach((button) => { const active = button.dataset.indicator === id; button.classList.toggle("active", active); button.setAttribute("aria-selected", String(active)); });
    section.querySelector('[data-role="indicator-name"]').textContent = definition.label;
    section.querySelector('[data-role="indicator-year"]').textContent = years.join(", ");
    section.querySelector('[data-role="indicator-median-label"]').textContent = "Median " + measure;
    section.querySelector('[data-role="indicator-median"]').textContent = fmt(median(values)) + "%";
    section.querySelector('[data-role="indicator-range-label"]').textContent = "Across " + rows.length + " areas";
    section.querySelector('[data-role="indicator-range"]').textContent = fmt(min) + "\u2014" + fmt(max) + "%";
    section.querySelector('[data-role="indicator-map-title"]').textContent = definition.label;
    section.querySelector('[data-role="indicator-legend-top"]').textContent = fmt(definition.direction === "beneficial" ? min : max, 0) + "%";
    section.querySelector('[data-role="indicator-legend-bottom"]').textContent = fmt(definition.direction === "beneficial" ? max : min, 0) + "%";
    section.querySelector('[data-role="bar-title"]').textContent = definition.label;
    section.querySelector('[data-role="bar-count"]').textContent = rows.length + " areas \u2014 %";
    const note = section.querySelector('[data-role="indicator-note"]');
    if (note) {
      note.hidden = years.every((year) => year === 2024);
      note.textContent = "Latest available year shown: " + years.join(", ") + ".";
    }
    section.querySelectorAll(".indicator-region").forEach((region) => {
      const row = byName.get(region.dataset.name);
      region.setAttribute("fill", row ? colorForValue(row.observedLatestEstimate, min, max, definition.direction === "beneficial") : "#E7E2E8");
      region.dataset.tip = row ? region.dataset.name + "\n" + fmt(row.observedLatestEstimate) + "% observed " + measure + "\n" + row.latestYear + " estimate" : region.dataset.name + "\nNo data";
      region.setAttribute("aria-label", region.dataset.tip.replaceAll("\n", ", "));
    });
    const barsContainer = section.querySelector('[data-role="indicator-bars"]');
    barsContainer.innerHTML = "";
    rows.forEach((row) => {
      const barRow = document.createElement("div");
      barRow.className = "bar-row";
      const nameSpan = document.createElement("span");
      nameSpan.textContent = row.adminName;
      barRow.appendChild(nameSpan);
      const trackDiv = document.createElement("div");
      trackDiv.className = "bar-track";
      const barI = document.createElement("i");
      barI.style.width = Math.max(2, Math.min(100, row.observedLatestEstimate)) + "%";
      trackDiv.appendChild(barI);
      barRow.appendChild(trackDiv);
      const valueStrong = document.createElement("strong");
      valueStrong.textContent = fmt(row.observedLatestEstimate);
      barRow.appendChild(valueStrong);
      barsContainer.appendChild(barRow);
    });
  }

  function updateBivariateSection(section) {
    const country = section.closest("[data-country]")?.dataset.country || "drc";
    const xSelect = section.querySelector('[data-role="biv-x"]'), ySelect = section.querySelector('[data-role="biv-y"]'), modeSelect = section.querySelector('[data-role="biv-mode"]');
    const mode = modeSelect?.value || "change";
    if (!xSelect || !ySelect) return;
    const x = definitions.find((item) => item.id === xSelect.value), y = definitions.find((item) => item.id === ySelect.value);
    if (!x || !y) return;
    const totalUnits = countryUnitCounts[country] || 0;
    const rowLookup = new Map(indicatorRows.filter((row) => row.country === country).map((row) => [row.adminName + "|" + row.indicator, row]));
    const lookup = new Map(classifications.filter((row) => row.country === country).map((row) => [row.adminName + "|" + row.indicator, row]));
    let both = 0;
    section.querySelectorAll(".biv-region").forEach((region) => {
      const xrRow = rowLookup.get(region.dataset.name + "|" + x.id), yrRow = rowLookup.get(region.dataset.name + "|" + y.id);
      const xr = lookup.get(region.dataset.name + "|" + x.id), yr = lookup.get(region.dataset.name + "|" + y.id);
      if (mode === "prevalence_rank") {
        const xRank = xrRow ? Number(xrRow.prevalenceRank) : NaN;
        const yRank = yrRow ? Number(yrRow.prevalenceRank) : NaN;
        const xb = rankBucket(xRank, totalUnits);
        const yb = rankBucket(yRank, totalUnits);
        if (xb === "worst" && yb === "worst") both++;
        region.setAttribute("fill", xb && yb ? (prevalenceRankBivariateColors[xb + ":" + yb] || "#E7E2E8") : "#E7E2E8");
        region.dataset.tip = xrRow && yrRow
          ? region.dataset.name + "\n" + x.label + ": Rank " + xRank + " / " + totalUnits + " (" + rankBucketLabel[xb] + ") \u2014 Latest observed " + fmt(xrRow.observedLatestEstimate) + "% (" + xrRow.latestYear + ")\n" + y.label + ": Rank " + yRank + " / " + totalUnits + " (" + rankBucketLabel[yb] + ") \u2014 Latest observed " + fmt(yrRow.observedLatestEstimate) + "% (" + yrRow.latestYear + ")"
          : region.dataset.name + "\nNo paired data";
      } else {
        if (xr?.classification === "worsening" && yr?.classification === "worsening") both++;
        region.setAttribute("fill", xr && yr ? (bivariateColors[xr.classification + ":" + yr.classification] || "#E7E2E8") : "#E7E2E8");
        region.dataset.tip = xr && yr ? region.dataset.name + "\n" + x.label + ": " + statusLabels[xr.classification] + " \u2014 Latest observed " + fmt(xr.observedLatestEstimate) + "% (" + xr.latestYear + ") \u2014 " + (xr.ppChange10yrRecoded > 0 ? "+" : "") + fmt(xr.ppChange10yrRecoded) + " pp\n" + y.label + ": " + statusLabels[yr.classification] + " \u2014 Latest observed " + fmt(yr.observedLatestEstimate) + "% (" + yr.latestYear + ") \u2014 " + (yr.ppChange10yrRecoded > 0 ? "+" : "") + fmt(yr.ppChange10yrRecoded) + " pp" : region.dataset.name + "\nNo paired data";
      }
      region.setAttribute("aria-label", region.dataset.tip.replaceAll("\n", ", "));
    });
    const titleEl = section.querySelector('[data-role="map-title"]'); if (titleEl) titleEl.textContent = x.shortLabel + " \u2014 " + y.shortLabel;
    const xLabelEl = section.querySelector('[data-role="biv-x-label"]'); if (xLabelEl) xLabelEl.textContent = x.shortLabel;
    const yLabelEl = section.querySelector('[data-role="biv-y-label"]'); if (yLabelEl) yLabelEl.textContent = y.shortLabel;
    const bothEl = section.querySelector('[data-role="biv-both"]'); if (bothEl) bothEl.textContent = both;
    const bothLabelEl = section.querySelector('[data-role="biv-summary-label"]');
    if (bothLabelEl) bothLabelEl.textContent = mode === "prevalence_rank" ? "areas where both are worst-ranked" : "areas where both worsened";
    updateBivariateLegend(section, mode);
  }

  function alphabetizeIndicatorTabs() {
    document.querySelectorAll(".indicator-section .indicator-tabs").forEach((tabs) => {
      [...tabs.querySelectorAll("button[data-indicator]")]
        .sort((a, b) => a.textContent.trim().localeCompare(b.textContent.trim(), "en", { sensitivity: "base" }))
        .forEach((button) => tabs.appendChild(button));
    });
  }

  function initializeIndicatorSections() {
    const initialized = [];
    document.querySelectorAll(".indicator-section").forEach((section) => {
      const country = section.closest("[data-country]")?.dataset.country || "drc";
      const tabs = section.querySelector(".indicator-tabs");
      if (!tabs) return;
      const available = definitions
        .filter((definition) => indicatorRows.some((row) => row.country === country && row.indicator === definition.id))
        .sort((a, b) => a.shortLabel.localeCompare(b.shortLabel, "en", { sensitivity: "base" }));
      const previousActive = tabs.querySelector("button.active[data-indicator]")?.dataset.indicator;
      const initialIndicator = available.some((definition) => definition.id === previousActive)
        ? previousActive
        : available[0]?.id;
      tabs.replaceChildren();
      available.forEach((definition) => {
        const button = document.createElement("button");
        button.type = "button";
        button.setAttribute("role", "tab");
        button.dataset.indicator = definition.id;
        button.textContent = definition.shortLabel;
        const active = definition.id === initialIndicator;
        button.classList.toggle("active", active);
        button.setAttribute("aria-selected", String(active));
        button.addEventListener("click", () => updateIndicator(definition.id, section));
        tabs.appendChild(button);
      });
      if (initialIndicator) initialized.push([initialIndicator, section]);
    });
    alphabetizeIndicatorTabs();
    initialized.forEach(([indicator, section]) => updateIndicator(indicator, section));
  }

  function applyWorseningCountPalette() {
    const countPaletteYlGn = {
      "0\u20131": "#FFFFE5",
      "2\u20133": "#ADDD8E",
      "4": "#41AB5D",
      "5\u20136": "#004529"
    };
    document.querySelectorAll(".count-section").forEach((section) => {
      section.querySelectorAll("use.map-region").forEach((region) => {
        const count = Number((region.dataset.tip || "").match(/(?:^|\n)(\d+) Worsening:/)?.[1]);
        const bucket = count <= 1 ? "0\u20131" : count <= 3 ? "2\u20133" : count === 4 ? "4" : "5\u20136";
        region.setAttribute("fill", countPaletteYlGn[bucket]);
      });
      const legend = section.querySelector(".discrete-legend");
      if (!legend) return;
      legend.innerHTML = "";
      ["5\u20136", "4", "2\u20133", "0\u20131"].forEach((label) => {
        const item = document.createElement("span");
        const swatch = document.createElement("i");
        swatch.style.background = countPaletteYlGn[label];
        item.append(swatch, label);
        legend.appendChild(item);
      });
    });
  }

  applyWorseningCountPalette();
  relabelChangeMapTooltips();
  bindTooltips();
  document.querySelectorAll(".bivariate-section").forEach((section) => ensureBivariateModeControl(section));
  initializeIndicatorSections();
  document.querySelectorAll(".bivariate-section").forEach((section) => {
    const xSelect = section.querySelector('[data-role="biv-x"]'), ySelect = section.querySelector('[data-role="biv-y"]'), modeSelect = section.querySelector('[data-role="biv-mode"]');
    if (!xSelect || !ySelect) return;
    if (!xSelect.value) xSelect.value = xSelect.options[0]?.value;
    if (!ySelect.value || ySelect.value === xSelect.value) { const alt = [...ySelect.options].find((opt) => opt.value !== xSelect.value); if (alt) ySelect.value = alt.value; }
    const handleChange = (changed) => () => {
      if (xSelect.value === ySelect.value) {
        const other = changed === "x" ? ySelect : xSelect;
        const current = changed === "x" ? xSelect.value : ySelect.value;
        const alt = [...other.options].find((opt) => opt.value !== current);
        if (alt) other.value = alt.value;
      }
      updateBivariateSection(section);
    };
    xSelect.addEventListener("change", handleChange("x"));
    ySelect.addEventListener("change", handleChange("y"));
    modeSelect?.addEventListener("change", () => updateBivariateSection(section));
    updateBivariateSection(section);
  });
  const sections = [...document.querySelectorAll("main [id]")];
  if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver((entries) => { const visible = entries.filter((entry) => entry.isIntersecting).sort((a,b) => b.intersectionRatio-a.intersectionRatio); if (!visible[0]) return; document.querySelectorAll(".nav-sections a").forEach((link) => link.classList.toggle("active", link.getAttribute("href") === "#" + visible[0].target.id)); }, { rootMargin: "-18% 0px -68% 0px", threshold: [0,.1,.35] });
    sections.forEach((section) => observer.observe(section));
  }

  function activateTab(country, tabName) {
    document.querySelectorAll(".tab-panel").forEach((panel) => panel.classList.toggle("active", panel.dataset.country === country && panel.dataset.tabPanel === tabName));
    document.querySelectorAll(".tab-btn").forEach((btn) => { const on = btn.dataset.country === country && btn.dataset.tab === tabName; btn.classList.toggle("active", on); btn.setAttribute("aria-selected", on); });
    document.querySelectorAll(".nav-chapter").forEach((chapter) => chapter.classList.toggle("active", chapter.dataset.country === country && chapter.dataset.tab === tabName));
  }

  function activateCountry(country, tabName) {
    document.querySelectorAll(".nav-country").forEach((link) => link.classList.toggle("active", link.dataset.country === country));
    document.querySelectorAll(".country-scoped").forEach((el) => { el.hidden = el.dataset.country !== country; });
    const tabBar = document.querySelector(".tab-bar");
    tabBar.hidden = !document.querySelector('.tab-btn[data-country="' + country + '"]');
    const defaultTab = tabName || document.querySelector('.tab-btn[data-country="' + country + '"]')?.dataset.tab || document.querySelector('.tab-panel[data-country="' + country + '"]')?.dataset.tabPanel || "overview";
    activateTab(country, defaultTab);
  }

  document.querySelectorAll(".tab-btn").forEach((btn) => btn.addEventListener("click", () => activateTab(btn.dataset.country, btn.dataset.tab)));

  document.querySelectorAll(".nav-country").forEach((link) => link.addEventListener("click", (event) => {
    event.preventDefault();
    activateCountry(link.dataset.country);
    requestAnimationFrame(() => document.getElementById(link.dataset.country)?.scrollIntoView());
  }));

  document.querySelectorAll("a[data-tab]").forEach((link) => link.addEventListener("click", (event) => {
    const targetId = link.getAttribute("href").slice(1);
    const target = document.getElementById(targetId);
    if (!target) return;
    const alreadyActive = target.closest(".tab-panel")?.classList.contains("active") ?? true;
    activateCountry(link.dataset.country, link.dataset.tab);
    if (!alreadyActive) { event.preventDefault(); requestAnimationFrame(() => target.scrollIntoView()); }
  }));

  const initialTarget = location.hash ? document.getElementById(location.hash.slice(1)) : null;
  const initialPanel = initialTarget?.closest(".tab-panel");
  activateCountry(initialPanel?.dataset.country || "drc", initialPanel?.dataset.tabPanel);
})();
