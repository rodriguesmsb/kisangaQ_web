const communitiesFile = "comunidades_quilombola.json";

const numberFormatter = new Intl.NumberFormat("pt-BR");

function cleanText(value, fallback = "Não informado") {
  if (value === null || value === undefined) {
    return fallback;
  }

  const text = String(value).trim();
  return text.length > 0 ? text : fallback;
}

function escapeHtml(value) {
  return cleanText(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;")
    .replaceAll("'", "&#039;");
}

function countBy(features, propertyName) {
  const counts = new Map();

  features.forEach((feature) => {
    const value = cleanText(feature.properties[propertyName]);
    counts.set(value, (counts.get(value) || 0) + 1);
  });

  return [...counts.entries()]
    .map(([name, total]) => ({ name, total }))
    .sort((a, b) => b.total - a.total || a.name.localeCompare(b.name, "pt-BR"));
}

function renderBreakdown(elementId, items) {
  const container = document.getElementById(elementId);

  if (items.length === 0) {
    container.textContent = "Não há dados disponíveis.";
    return;
  }

  const maxTotal = Math.max(...items.map((item) => item.total));

  container.innerHTML = items.map((item) => {
    const width = Math.max(6, Math.round((item.total / maxTotal) * 100));

    return `
      <div class="breakdown-item">
        <div class="breakdown-row">
          <span>${escapeHtml(item.name)}</span>
          <strong>${numberFormatter.format(item.total)}</strong>
        </div>
        <div class="breakdown-track">
          <div class="breakdown-bar" style="width: ${width}%"></div>
        </div>
      </div>
    `;
  }).join("");
}

function popupContent(properties) {
  const name = cleanText(properties.nm_aglom, "Comunidade sem nome informado");
  const municipality = cleanText(properties.nm_munic);
  const state = cleanText(properties.nm_uf);
  const biome = cleanText(properties.bioma);
  const landStatus = cleanText(properties.dados_pe14);

  return `
    <strong>${escapeHtml(name)}</strong><br>
    Município: ${escapeHtml(municipality)}<br>
    UF: ${escapeHtml(state)}<br>
    Bioma: ${escapeHtml(biome)}<br>
    Situação fundiária: ${escapeHtml(landStatus)}
  `;
}

function initMap(features) {
  const map = L.map("map", {
    scrollWheelZoom: false
  }).setView([-14.2350, -51.9253], 4);

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 18,
    attribution: "&copy; OpenStreetMap contributors"
  }).addTo(map);

  const layer = typeof L.markerClusterGroup === "function" ?
    L.markerClusterGroup({
      showCoverageOnHover: false,
      maxClusterRadius: 48
    }) :
    L.layerGroup();

  const bounds = [];

  features.forEach((feature) => {
    const properties = feature.properties;
    const lat = Number(properties.lat_d);
    const lng = Number(properties.long_d);

    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return;
    }

    const marker = L.circleMarker([lat, lng], {
      radius: 5,
      color: "#2c1a08",
      weight: 1,
      fillColor: "#c8731a",
      fillOpacity: 0.78
    });

    marker.bindPopup(popupContent(properties));
    marker.bindTooltip(cleanText(properties.nm_aglom, "Comunidade sem nome informado"));
    layer.addLayer(marker);
    bounds.push([lat, lng]);
  });

  layer.addTo(map);

  if (bounds.length > 0) {
    map.fitBounds(bounds, { padding: [20, 20] });
  }
}

function populateSuggestionUf(features) {
  const select = document.getElementById("new_uf");

  if (!select) {
    return;
  }

  const states = [...new Set(features
    .map((feature) => cleanText(feature.properties.nm_uf, ""))
    .filter(Boolean))]
    .sort((a, b) => a.localeCompare(b, "pt-BR"));

  select.innerHTML = [
    '<option value="">Selecione</option>',
    ...states.map((state) => `<option value="${escapeHtml(state)}">${escapeHtml(state)}</option>`)
  ].join("");
}

function cleanFormText(form, fieldName) {
  const value = new FormData(form).get(fieldName);
  return value === null ? "" : String(value).trim();
}

function cleanFormNumber(form, fieldName) {
  const value = cleanFormText(form, fieldName);
  return value.length === 0 ? NaN : Number(value);
}

function buildSuggestionSubmission(nm_aglom, nm_uf, cd_munic, lat_d, long_d) {
  return {
    type: "Feature",
    properties: {
      lat_d,
      long_d,
      nm_aglom,
      nm_uf,
      cd_munic
    },
    geometry: {
      type: "Point",
      coordinates: [long_d, lat_d]
    },
    submitted_at: new Date().toISOString(),
    source: "KisangaQ_web"
  };
}

function suggestionMailtoUri(submission) {
  const jsonText = JSON.stringify(submission, null, 2);
  const subject = `Nova comunidade quilombola: ${submission.properties.nm_aglom}`;
  const body = [
    "Segue o JSON de submissao gerado pelo KisangaQ.",
    "",
    jsonText
  ].join("\n");

  return `mailto:rodriguesmsb@gmail.com?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
}

function setSuggestionStatus(message, type) {
  const status = document.getElementById("submit-status");

  if (!status) {
    return;
  }

  status.textContent = message;
  status.className = `submit-status is-visible is-${type}`;
}

function initSuggestionForm() {
  const form = document.getElementById("suggestions-form");

  if (!form) {
    return;
  }

  form.addEventListener("submit", (event) => {
    event.preventDefault();

    const nm_aglom = cleanFormText(form, "new_nm_aglom");
    const nm_uf = cleanFormText(form, "new_uf");
    const cd_munic = cleanFormText(form, "new_cd_munic");
    const lat_d = cleanFormNumber(form, "new_lat");
    const long_d = cleanFormNumber(form, "new_long");
    const errors = [];

    if (!nm_aglom) errors.push("nome da comunidade");
    if (!nm_uf) errors.push("UF");
    if (!cd_munic) errors.push("codigo municipal");
    if (!Number.isFinite(lat_d) || lat_d < -90 || lat_d > 90) {
      errors.push("latitude valida");
    }
    if (!Number.isFinite(long_d) || long_d < -180 || long_d > 180) {
      errors.push("longitude valida");
    }

    if (errors.length > 0) {
      setSuggestionStatus(`Preencha: ${errors.join(", ")}.`, "error");
      return;
    }

    const submission = buildSuggestionSubmission(nm_aglom, nm_uf, cd_munic, lat_d, long_d);
    setSuggestionStatus("JSON gerado e email aberto para envio.", "success");
    window.location.href = suggestionMailtoUri(submission);
  });
}

initSuggestionForm();

fetch(communitiesFile)
  .then((response) => response.json())
  .then((data) => {
    const features = data.features || [];

    document.getElementById("total-communities").textContent = numberFormatter.format(features.length);
    renderBreakdown("state-breakdown", countBy(features, "nm_uf"));
    renderBreakdown("biome-breakdown", countBy(features, "bioma"));
    populateSuggestionUf(features);
    initMap(features);
  })
  .catch(() => {
    document.getElementById("total-communities").textContent = "0";
    document.getElementById("state-breakdown").textContent = "Não foi possível carregar os dados.";
    document.getElementById("biome-breakdown").textContent = "Não foi possível carregar os dados.";
  });
