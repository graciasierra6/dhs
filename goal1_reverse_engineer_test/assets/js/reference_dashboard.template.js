
(() => {
  const definitions = [{"id":"wasting","label":"Wasting","shortLabel":"Wasting","direction":"adverse"},{"id":"anemia_women","label":"Anemia (women)","shortLabel":"Anemia","direction":"adverse"},{"id":"malaria_rdt_positive","label":"Malaria RDT+","shortLabel":"Malaria RDT+","direction":"adverse"},{"id":"zero_dose","label":"Zero-dose","shortLabel":"Zero-dose","direction":"adverse"},{"id":"first_birth_under20","label":"First birth \u003c 20","shortLabel":"First birth \u003c20","direction":"adverse"},{"id":"facility_delivery","label":"Facility delivery","shortLabel":"Facility delivery","direction":"beneficial"},{"id":"fever_care_seeking","label":"Fever care seeking","shortLabel":"Fever care","direction":"beneficial"},{"id":"anc4plus","label":"ANC4+","shortLabel":"ANC4+","direction":"beneficial"}];
  const indicatorRows = {{INDICATOR_ROWS}};
  const classifications = {{CLASSIFICATIONS}};
  const purpleScale = ["#F7FCFD","#E0ECF4","#BFD3E6","#9EBCDA","#8C96C6","#8C6BB1","#88419D","#810F7C","#4D004B"];
  const bivariateColors = {"improving:improving":"#F0EEE4","inside_threshold:improving":"#E8BC8D","worsening:improving":"#DF8A36","improving:inside_threshold":"#80B0A6","inside_threshold:inside_threshold":"#86856A","worsening:inside_threshold":"#8C592E","improving:worsening":"#107369","inside_threshold:worsening":"#254E48","worsening:worsening":"#3A2826"};
  const prevalenceRankBivariateColors = {"best:best":"#F0EEE4","middle:best":"#E8BC8D","worst:best":"#DF8A36","best:middle":"#80B0A6","middle:middle":"#86856A","worst:middle":"#8C592E","best:worst":"#107369","middle:worst":"#254E48","worst:worst":"#3A2826"};
  const statusLabels = {"improving":"Improving","inside_threshold":"Non-significant change","worsening":"Worsening","no_data":"No data"};
  const provinceImagesPrevalence = {{PROVINCE_IMAGES_PREVALENCE}};
  const provinceImagesChange = {{PROVINCE_IMAGES_CHANGE}};
  const fmt = (value, digits = 1) => Number(value).toLocaleString("en-US", { minimumFractionDigits: digits, maximumFractionDigits: digits });
  const median = (values) => { const ordered = [...values].sort((a,b) => a-b); const middle = Math.floor(ordered.length/2); return ordered.length % 2 ? ordered[middle] : (ordered[middle-1] + ordered[middle]) / 2; };
  const colorForValue = (value, min, max, reverse = false) => { const progress = max === min ? .5 : (value-min)/(max-min); const index = Math.min(purpleScale.length-1, Math.floor(progress*purpleScale.length)); return purpleScale[reverse ? purpleScale.length-1-index : index]; };
  const esc = (value) => String(value ?? "").replace(/[&<>]/g, character => ({"&":"&amp;","<":"&lt;",">":"&gt;"}[character]));
  const rankBucketLabel = { best: "Best ranked", middle: "Middle ranked", worst: "Worst ranked" };
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
  }

  function buildProfileRows(adminName, country) {
    return definitions
      .filter((definition) => indicatorRows.some((entry) => entry.adminName === adminName && entry.indicator === definition.id && entry.country === country))
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
    const imageBank = profileType === "change" ? provinceImagesChange : provinceImagesPrevalence;
    const fallbackBank = profileType === "change" ? provinceImagesPrevalence : provinceImagesChange;
    const imageSrc = imageBank[adminName] || fallbackBank[adminName];
    imageWrap.innerHTML = "";
    if (imageSrc) {
      const img = document.createElement("img");
      img.id = "profile-image";
      img.alt = adminName + " indicator strip chart";
      img.src = imageSrc;
      imageWrap.appendChild(img);
    } else {
      const emptyDiv = document.createElement("div");
      emptyDiv.className = "profile-image-empty";
      emptyDiv.textContent = "No rankings visualization available yet.";
      imageWrap.appendChild(emptyDiv);
    }
    const panel = document.getElementById("profile-panel");
    panel.dataset.adminName = adminName;
    panel.dataset.country = country;
    panel.classList.add("open");
    panel.setAttribute("aria-hidden", "false");
    document.getElementById("profile-overlay").classList.add("open");
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
    section.querySelector('[data-role="indicator-range"]').textContent = fmt(min) + "—" + fmt(max) + "%";
    section.querySelector('[data-role="indicator-map-title"]').textContent = definition.label;
    section.querySelector('[data-role="indicator-legend-top"]').textContent = fmt(definition.direction === "beneficial" ? min : max, 0) + "%";
    section.querySelector('[data-role="indicator-legend-bottom"]').textContent = fmt(definition.direction === "beneficial" ? max : min, 0) + "%";
    section.querySelector('[data-role="bar-title"]').textContent = definition.label;
    section.querySelector('[data-role="bar-count"]').textContent = rows.length + " areas — %";
    const note = section.querySelector('[data-role="indicator-note"]'); note.hidden = years.every((year) => year === 2024); note.textContent = "Latest available year shown: " + years.join(", ") + ".";
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
          ? region.dataset.name + "\n" + x.label + ": Rank " + xRank + " / " + totalUnits + " (" + rankBucketLabel[xb] + ") — Latest observed " + fmt(xrRow.observedLatestEstimate) + "% (" + xrRow.latestYear + ")\n" + y.label + ": Rank " + yRank + " / " + totalUnits + " (" + rankBucketLabel[yb] + ") — Latest observed " + fmt(yrRow.observedLatestEstimate) + "% (" + yrRow.latestYear + ")"
          : region.dataset.name + "\nNo paired data";
      } else {
        if (xr?.classification === "worsening" && yr?.classification === "worsening") both++;
        region.setAttribute("fill", xr && yr ? (bivariateColors[xr.classification + ":" + yr.classification] || "#E7E2E8") : "#E7E2E8");
        region.dataset.tip = xr && yr ? region.dataset.name + "\n" + x.label + ": " + statusLabels[xr.classification] + " — Latest observed " + fmt(xr.observedLatestEstimate) + "% (" + xr.latestYear + ") — " + (xr.ppChange10yrRecoded > 0 ? "+" : "") + fmt(xr.ppChange10yrRecoded) + " pp\n" + y.label + ": " + statusLabels[yr.classification] + " — Latest observed " + fmt(yr.observedLatestEstimate) + "% (" + yr.latestYear + ") — " + (yr.ppChange10yrRecoded > 0 ? "+" : "") + fmt(yr.ppChange10yrRecoded) + " pp" : region.dataset.name + "\nNo paired data";
      }
      region.setAttribute("aria-label", region.dataset.tip.replaceAll("\n", ", "));
    });
    const titleEl = section.querySelector('[data-role="map-title"]'); if (titleEl) titleEl.textContent = x.shortLabel + " — " + y.shortLabel;
    const xLabelEl = section.querySelector('[data-role="biv-x-label"]'); if (xLabelEl) xLabelEl.textContent = x.shortLabel;
    const yLabelEl = section.querySelector('[data-role="biv-y-label"]'); if (yLabelEl) yLabelEl.textContent = y.shortLabel;
    const bothEl = section.querySelector('[data-role="biv-both"]'); if (bothEl) bothEl.textContent = both;
    const bothLabelEl = section.querySelector('[data-role="biv-summary-label"]');
    if (bothLabelEl) bothLabelEl.textContent = mode === "prevalence_rank" ? "areas where both are worst-ranked" : "areas where both worsened";
    updateBivariateLegend(section, mode);
  }

  relabelChangeMapTooltips();
  bindTooltips();
  document.querySelectorAll(".bivariate-section").forEach((section) => ensureBivariateModeControl(section));
  document.querySelectorAll(".indicator-section").forEach((section) => section.querySelectorAll("[data-indicator]").forEach((button) => button.addEventListener("click", () => updateIndicator(button.dataset.indicator, section))));
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
const indicatorOrder=["anc4plus","anemia_women","facility_delivery","fever_care_seeking","first_birth_under20","wasting","zero_dose","malaria_rdt_positive","malaria_microscopy_positive"];const indicatorLabels={"facility_delivery":"Facility delivery","anemia_women":"Anemia (women)","malaria_microscopy_positive":"Malaria positive (microscopy)","fever_care_seeking":"Fever care seeking","wasting":"Wasting","zero_dose":"Zero-dose","anc4plus":"ANC4+","first_birth_under20":"First birth \u003c20","malaria_rdt_positive":"Malaria positive (RDT)"};const shapeOrderStates=["Cross River","FCT Abuja","Ogun","Oyo","Sokoto","Zamfara","Lagos","Akwa Ibom","Bayelsa","Ondo","Delta","Rivers","Kwara","Kogi","Benue","Borno","Katsina","Plateau","Edo","Jigawa","Anambra","Kano","Nasarawa","Kebbi","Imo","Gombe","Adamawa","Yobe","Abia","Ekiti","Osun","Bauchi","Niger","Kaduna","Enugu","Taraba","Ebonyi"];const shapeMap=[{"shape":0,"state":"Cross River"},{"shape":1,"state":"FCT Abuja"},{"shape":2,"state":"Ogun"},{"shape":3,"state":"Oyo"},{"shape":4,"state":"Sokoto"},{"shape":5,"state":"Zamfara"},{"shape":6,"state":"Lagos"},{"shape":7,"state":"Akwa Ibom"},{"shape":8,"state":"Bayelsa"},{"shape":9,"state":"Ondo"},{"shape":10,"state":"Delta"},{"shape":11,"state":"Rivers"},{"shape":12,"state":"Kwara"},{"shape":13,"state":"Kogi"},{"shape":14,"state":"Benue"},{"shape":15,"state":"Borno"},{"shape":16,"state":"Katsina"},{"shape":17,"state":"Plateau"},{"shape":18,"state":"Edo"},{"shape":19,"state":"Jigawa"},{"shape":20,"state":"Anambra"},{"shape":21,"state":"Kano"},{"shape":22,"state":"Nasarawa"},{"shape":23,"state":"Kebbi"},{"shape":24,"state":"Imo"},{"shape":25,"state":"Gombe"},{"shape":26,"state":"Adamawa"},{"shape":27,"state":"Yobe"},{"shape":28,"state":"Abia"},{"shape":29,"state":"Ekiti"},{"shape":30,"state":"Osun"},{"shape":31,"state":"Bauchi"},{"shape":32,"state":"Niger"},{"shape":33,"state":"Kaduna"},{"shape":34,"state":"Enugu"},{"shape":35,"state":"Taraba"},{"shape":36,"state":"Ebonyi"}];const rows=[{"indicator":"anc4plus","admin_name":"Borno","value":61.103373,"year":2024},{"indicator":"anc4plus","admin_name":"Yobe","value":48.495499,"year":2024},{"indicator":"anc4plus","admin_name":"Rivers","value":76.477595,"year":2024},{"indicator":"anc4plus","admin_name":"Kaduna","value":59.432276,"year":2024},{"indicator":"anc4plus","admin_name":"Bayelsa","value":48.615939,"year":2024},{"indicator":"anc4plus","admin_name":"Katsina","value":37.178724,"year":2024},{"indicator":"anc4plus","admin_name":"Benue","value":49.128425,"year":2024},{"indicator":"anc4plus","admin_name":"Akwa Ibom","value":65.724152,"year":2024},{"indicator":"anc4plus","admin_name":"Taraba","value":50.546595,"year":2024},{"indicator":"anc4plus","admin_name":"Kano","value":51.261443,"year":2024},{"indicator":"anc4plus","admin_name":"Anambra","value":84.858744,"year":2024},{"indicator":"anc4plus","admin_name":"Nasarawa","value":65.953382,"year":2024},{"indicator":"anc4plus","admin_name":"Sokoto","value":22.747631,"year":2024},{"indicator":"anc4plus","admin_name":"Plateau","value":46.436564,"year":2024},{"indicator":"anc4plus","admin_name":"Bauchi","value":46.602332,"year":2024},{"indicator":"anc4plus","admin_name":"Cross River","value":79.987405,"year":2024},{"indicator":"anc4plus","admin_name":"Zamfara","value":21.457577,"year":2024},{"indicator":"anc4plus","admin_name":"Lagos","value":95.432872,"year":2024},{"indicator":"anc4plus","admin_name":"Jigawa","value":37.660619,"year":2024},{"indicator":"anc4plus","admin_name":"Osun","value":91.974982,"year":2024},{"indicator":"anc4plus","admin_name":"Imo","value":84.932995,"year":2024},{"indicator":"anc4plus","admin_name":"Kebbi","value":14.031834,"year":2024},{"indicator":"anc4plus","admin_name":"FCT Abuja","value":79.905067,"year":2024},{"indicator":"anc4plus","admin_name":"Oyo","value":73.775034,"year":2024},{"indicator":"anc4plus","admin_name":"Abia","value":79.05641,"year":2024},{"indicator":"anc4plus","admin_name":"Edo","value":62.99775,"year":2024},{"indicator":"anc4plus","admin_name":"Adamawa","value":56.421333,"year":2024},{"indicator":"anc4plus","admin_name":"Ondo","value":66.281513,"year":2024},{"indicator":"anc4plus","admin_name":"Delta","value":60.458586,"year":2024},{"indicator":"anc4plus","admin_name":"Ebonyi","value":61.727962,"year":2024},{"indicator":"anc4plus","admin_name":"Gombe","value":39.103663,"year":2024},{"indicator":"anc4plus","admin_name":"Niger","value":34.69295,"year":2024},{"indicator":"anc4plus","admin_name":"Ekiti","value":68.589093,"year":2024},{"indicator":"anc4plus","admin_name":"Ogun","value":73.656235,"year":2024},{"indicator":"anc4plus","admin_name":"Enugu","value":61.907756,"year":2024},{"indicator":"anc4plus","admin_name":"Kogi","value":54.10791,"year":2024},{"indicator":"anc4plus","admin_name":"Kwara","value":51.302839,"year":2024},{"indicator":"anemia_women","admin_name":"Kebbi","value":20.08032564,"year":2024},{"indicator":"anemia_women","admin_name":"Nasarawa","value":31.06414698,"year":2024},{"indicator":"anemia_women","admin_name":"Zamfara","value":39.06831555,"year":2024},{"indicator":"anemia_women","admin_name":"Yobe","value":37.25458425,"year":2024},{"indicator":"anemia_women","admin_name":"Delta","value":35.82449551,"year":2024},{"indicator":"anemia_women","admin_name":"Gombe","value":38.6254518,"year":2024},{"indicator":"anemia_women","admin_name":"Imo","value":40.12632595,"year":2024},{"indicator":"anemia_women","admin_name":"Niger","value":40.03126674,"year":2024},{"indicator":"anemia_women","admin_name":"Benue","value":26.74018447,"year":2024},{"indicator":"anemia_women","admin_name":"Bauchi","value":46.67997221,"year":2024},{"indicator":"anemia_women","admin_name":"FCT Abuja","value":29.82901728,"year":2024},{"indicator":"anemia_women","admin_name":"Plateau","value":23.72343165,"year":2024},{"indicator":"anemia_women","admin_name":"Osun","value":37.61204694,"year":2024},{"indicator":"anemia_women","admin_name":"Katsina","value":52.36303215,"year":2024},{"indicator":"anemia_women","admin_name":"Anambra","value":52.27675929,"year":2024},{"indicator":"anemia_women","admin_name":"Kaduna","value":26.11484997,"year":2024},{"indicator":"anemia_women","admin_name":"Jigawa","value":48.83952536,"year":2024},{"indicator":"anemia_women","admin_name":"Rivers","value":49.74679356,"year":2024},{"indicator":"anemia_women","admin_name":"Borno","value":39.09120376,"year":2024},{"indicator":"anemia_women","admin_name":"Kogi","value":43.47425178,"year":2024},{"indicator":"anemia_women","admin_name":"Taraba","value":40.33693676,"year":2024},{"indicator":"anemia_women","admin_name":"Kano","value":33.46541688,"year":2024},{"indicator":"anemia_women","admin_name":"Enugu","value":47.76113895,"year":2024},{"indicator":"anemia_women","admin_name":"Oyo","value":38.2913686,"year":2024},{"indicator":"anemia_women","admin_name":"Bayelsa","value":47.70077996,"year":2024},{"indicator":"anemia_women","admin_name":"Ekiti","value":40.40354179,"year":2024},{"indicator":"anemia_women","admin_name":"Ondo","value":45.22823992,"year":2024},{"indicator":"anemia_women","admin_name":"Sokoto","value":64.27788137,"year":2024},{"indicator":"anemia_women","admin_name":"Cross River","value":38.5152347,"year":2024},{"indicator":"anemia_women","admin_name":"Ogun","value":41.67780639,"year":2024},{"indicator":"anemia_women","admin_name":"Edo","value":50.81819356,"year":2024},{"indicator":"anemia_women","admin_name":"Lagos","value":46.30045303,"year":2024},{"indicator":"anemia_women","admin_name":"Akwa Ibom","value":55.52269926,"year":2024},{"indicator":"anemia_women","admin_name":"Ebonyi","value":71.68532422,"year":2024},{"indicator":"anemia_women","admin_name":"Kwara","value":55.82042091,"year":2024},{"indicator":"anemia_women","admin_name":"Abia","value":64.03379026,"year":2024},{"indicator":"anemia_women","admin_name":"Adamawa","value":44.23647588,"year":2024},{"indicator":"facility_delivery","admin_name":"Borno","value":45.915765,"year":2024},{"indicator":"facility_delivery","admin_name":"Ondo","value":83.187846,"year":2024},{"indicator":"facility_delivery","admin_name":"Delta","value":82.982899,"year":2024},{"indicator":"facility_delivery","admin_name":"Yobe","value":32.082441,"year":2024},{"indicator":"facility_delivery","admin_name":"Gombe","value":48.530973,"year":2024},{"indicator":"facility_delivery","admin_name":"Kano","value":32.673853,"year":2024},{"indicator":"facility_delivery","admin_name":"Ebonyi","value":79.367592,"year":2024},{"indicator":"facility_delivery","admin_name":"Cross River","value":58.834953,"year":2024},{"indicator":"facility_delivery","admin_name":"Bayelsa","value":46.117097,"year":2024},{"indicator":"facility_delivery","admin_name":"Edo","value":90.920718,"year":2024},{"indicator":"facility_delivery","admin_name":"Nasarawa","value":55.708749,"year":2024},{"indicator":"facility_delivery","admin_name":"Jigawa","value":21.405216,"year":2024},{"indicator":"facility_delivery","admin_name":"Bauchi","value":31.142297,"year":2024},{"indicator":"facility_delivery","admin_name":"Abia","value":85.956188,"year":2024},{"indicator":"facility_delivery","admin_name":"FCT Abuja","value":81.334621,"year":2024},{"indicator":"facility_delivery","admin_name":"Zamfara","value":15.314362,"year":2024},{"indicator":"facility_delivery","admin_name":"Plateau","value":45.687297,"year":2024},{"indicator":"facility_delivery","admin_name":"Taraba","value":33.001944,"year":2024},{"indicator":"facility_delivery","admin_name":"Ogun","value":83.329697,"year":2024},{"indicator":"facility_delivery","admin_name":"Lagos","value":85.844276,"year":2024},{"indicator":"facility_delivery","admin_name":"Adamawa","value":41.579381,"year":2024},{"indicator":"facility_delivery","admin_name":"Benue","value":59.046486,"year":2024},{"indicator":"facility_delivery","admin_name":"Rivers","value":56.884896,"year":2024},{"indicator":"facility_delivery","admin_name":"Sokoto","value":12.456265,"year":2024},{"indicator":"facility_delivery","admin_name":"Enugu","value":92.587143,"year":2024},{"indicator":"facility_delivery","admin_name":"Katsina","value":15.80346,"year":2024},{"indicator":"facility_delivery","admin_name":"Imo","value":97.026071,"year":2024},{"indicator":"facility_delivery","admin_name":"Niger","value":30.184659,"year":2024},{"indicator":"facility_delivery","admin_name":"Kebbi","value":8.843813,"year":2024},{"indicator":"facility_delivery","admin_name":"Oyo","value":75.027198,"year":2024},{"indicator":"facility_delivery","admin_name":"Anambra","value":83.24692,"year":2024},{"indicator":"facility_delivery","admin_name":"Osun","value":86.672552,"year":2024},{"indicator":"facility_delivery","admin_name":"Akwa Ibom","value":38.588981,"year":2024},{"indicator":"facility_delivery","admin_name":"Ekiti","value":81.658578,"year":2024},{"indicator":"facility_delivery","admin_name":"Kaduna","value":25.859501,"year":2024},{"indicator":"facility_delivery","admin_name":"Kogi","value":62.161529,"year":2024},{"indicator":"facility_delivery","admin_name":"Kwara","value":51.497966,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Ogun","value":79.949113,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Benue","value":67.178773,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Anambra","value":88.41948,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Delta","value":65.252366,"year":2024},{"indicator":"fever_care_seeking","admin_name":"FCT Abuja","value":88.242503,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Imo","value":91.521115,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Lagos","value":81.480825,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Kaduna","value":58.035336,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Borno","value":69.901994,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Jigawa","value":69.456826,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Cross River","value":83.384644,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Katsina","value":56.315834,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Gombe","value":83.810327,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Ekiti","value":61.840265,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Niger","value":64.979575,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Zamfara","value":67.853352,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Sokoto","value":59.118744,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Osun","value":69.141468,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Plateau","value":54.335655,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Bayelsa","value":71.31183,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Ondo","value":65.15844,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Abia","value":60.588801,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Kwara","value":68.005494,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Adamawa","value":70.305299,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Nasarawa","value":72.818953,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Yobe","value":62.122155,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Akwa Ibom","value":70.056854,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Oyo","value":63.467586,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Taraba","value":56.12855,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Enugu","value":52.717287,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Edo","value":59.138604,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Kogi","value":66.707402,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Rivers","value":58.384398,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Kano","value":45.078199,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Kebbi","value":41.447545,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Ebonyi","value":39.666647,"year":2024},{"indicator":"fever_care_seeking","admin_name":"Bauchi","value":38.603106,"year":2024},{"indicator":"first_birth_under20","admin_name":"Sokoto","value":58.75740125,"year":2024},{"indicator":"first_birth_under20","admin_name":"Benue","value":48.97661086,"year":2024},{"indicator":"first_birth_under20","admin_name":"Bayelsa","value":48.08737855,"year":2024},{"indicator":"first_birth_under20","admin_name":"Oyo","value":24.22779915,"year":2024},{"indicator":"first_birth_under20","admin_name":"Edo","value":23.07430374,"year":2024},{"indicator":"first_birth_under20","admin_name":"Ogun","value":24.37110376,"year":2024},{"indicator":"first_birth_under20","admin_name":"Delta","value":31.44268471,"year":2024},{"indicator":"first_birth_under20","admin_name":"Abia","value":16.36148001,"year":2024},{"indicator":"first_birth_under20","admin_name":"Anambra","value":21.48852753,"year":2024},{"indicator":"first_birth_under20","admin_name":"Katsina","value":67.08290374,"year":2024},{"indicator":"first_birth_under20","admin_name":"Cross River","value":35.76983241,"year":2024},{"indicator":"first_birth_under20","admin_name":"Bauchi","value":65.54095138,"year":2024},{"indicator":"first_birth_under20","admin_name":"Kano","value":60.64340173,"year":2024},{"indicator":"first_birth_under20","admin_name":"Taraba","value":55.85589132,"year":2024},{"indicator":"first_birth_under20","admin_name":"Imo","value":17.9399906,"year":2024},{"indicator":"first_birth_under20","admin_name":"Kebbi","value":62.14482735,"year":2024},{"indicator":"first_birth_under20","admin_name":"Rivers","value":33.29042452,"year":2024},{"indicator":"first_birth_under20","admin_name":"Jigawa","value":67.83655527,"year":2024},{"indicator":"first_birth_under20","admin_name":"Ebonyi","value":39.12518893,"year":2024},{"indicator":"first_birth_under20","admin_name":"Akwa Ibom","value":46.94275336,"year":2024},{"indicator":"first_birth_under20","admin_name":"Niger","value":51.0756519,"year":2024},{"indicator":"first_birth_under20","admin_name":"FCT Abuja","value":31.39053496,"year":2024},{"indicator":"first_birth_under20","admin_name":"Enugu","value":30.74329616,"year":2024},{"indicator":"first_birth_under20","admin_name":"Borno","value":52.57968717,"year":2024},{"indicator":"first_birth_under20","admin_name":"Ondo","value":30.93518784,"year":2024},{"indicator":"first_birth_under20","admin_name":"Lagos","value":15.24291624,"year":2024},{"indicator":"first_birth_under20","admin_name":"Adamawa","value":59.37119906,"year":2024},{"indicator":"first_birth_under20","admin_name":"Zamfara","value":69.22620392,"year":2024},{"indicator":"first_birth_under20","admin_name":"Gombe","value":68.30856973,"year":2024},{"indicator":"first_birth_under20","admin_name":"Osun","value":22.12313825,"year":2024},{"indicator":"first_birth_under20","admin_name":"Kogi","value":46.7375006,"year":2024},{"indicator":"first_birth_under20","admin_name":"Nasarawa","value":49.56148142,"year":2024},{"indicator":"first_birth_under20","admin_name":"Yobe","value":65.56224881,"year":2024},{"indicator":"first_birth_under20","admin_name":"Ekiti","value":31.13050132,"year":2024},{"indicator":"first_birth_under20","admin_name":"Kaduna","value":67.50766661,"year":2024},{"indicator":"first_birth_under20","admin_name":"Kwara","value":32.93797251,"year":2024},{"indicator":"first_birth_under20","admin_name":"Plateau","value":50.38827938,"year":2024},{"indicator":"wasting","admin_name":"Kaduna","value":5.896358091,"year":2024},{"indicator":"wasting","admin_name":"Kano","value":10.39470898,"year":2024},{"indicator":"wasting","admin_name":"Bauchi","value":5.24001237,"year":2024},{"indicator":"wasting","admin_name":"Borno","value":10.33049408,"year":2024},{"indicator":"wasting","admin_name":"Katsina","value":6.721186552,"year":2024},{"indicator":"wasting","admin_name":"Yobe","value":10.09131788,"year":2024},{"indicator":"wasting","admin_name":"Sokoto","value":6.035052676,"year":2024},{"indicator":"wasting","admin_name":"Niger","value":5.794032154,"year":2024},{"indicator":"wasting","admin_name":"Zamfara","value":5.275815423,"year":2024},{"indicator":"wasting","admin_name":"Kebbi","value":9.552864695,"year":2024},{"indicator":"wasting","admin_name":"Adamawa","value":6.959847223,"year":2024},{"indicator":"wasting","admin_name":"Anambra","value":9.789366528,"year":2024},{"indicator":"wasting","admin_name":"FCT Abuja","value":6.972642657,"year":2024},{"indicator":"wasting","admin_name":"Plateau","value":4.771686141,"year":2024},{"indicator":"wasting","admin_name":"Lagos","value":5.968777471,"year":2024},{"indicator":"wasting","admin_name":"Gombe","value":8.822882214,"year":2024},{"indicator":"wasting","admin_name":"Enugu","value":3.885584696,"year":2024},{"indicator":"wasting","admin_name":"Imo","value":7.13242604,"year":2024},{"indicator":"wasting","admin_name":"Cross River","value":5.623908292,"year":2024},{"indicator":"wasting","admin_name":"Ebonyi","value":6.53616366,"year":2024},{"indicator":"wasting","admin_name":"Jigawa","value":13.19888173,"year":2024},{"indicator":"wasting","admin_name":"Kogi","value":5.858815758,"year":2024},{"indicator":"wasting","admin_name":"Ekiti","value":4.97736177,"year":2024},{"indicator":"wasting","admin_name":"Abia","value":8.22455821,"year":2024},{"indicator":"wasting","admin_name":"Edo","value":8.001086275,"year":2024},{"indicator":"wasting","admin_name":"Delta","value":15.13267289,"year":2024},{"indicator":"wasting","admin_name":"Benue","value":6.740900604,"year":2024},{"indicator":"wasting","admin_name":"Kwara","value":6.147213268,"year":2024},{"indicator":"wasting","admin_name":"Nasarawa","value":9.567999943,"year":2024},{"indicator":"wasting","admin_name":"Osun","value":11.83325332,"year":2024},{"indicator":"wasting","admin_name":"Akwa Ibom","value":11.7771064,"year":2024},{"indicator":"wasting","admin_name":"Taraba","value":9.488313678,"year":2024},{"indicator":"wasting","admin_name":"Rivers","value":12.70018555,"year":2024},{"indicator":"wasting","admin_name":"Ogun","value":13.41720692,"year":2024},{"indicator":"wasting","admin_name":"Ondo","value":10.20967123,"year":2024},{"indicator":"wasting","admin_name":"Bayelsa","value":8.895952244,"year":2024},{"indicator":"wasting","admin_name":"Oyo","value":14.42265584,"year":2024},{"indicator":"zero_dose","admin_name":"Borno","value":31.70475949,"year":2024},{"indicator":"zero_dose","admin_name":"Jigawa","value":34.29304501,"year":2024},{"indicator":"zero_dose","admin_name":"Yobe","value":40.56465229,"year":2024},{"indicator":"zero_dose","admin_name":"Bauchi","value":37.32357799,"year":2024},{"indicator":"zero_dose","admin_name":"Katsina","value":39.8058631,"year":2024},{"indicator":"zero_dose","admin_name":"Kano","value":42.02316418,"year":2024},{"indicator":"zero_dose","admin_name":"Gombe","value":34.02587255,"year":2024},{"indicator":"zero_dose","admin_name":"Nasarawa","value":20.97020666,"year":2024},{"indicator":"zero_dose","admin_name":"Delta","value":7.590002729,"year":2024},{"indicator":"zero_dose","admin_name":"Taraba","value":40.24727399,"year":2024},{"indicator":"zero_dose","admin_name":"Benue","value":32.01195044,"year":2024},{"indicator":"zero_dose","admin_name":"Kebbi","value":84.03315111,"year":2024},{"indicator":"zero_dose","admin_name":"Sokoto","value":86.27255649,"year":2024},{"indicator":"zero_dose","admin_name":"FCT Abuja","value":6.19172019,"year":2024},{"indicator":"zero_dose","admin_name":"Ondo","value":19.83977563,"year":2024},{"indicator":"zero_dose","admin_name":"Cross River","value":2.788505654,"year":2024},{"indicator":"zero_dose","admin_name":"Ebonyi","value":3.002995162,"year":2024},{"indicator":"zero_dose","admin_name":"Lagos","value":1.096066604,"year":2024},{"indicator":"zero_dose","admin_name":"Edo","value":2.091662959,"year":2024},{"indicator":"zero_dose","admin_name":"Zamfara","value":82.62359886,"year":2024},{"indicator":"zero_dose","admin_name":"Bayelsa","value":17.23842012,"year":2024},{"indicator":"zero_dose","admin_name":"Plateau","value":35.29387356,"year":2024},{"indicator":"zero_dose","admin_name":"Ogun","value":20.17371126,"year":2024},{"indicator":"zero_dose","admin_name":"Imo","value":6.719030045,"year":2024},{"indicator":"zero_dose","admin_name":"Abia","value":5.45723019,"year":2024},{"indicator":"zero_dose","admin_name":"Oyo","value":29.43410814,"year":2024},{"indicator":"zero_dose","admin_name":"Enugu","value":12.83170451,"year":2024},{"indicator":"zero_dose","admin_name":"Anambra","value":14.92877653,"year":2024},{"indicator":"zero_dose","admin_name":"Ekiti","value":6.015148228,"year":2024},{"indicator":"zero_dose","admin_name":"Akwa Ibom","value":15.13765264,"year":2024},{"indicator":"zero_dose","admin_name":"Osun","value":12.93826467,"year":2024},{"indicator":"zero_dose","admin_name":"Kaduna","value":45.6071497,"year":2024},{"indicator":"zero_dose","admin_name":"Adamawa","value":29.11831667,"year":2024},{"indicator":"zero_dose","admin_name":"Niger","value":56.63335768,"year":2024},{"indicator":"zero_dose","admin_name":"Rivers","value":22.01150502,"year":2024},{"indicator":"zero_dose","admin_name":"Kwara","value":51.74169935,"year":2024},{"indicator":"zero_dose","admin_name":"Kogi","value":56.97488153,"year":2024},{"indicator":"malaria_rdt_positive","admin_name":"Osun","value":27.55320134,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Borno","value":18.62373676,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Ogun","value":35.60118029,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Sokoto","value":40.32348625,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Akwa Ibom","value":33.50147738,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Rivers","value":33.84001239,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Kwara","value":17.61246742,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Delta","value":18.89135141,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Oyo","value":29.56098766,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Lagos","value":3.244182808,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Abia","value":26.4204568,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Ondo","value":44.84330263,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Ebonyi","value":30.18701851,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Katsina","value":49.47541357,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Edo","value":30.20342429,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Nasarawa","value":29.93900059,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Kogi","value":27.73352179,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Cross River","value":40.5583512,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Benue","value":33.9762087,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Plateau","value":26.43442792,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Yobe","value":62.51157129,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Zamfara","value":59.73689676,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Enugu","value":30.21749413,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Kaduna","value":32.28640995,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Imo","value":26.17021871,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Niger","value":42.55282289,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Adamawa","value":27.9578965,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Ekiti","value":36.52242265,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Taraba","value":24.52453213,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Kebbi","value":75.60719959,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Bayelsa","value":27.07378718,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Anambra","value":20.16236367,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Gombe","value":33.07982323,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Jigawa","value":54.52837393,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"FCT Abuja","value":34.56139661,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Bauchi","value":59.63938532,"year":2021},{"indicator":"malaria_rdt_positive","admin_name":"Kano","value":54.03456571,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Niger","value":20.73704172,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Ogun","value":24.89644342,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Osun","value":19.33053237,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Kwara","value":5.64439505,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Benue","value":17.56907294,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Ondo","value":26.66946467,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Edo","value":22.58896704,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Zamfara","value":36.60438503,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Oyo","value":20.88733396,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Katsina","value":29.30525161,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Kogi","value":15.89045275,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Abia","value":14.50863354,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Kebbi","value":49.0125192,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"FCT Abuja","value":18.79132392,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Delta","value":9.998161617,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Cross River","value":23.64869018,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Borno","value":5.553061836,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Nasarawa","value":15.2761511,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Yobe","value":20.48159669,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Ekiti","value":20.81388721,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Jigawa","value":25.39866252,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Bauchi","value":31.71440934,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Kano","value":25.48486827,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Kaduna","value":16.20298937,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Imo","value":15.52660297,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Rivers","value":8.649880492,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Adamawa","value":10.69777946,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Lagos","value":2.576683457,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Anambra","value":5.447306137,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Plateau","value":18.83114147,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Ebonyi","value":25.70247934,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Gombe","value":17.74685089,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Bayelsa","value":16.74333373,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Enugu","value":24.30851664,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Sokoto","value":35.93156543,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Akwa Ibom","value":30.11109978,"year":2021},{"indicator":"malaria_microscopy_positive","admin_name":"Taraba","value":17.85314892,"year":2021}];const scale=["#4D004B","#810F7C","#88419D","#8C6BB1","#8C96C6","#9EBCDA","#BFD3E6","#E0ECF4","#F7FCFD"];const section=document.getElementById('nigeria-indicators');const tooltip=section.querySelector('.map-tooltip');const tabs=section.querySelector('.indicator-tabs');const dataByIndicator=new Map();for(const row of rows){if(!dataByIndicator.has(row.indicator))dataByIndicator.set(row.indicator,{year:row.year,map:new Map()});dataByIndicator.get(row.indicator).map.set(row.admin_name,Number(row.value));}for(const [idx,id] of indicatorOrder.entries()){const btn=document.createElement('button');btn.type='button';btn.dataset.indicator=id;btn.textContent=indicatorLabels[id]||id;btn.className=idx===0?'active':'';btn.setAttribute('aria-selected',idx===0?'true':'false');btn.addEventListener('click',()=>updateIndicator(id));tabs.appendChild(btn);}function bucket(sorted,value){let rank=0;while(rank<sorted.length&&sorted[rank]<=value)rank+=1;const p=(rank-1)/Math.max(1,sorted.length-1);return Math.max(0,Math.min(8,Math.round(p*8)));}function updateIndicator(indicator){const obj=dataByIndicator.get(indicator);if(!obj)return;const year=obj.year;const m=obj.map;const pairs=shapeOrderStates.map(name=>({name,value:m.get(name)}));const vals=pairs.map(p=>p.value).sort((a,b)=>a-b);const min=vals[0],max=vals[vals.length-1],med=vals[Math.floor(vals.length/2)];section.querySelectorAll('.indicator-tabs button').forEach(b=>{const on=b.dataset.indicator===indicator;b.classList.toggle('active',on);b.setAttribute('aria-selected',on?'true':'false');});section.querySelector('[data-role="indicator-name"]').textContent=indicatorLabels[indicator]||indicator;section.querySelector('[data-role="indicator-year"]').textContent=String(year);section.querySelector('[data-role="indicator-median"]').textContent=med.toFixed(1)+'%';section.querySelector('[data-role="indicator-range"]').textContent=min.toFixed(1)+'-'+max.toFixed(1)+'%';section.querySelector('[data-role="indicator-map-title"]').textContent=(indicatorLabels[indicator]||indicator)+' ('+year+')';section.querySelector('[data-role="bar-title"]').textContent=(indicatorLabels[indicator]||indicator)+' ('+year+')';section.querySelector('[data-role="indicator-legend-top"]').textContent=max.toFixed(0)+'%';section.querySelector('[data-role="indicator-legend-bottom"]').textContent=min.toFixed(0)+'%';section.querySelectorAll('.indicator-region').forEach(region=>{const name=region.dataset.name;const value=m.get(name);region.setAttribute('fill',scale[bucket(vals,value)]);region.dataset.tip=name+'\n'+value.toFixed(1)+'% observed prevalence\n'+year+' estimate';region.setAttribute('aria-label',name+', '+value.toFixed(1)+'% observed prevalence, '+year+' estimate');});const bars=section.querySelector('[data-role="indicator-bars"]');bars.innerHTML='';const sorted=[...pairs].sort((a,b)=>b.value-a.value);for(const row of sorted){const width=max===0?0:((row.value/max)*100);const el=document.createElement('div');el.className='bar-row';el.innerHTML='<span>'+row.name+'</span><div class="bar-track"><i style="width:'+width.toFixed(1)+'%"></i></div><strong>'+row.value.toFixed(1)+'</strong>';bars.appendChild(el);}}section.querySelectorAll('.indicator-region').forEach(region=>{region.addEventListener('pointerenter',()=>{tooltip.textContent=region.dataset.tip;tooltip.classList.add('visible');});region.addEventListener('pointermove',(event)=>{tooltip.textContent=region.dataset.tip;tooltip.style.left=event.offsetX+'px';tooltip.style.top=event.offsetY+'px';});region.addEventListener('pointerleave',()=>tooltip.classList.remove('visible'));});(function verify(){const regions=Array.from(section.querySelectorAll('.indicator-region'));const mismatches=regions.filter((r,i)=>{const expected='nigeria-shape-'+i;const href=(r.getAttribute('href')||'').replace('#','');const xhref=(r.getAttribute('xlink:href')||'').replace('#','');const expectedState=(shapeMap.find(p=>p.shape===i)||{}).state;return r.dataset.name!==expectedState||href!==expected||xhref!==expected;});const status=section.querySelector('[data-role="mapping-status"]');status.textContent=mismatches.length?('Mapping validation failed for '+mismatches.length+' shapes.'):('Mapping validation passed against archived nigeria_svg_mapping for all 37 shapes.');if(mismatches.length)status.style.color='#8d1a1a';})();updateIndicator(indicatorOrder[0]);
// Align the first Nigeria prevalence map with the same shape-to-state order used elsewhere.
(function fixNigeriaPrevalenceMapMapping() {
  const shell = document.getElementById("nigeria-rank-prevalence-shell");
  if (!shell) return;

  const targetOrder = [
    "Cross River", "FCT Abuja", "Ogun", "Oyo", "Sokoto", "Zamfara", "Lagos", "Akwa Ibom", "Bayelsa", "Ondo",
    "Delta", "Rivers", "Kwara", "Kogi", "Benue", "Borno", "Katsina", "Plateau", "Edo", "Jigawa",
    "Anambra", "Kano", "Nasarawa", "Kebbi", "Imo", "Gombe", "Adamawa", "Yobe", "Abia", "Ekiti",
    "Osun", "Bauchi", "Niger", "Kaduna", "Enugu", "Taraba", "Ebonyi"
  ];

  const regions = Array.from(shell.querySelectorAll("use.map-region.profile-trigger"));
  if (regions.length !== targetOrder.length) return;

  const payloadByState = new Map(
    regions.map((region) => {
      const state = region.dataset.name;
      return [
        state,
        {
          fill: region.getAttribute("fill") || "#E7E2E8",
          tip: region.dataset.tip || (state + "\nNo data"),
          aria: region.getAttribute("aria-label") || (state + ", No data")
        }
      ];
    })
  );

  regions.forEach((region, index) => {
    const state = targetOrder[index];
    const payload = payloadByState.get(state);
    region.dataset.name = state;

    if (!payload) {
      region.dataset.tip = state + "\nNo data";
      region.setAttribute("aria-label", state + ", No data");
      region.setAttribute("fill", "#E7E2E8");
      return;
    }

    const normalizedTip = payload.tip.replace(/^[^\n]*/, state);
    const normalizedAria = payload.aria.replace(/^[^,]*/, state);

    region.dataset.tip = normalizedTip;
    region.setAttribute("aria-label", normalizedAria);
    region.setAttribute("fill", payload.fill);
  });
})();
