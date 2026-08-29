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

fetch(communitiesFile)
  .then((response) => response.json())
  .then((data) => {
    const features = data.features || [];

    document.getElementById("total-communities").textContent = numberFormatter.format(features.length);
    renderBreakdown("state-breakdown", countBy(features, "nm_uf"));
    renderBreakdown("biome-breakdown", countBy(features, "bioma"));
    initMap(features);
  })
  .catch(() => {
    document.getElementById("total-communities").textContent = "0";
    document.getElementById("state-breakdown").textContent = "Não foi possível carregar os dados.";
    document.getElementById("biome-breakdown").textContent = "Não foi possível carregar os dados.";
  });
