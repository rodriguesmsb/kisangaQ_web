const dataFile = "003_data_for_story.json";

const agglomerateKey = "number_algomerated";
const slopeKey = "overall_slope";

const agglomerateClasses = [
  { label: "Nenhum", min: 0, max: 0 },
  { label: "1", min: 1, max: 1 },
  { label: "2 a 4", min: 2, max: 4 },
  { label: "5 a 9", min: 5, max: 9 },
  { label: "10 ou mais", min: 10, max: Infinity }
];

// ColorBrewer BrBG: marrom para perda de vegetação, verde-azulado para ganho.
const slopeColors = ["#a6611a", "#dfc27d", "#80cdc1", "#018571"];
const agglomerateColors = ["#f1efe8", "#fdd8b0", "#f5a560", "#d9721f", "#8f4410"];
const missingColor = "#d6d9d2";
const smallSampleSize = 30;

const numberFormatter = new Intl.NumberFormat("pt-BR");
const decimalFormatter = new Intl.NumberFormat("pt-BR", {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2
});
const slopeFormatter = new Intl.NumberFormat("pt-BR", {
  minimumFractionDigits: 4,
  maximumFractionDigits: 5
});
const percentFormatter = new Intl.NumberFormat("pt-BR", {
  style: "percent",
  maximumFractionDigits: 0
});

let map;
let municipalityLayer;
let currentMapStyle;
let storyFeatures = [];
let validRows = [];

function cleanText(value, fallback = "Não informado") {
  if (value === null || value === undefined) {
    return fallback;
  }

  const text = String(value).trim();
  return text.length > 0 ? text : fallback;
}

function escapeHtml(value) {
  return cleanText(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function parseNumber(value) {
  if (value === null || value === undefined || value === "") {
    return null;
  }

  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function formatCount(value) {
  return numberFormatter.format(Math.round(value));
}

function formatSlope(value) {
  const number = parseNumber(value);

  if (number === null) {
    return "Sem dado";
  }

  const prefix = number > 0 ? "+" : "";
  return `${prefix}${slopeFormatter.format(number)}`;
}

function formatPercent(value) {
  return value === null ? "n/a" : percentFormatter.format(value);
}

function median(values) {
  if (values.length === 0) {
    return null;
  }

  const sorted = values.slice().sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle];
}

function shareNegative(rows) {
  return rows.length === 0 ? null : rows.filter((row) => row.slope < 0).length / rows.length;
}

function classIndex(count) {
  const index = agglomerateClasses.findIndex((group) => count >= group.min && count <= group.max);
  return index === -1 ? agglomerateClasses.length - 1 : index;
}

function toRows(features) {
  return features
    .map((feature) => ({
      feature,
      name: cleanText(feature.properties.NM_MUN),
      biome: cleanText(feature.properties.bioma),
      count: parseNumber(feature.properties[agglomerateKey]),
      slope: parseNumber(feature.properties[slopeKey])
    }))
    .filter((row) => row.count !== null && row.slope !== null);
}

function classPhrase(group) {
  if (group.max === 0) return "entre os municípios sem aglomerados";
  return `entre os que têm ${group.label.toLowerCase()} ${group.max === 1 ? "aglomerado" : "aglomerados"}`;
}

function rowsForBiome(biome) {
  return biome ? validRows.filter((row) => row.biome === biome) : validRows;
}

function summarizeClasses(rows) {
  return agglomerateClasses.map((group, index) => {
    const members = rows.filter((row) => classIndex(row.count) === index);

    return {
      ...group,
      n: members.length,
      negativeShare: shareNegative(members),
      medianSlope: median(members.map((row) => row.slope)),
      medianCount: median(members.map((row) => row.count))
    };
  });
}

// ---------- Estatísticas ----------

function pearson(xs, ys) {
  if (xs.length < 3) {
    return null;
  }

  const meanX = xs.reduce((total, value) => total + value, 0) / xs.length;
  const meanY = ys.reduce((total, value) => total + value, 0) / ys.length;
  let covariance = 0;
  let sumX = 0;
  let sumY = 0;

  for (let index = 0; index < xs.length; index += 1) {
    const dx = xs[index] - meanX;
    const dy = ys[index] - meanY;
    covariance += dx * dy;
    sumX += dx * dx;
    sumY += dy * dy;
  }

  const denominator = Math.sqrt(sumX * sumY);
  return denominator === 0 ? null : covariance / denominator;
}

function ranks(values) {
  const order = values.map((value, index) => ({ value, index })).sort((a, b) => a.value - b.value);
  const result = new Array(values.length);
  let start = 0;

  while (start < order.length) {
    let end = start;
    while (end + 1 < order.length && order[end + 1].value === order[start].value) {
      end += 1;
    }

    const averageRank = (start + end) / 2 + 1;
    for (let position = start; position <= end; position += 1) {
      result[order[position].index] = averageRank;
    }

    start = end + 1;
  }

  return result;
}

function spearman(xs, ys) {
  return pearson(ranks(xs), ranks(ys));
}

function correlationStrength(r) {
  const absolute = Math.abs(r);
  if (absolute < 0.1) return "praticamente nula";
  if (absolute < 0.3) return "fraca";
  if (absolute < 0.5) return "moderada";
  if (absolute < 0.7) return "forte";
  return "muito forte";
}

// ---------- Resumo inicial ----------

function updateSummaryCards(features) {
  const withAgglomerates = validRows.filter((row) => row.count > 0);
  const withoutAgglomerates = validRows.filter((row) => row.count === 0);
  const totalAgglomerates = validRows.reduce((total, row) => total + row.count, 0);
  const top = validRows.slice().sort((a, b) => b.count - a.count)[0];

  document.getElementById("agglomerates-total").textContent = formatCount(totalAgglomerates);
  document.getElementById("municipalities-with").textContent = formatCount(withAgglomerates.length);
  document.getElementById("loss-with").textContent = formatPercent(shareNegative(withAgglomerates));
  document.getElementById("loss-without").textContent = formatPercent(shareNegative(withoutAgglomerates));

  document.getElementById("data-summary").textContent = [
    `A base reúne ${formatCount(features.length)} municípios, dos quais ${formatCount(validRows.length)} têm dados de aglomerados quilombolas e de tendência do NDVI.`,
    `${formatCount(withAgglomerates.length)} deles abrigam ao menos um aglomerado, somando ${formatCount(totalAgglomerates)} aglomerados.`,
    top ? `${top.name} lidera, com ${formatCount(top.count)} aglomerados.` : ""
  ].filter(Boolean).join(" ");
}

// ---------- Mapa ----------

function slopeBreaks() {
  const negatives = validRows.filter((row) => row.slope < 0).map((row) => row.slope);
  const positives = validRows.filter((row) => row.slope >= 0).map((row) => row.slope);

  return {
    lowNegative: negatives.length > 0 ? median(negatives) : 0,
    highPositive: positives.length > 0 ? median(positives) : 0
  };
}

function slopeClass(value, breaks) {
  if (value < breaks.lowNegative) return 0;
  if (value < 0) return 1;
  if (value < breaks.highPositive) return 2;
  return 3;
}

function selectedMapMetric() {
  const select = document.getElementById("map-metric");
  return select ? select.value : slopeKey;
}

function colorForFeature(feature, metricKey, breaks) {
  const value = parseNumber(feature.properties[metricKey]);

  if (value === null) {
    return missingColor;
  }

  return metricKey === slopeKey
    ? slopeColors[slopeClass(value, breaks)]
    : agglomerateColors[classIndex(value)];
}

function mapStyle(metricKey, breaks) {
  return (feature) => {
    const hasValue = parseNumber(feature.properties[metricKey]) !== null;

    return {
      color: "#ffffff",
      fillColor: colorForFeature(feature, metricKey, breaks),
      fillOpacity: hasValue ? 0.88 : 0.45,
      opacity: 0.7,
      weight: 0.3
    };
  };
}

function municipalityPopup(properties) {
  const count = parseNumber(properties[agglomerateKey]);

  return `
    <strong>${escapeHtml(properties.NM_MUN)}</strong>
    <span>${escapeHtml(cleanText(properties.bioma, "Bioma não informado"))}</span>
    <dl>
      <dt>Aglomerados quilombolas</dt><dd>${count === null ? "Sem dado" : formatCount(count)}</dd>
      <dt>Tendência do NDVI</dt><dd>${formatSlope(properties[slopeKey])}</dd>
    </dl>
  `;
}

function bindMunicipalityInteractions(layer) {
  layer.eachLayer((municipality) => {
    municipality.bindPopup(() => municipalityPopup(municipality.feature.properties));
    municipality.bindTooltip(cleanText(municipality.feature.properties.NM_MUN), { sticky: true });

    municipality.on({
      mouseover(event) {
        event.target.setStyle({
          color: "#18211f",
          fillOpacity: 1,
          opacity: 1,
          weight: 1.5
        });
        event.target.bringToFront();
      },
      mouseout(event) {
        event.target.setStyle(currentMapStyle(event.target.feature));
      }
    });
  });
}

function legendItem(color, label) {
  return `
    <div class="legend-item">
      <span class="legend-swatch" style="background:${color}"></span>
      <span>${label}</span>
    </div>
  `;
}

function renderLegend(metricKey, breaks) {
  const legend = document.getElementById("map-legend");

  if (!legend) {
    return;
  }

  const items = metricKey === slopeKey
    ? [
      legendItem(slopeColors[0], `Queda forte (abaixo de ${formatSlope(breaks.lowNegative)})`),
      legendItem(slopeColors[1], "Queda leve"),
      legendItem(slopeColors[2], "Ganho leve"),
      legendItem(slopeColors[3], `Ganho forte (acima de ${formatSlope(breaks.highPositive)})`)
    ]
    : agglomerateClasses.map((group, index) => legendItem(agglomerateColors[index], group.label));

  legend.innerHTML = `
    <strong>${metricKey === slopeKey ? "Tendência do NDVI" : "Aglomerados quilombolas"}</strong>
    ${items.join("")}
    ${legendItem(missingColor, "Sem dado")}
  `;
}

function updateMapMetric() {
  if (!map || storyFeatures.length === 0) {
    return;
  }

  const metricKey = selectedMapMetric();
  const breaks = slopeBreaks();
  currentMapStyle = mapStyle(metricKey, breaks);

  if (municipalityLayer) {
    municipalityLayer.setStyle(currentMapStyle);
  } else {
    municipalityLayer = L.geoJSON(storyFeatures, {
      renderer: L.canvas({ padding: 0.5 }),
      style: currentMapStyle
    }).addTo(map);

    bindMunicipalityInteractions(municipalityLayer);

    const bounds = municipalityLayer.getBounds();
    if (bounds.isValid()) {
      map.fitBounds(bounds, { padding: [24, 24] });
    }
  }

  renderLegend(metricKey, breaks);
}

function initMap(features) {
  if (typeof L === "undefined") {
    document.getElementById("map").textContent = "Não foi possível carregar a biblioteca do mapa.";
    return;
  }

  map = L.map("map", {
    preferCanvas: true,
    scrollWheelZoom: false
  }).setView([-14.2350, -51.9253], 4);

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: "&copy; OpenStreetMap contributors",
    maxZoom: 18
  }).addTo(map);

  const select = document.getElementById("map-metric");
  if (select) {
    select.addEventListener("change", updateMapMetric);
  }

  storyFeatures = features;
  updateMapMetric();
}

// ---------- Faixas de aglomerados ----------

function biomeLabel(biome) {
  return biome ? `no bioma ${biome}` : "no país";
}

function renderClassesChart(biome) {
  const container = document.getElementById("classes-chart");
  const summary = document.getElementById("classes-summary");
  const groups = summarizeClasses(rowsForBiome(biome));
  const filled = groups.filter((group) => group.n > 0);

  if (filled.length === 0) {
    container.textContent = "Não há municípios com dados para este recorte.";
    summary.textContent = "";
    return;
  }

  const first = filled[0];
  const last = filled[filled.length - 1];

  summary.textContent = filled.length > 1
    ? `Percentual de municípios com tendência negativa do NDVI ${biomeLabel(biome)}, por número de aglomerados quilombolas. A parcela em queda passa de ${formatPercent(first.negativeShare)} ${classPhrase(first)} para ${formatPercent(last.negativeShare)} ${classPhrase(last)}.`
    : `Percentual de municípios com tendência negativa do NDVI ${biomeLabel(biome)}, por número de aglomerados quilombolas.`;

  const header = `
    <div class="bar-row bar-row--header" aria-hidden="true">
      <span>Aglomerados</span>
      <span>Municípios com NDVI em queda</span>
      <span>Mediana do NDVI</span>
    </div>
  `;

  const rows = groups.map((group) => {
    const width = group.negativeShare === null ? 0 : group.negativeShare * 100;
    const isSmall = group.n > 0 && group.n < smallSampleSize;
    const title = group.n === 0
      ? `${group.label}: sem municípios`
      : `${group.label}: ${formatPercent(group.negativeShare)} de ${formatCount(group.n)} municípios com NDVI em queda; mediana ${formatSlope(group.medianSlope)}`;

    return `
      <div class="bar-row" title="${escapeHtml(title)}">
        <span class="bar-label">${escapeHtml(group.label)}<small>n = ${formatCount(group.n)}${isSmall ? " · amostra pequena" : ""}</small></span>
        <div class="bar-track">
          <span class="bar-half" aria-hidden="true"></span>
          <span class="bar-fill" style="width:${width}%"></span>
          <strong class="bar-value">${group.n === 0 ? "sem dado" : formatPercent(group.negativeShare)}</strong>
        </div>
        <span class="bar-median ${group.medianSlope !== null && group.medianSlope < 0 ? "is-negative" : ""}">${group.medianSlope === null ? "—" : formatSlope(group.medianSlope)}</span>
      </div>
    `;
  }).join("");

  container.innerHTML = `${header}${rows}<p class="chart-caption">A marca vertical indica 50%: à direita dela, a maioria dos municípios da faixa perde vegetação.</p>`;
}

// ---------- Dispersão ----------

function scaleLinear(domainMin, domainMax, rangeMin, rangeMax) {
  if (domainMin === domainMax) {
    return () => (rangeMin + rangeMax) / 2;
  }

  return (value) => rangeMin + ((value - domainMin) / (domainMax - domainMin)) * (rangeMax - rangeMin);
}

function tickValues(min, max, count) {
  if (count <= 1 || min === max) {
    return [min];
  }

  return Array.from({ length: count }, (_, index) => min + ((max - min) * index) / (count - 1));
}

function stableJitter(text) {
  let hash = 0;
  for (let index = 0; index < text.length; index += 1) {
    hash = ((hash * 31) + text.charCodeAt(index)) % 100003;
  }
  return (hash / 100003) - 0.5;
}

function renderCorrelation(biome) {
  const rows = rowsForBiome(biome);
  const xs = rows.map((row) => row.count);
  const ys = rows.map((row) => row.slope);
  const rho = spearman(xs, ys);
  const r = pearson(xs, ys);
  const summary = document.getElementById("correlation-summary");
  const plot = document.getElementById("correlation-plot");

  document.getElementById("correlation-count").textContent = `n = ${formatCount(rows.length)} municípios`;

  if (rho === null) {
    document.getElementById("spearman-value").textContent = "n/a";
    document.getElementById("pearson-value").textContent = "";
    summary.textContent = "Não há municípios suficientes para calcular a correlação neste recorte.";
    plot.textContent = "Sem dados suficientes para o gráfico.";
    return;
  }

  document.getElementById("spearman-value").textContent = decimalFormatter.format(rho);
  document.getElementById("pearson-value").textContent = r === null ? "" : `Pearson r = ${decimalFormatter.format(r)}`;

  const direction = rho < 0 ? "negativa" : "positiva";
  const meaning = rho < 0
    ? "municípios com mais aglomerados tendem a ter tendência de NDVI mais baixa"
    : "municípios com mais aglomerados tendem a ter tendência de NDVI mais alta";

  summary.textContent = `${biome ? `No bioma ${biome}, a` : "A"} correlação de postos de Spearman entre o número de aglomerados e o overall_slope é ρ = ${decimalFormatter.format(rho)}, uma associação ${correlationStrength(rho)} e ${direction}: ${meaning}. A dispersão entre os pontos é grande, então o número de aglomerados explica pouco da variação do NDVI.`;

  renderScatterPlot(plot, rows, summarizeClasses(rows));
}

function renderScatterPlot(container, rows, groups) {
  const width = 760;
  const height = 440;
  const margin = { top: 24, right: 24, bottom: 58, left: 82 };
  const innerWidth = width - margin.left - margin.right;
  const innerHeight = height - margin.top - margin.bottom;
  const maxCount = Math.max(...rows.map((row) => row.count), 1);
  const ys = rows.map((row) => row.slope);
  const minY = Math.min(...ys, 0);
  const maxY = Math.max(...ys, 0);
  const yPadding = (maxY - minY) * 0.05 || 0.001;
  const xScale = scaleLinear(-0.25, Math.log1p(maxCount) + 0.15, margin.left, margin.left + innerWidth);
  const yScale = scaleLinear(minY - yPadding, maxY + yPadding, margin.top + innerHeight, margin.top);
  const xTicks = [0, 1, 2, 5, 10, 20, 50, 100, 200].filter((tick) => tick <= maxCount * 1.1);
  const yTicks = tickValues(minY, maxY, 5);

  const grid = yTicks.map((tick) => `
    <g class="axis-grid">
      <line x1="${margin.left}" x2="${margin.left + innerWidth}" y1="${yScale(tick)}" y2="${yScale(tick)}"></line>
      <text x="${margin.left - 12}" y="${yScale(tick) + 4}" text-anchor="end">${formatSlope(tick)}</text>
    </g>
  `).join("");

  const xAxis = xTicks.map((tick) => `
    <g class="axis-tick">
      <line x1="${xScale(Math.log1p(tick))}" x2="${xScale(Math.log1p(tick))}" y1="${margin.top + innerHeight}" y2="${margin.top + innerHeight + 6}"></line>
      <text x="${xScale(Math.log1p(tick))}" y="${margin.top + innerHeight + 24}" text-anchor="middle">${formatCount(tick)}</text>
    </g>
  `).join("");

  const points = rows.map((row) => {
    const x = xScale(Math.log1p(row.count) + stableJitter(row.feature.properties.CD_MUN || row.name) * 0.18);
    const y = yScale(row.slope);

    return `
      <circle class="scatter-dot ${row.slope < 0 ? "is-negative" : ""}" cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="2.6">
        <title>${escapeHtml(row.name)} (${escapeHtml(row.biome)}): ${formatCount(row.count)} aglomerados · NDVI ${formatSlope(row.slope)}</title>
      </circle>
    `;
  }).join("");

  const medianPoints = groups
    .filter((group) => group.n > 0)
    .map((group) => ({ x: xScale(Math.log1p(group.medianCount)), y: yScale(group.medianSlope), group }));

  const medianLine = medianPoints.length > 1
    ? `<polyline class="median-line" points="${medianPoints.map((point) => `${point.x},${point.y}`).join(" ")}"></polyline>`
    : "";

  const medianMarkers = medianPoints.map((point) => `
    <circle class="median-marker" cx="${point.x}" cy="${point.y}" r="5.5">
      <title>Faixa ${escapeHtml(point.group.label)}: mediana ${formatSlope(point.group.medianSlope)} (n = ${formatCount(point.group.n)})</title>
    </circle>
  `).join("");

  container.innerHTML = `
    <svg viewBox="0 0 ${width} ${height}" role="img" aria-label="Dispersão entre número de aglomerados quilombolas e tendência do NDVI por município">
      <rect class="plot-background" x="${margin.left}" y="${margin.top}" width="${innerWidth}" height="${innerHeight}"></rect>
      ${grid}
      <line class="zero-line" x1="${margin.left}" x2="${margin.left + innerWidth}" y1="${yScale(0)}" y2="${yScale(0)}"></line>
      <line class="axis-line" x1="${margin.left}" x2="${margin.left}" y1="${margin.top}" y2="${margin.top + innerHeight}"></line>
      <line class="axis-line" x1="${margin.left}" x2="${margin.left + innerWidth}" y1="${margin.top + innerHeight}" y2="${margin.top + innerHeight}"></line>
      ${xAxis}
      <g class="scatter-points">${points}</g>
      ${medianLine}
      ${medianMarkers}
      <text class="axis-title" x="${margin.left + innerWidth / 2}" y="${height - 10}" text-anchor="middle">aglomerados quilombolas no município (escala logarítmica)</text>
      <text class="axis-title" transform="translate(18 ${margin.top + innerHeight / 2}) rotate(-90)" text-anchor="middle">tendência do NDVI (overall_slope)</text>
    </svg>
  `;
}

// ---------- Biomas ----------

function biomeComparison() {
  const biomes = [...new Set(validRows.map((row) => row.biome))].sort((a, b) => a.localeCompare(b, "pt-BR"));

  return biomes.map((biome) => {
    const rows = rowsForBiome(biome);
    const withRows = rows.filter((row) => row.count > 0);
    const withoutRows = rows.filter((row) => row.count === 0);

    return {
      biome,
      n: rows.length,
      withN: withRows.length,
      withoutN: withoutRows.length,
      withShare: shareNegative(withRows),
      withoutShare: shareNegative(withoutRows),
      rho: spearman(rows.map((row) => row.count), rows.map((row) => row.slope))
    };
  });
}

function renderBiomeChart(comparison) {
  const container = document.getElementById("biome-chart");
  const summary = document.getElementById("biome-summary");
  const reliable = comparison.filter((item) => item.withN >= smallSampleSize && item.withoutN >= smallSampleSize);
  const higherWith = reliable.filter((item) => item.withShare > item.withoutShare);
  const exceptions = reliable.filter((item) => item.withShare <= item.withoutShare);

  summary.textContent = [
    `Percentual de municípios com NDVI em queda, comparando municípios sem e com aglomerados quilombolas dentro de cada bioma.`,
    `Em ${formatCount(higherWith.length)} de ${formatCount(reliable.length)} biomas com amostra suficiente, a queda é mais frequente onde há aglomerados.`,
    exceptions.length === 1 ? `A exceção é o bioma ${exceptions[0].biome}.` : "",
    exceptions.length > 1 ? `As exceções são os biomas ${exceptions.map((item) => item.biome).join(" e ")}.` : ""
  ].filter(Boolean).join(" ");

  const legend = `
    <div class="chart-legend">
      <span><i class="legend-dot legend-dot--without"></i>Sem aglomerados</span>
      <span><i class="legend-dot legend-dot--with"></i>Com aglomerados</span>
    </div>
  `;

  const rows = comparison.map((item) => {
    const isSmall = item.withN < smallSampleSize || item.withoutN < smallSampleSize;
    const bar = (share, n, modifier, label) => `
      <div class="pair-bar" title="${escapeHtml(`${item.biome}, ${label}: ${formatPercent(share)} de ${formatCount(n)} municípios com NDVI em queda`)}">
        <div class="bar-track bar-track--thin">
          <span class="bar-half" aria-hidden="true"></span>
          <span class="bar-fill ${modifier}" style="width:${share === null ? 0 : share * 100}%"></span>
        </div>
        <strong>${formatPercent(share)}</strong>
      </div>
    `;

    return `
      <div class="biome-row">
        <div class="biome-label">
          <strong>${escapeHtml(item.biome)}</strong>
          <small>${formatCount(item.n)} municípios · ρ = ${item.rho === null ? "n/a" : decimalFormatter.format(item.rho)}${isSmall ? " · amostra pequena" : ""}</small>
        </div>
        <div class="biome-bars">
          ${bar(item.withoutShare, item.withoutN, "bar-fill--without", "sem aglomerados")}
          ${bar(item.withShare, item.withN, "", "com aglomerados")}
        </div>
      </div>
    `;
  }).join("");

  container.innerHTML = `${legend}${rows}`;
}

// ---------- Resposta ----------

function renderAnswer(comparison) {
  const groups = summarizeClasses(validRows).filter((group) => group.n > 0);
  const rho = spearman(validRows.map((row) => row.count), validRows.map((row) => row.slope));
  const first = groups[0];
  const last = groups[groups.length - 1];
  const reliable = comparison.filter((item) => item.withN >= smallSampleSize && item.withoutN >= smallSampleSize);
  const negativeWithin = reliable.filter((item) => item.rho !== null && item.rho < 0);
  const title = document.getElementById("answer-title");
  const text = document.getElementById("answer-text");

  if (rho === null || !first || !last) {
    title.textContent = "Não foi possível responder com estes dados.";
    text.textContent = "";
    return;
  }

  const isNegative = rho < 0;
  const strength = correlationStrength(rho);

  title.textContent = isNegative
    ? `Sim, existe uma relação negativa, mas ela é ${strength}.`
    : `Não há relação negativa: a associação é ${strength} e ${rho < 0 ? "negativa" : "positiva"}.`;

  text.textContent = [
    `Nos ${formatCount(validRows.length)} municípios analisados, o número de aglomerados quilombolas e a tendência do NDVI têm correlação ρ = ${decimalFormatter.format(rho)}.`,
    `A parcela de municípios com vegetação em queda sobe de ${formatPercent(first.negativeShare)} ${classPhrase(first)} para ${formatPercent(last.negativeShare)} ${classPhrase(last)}.`,
    `A relação aparece também dentro de ${formatCount(negativeWithin.length)} dos ${formatCount(reliable.length)} biomas com amostra suficiente, o que indica que ela não se explica apenas pela diferença entre biomas.`,
    "Isso não significa que os quilombos causam desmatamento. Uma explicação possível é que muitos aglomerados estão em regiões onde a vegetação já sofre pressão de outras atividades, como a expansão agropecuária, o que coloca essas comunidades diante da perda ambiental. Testar essa hipótese exige dados mais finos, no nível do território."
  ].join(" ");
}

// ---------- Inicialização ----------

function populateBiomeFilter() {
  const select = document.getElementById("biome-filter");
  const biomes = [...new Set(validRows.map((row) => row.biome))].sort((a, b) => a.localeCompare(b, "pt-BR"));

  biomes.forEach((biome) => {
    const option = document.createElement("option");
    option.value = biome;
    option.textContent = biome;
    select.appendChild(option);
  });

  select.addEventListener("change", () => {
    renderClassesChart(select.value);
    renderCorrelation(select.value);
  });
}

function showLoadError() {
  document.getElementById("data-summary").textContent = "Não foi possível carregar os dados desta história.";
  ["agglomerates-total", "municipalities-with", "loss-with", "loss-without", "spearman-value"].forEach((id) => {
    document.getElementById(id).textContent = "n/a";
  });
  document.getElementById("classes-summary").textContent = "Não foi possível carregar os dados.";
  document.getElementById("correlation-summary").textContent = "Não foi possível calcular a correlação.";
  document.getElementById("biome-summary").textContent = "Não foi possível comparar os biomas.";
  document.getElementById("answer-text").textContent = "";
}

fetch(dataFile)
  .then((response) => {
    if (!response.ok) {
      throw new Error("Data request failed");
    }

    return response.json();
  })
  .then((data) => {
    const features = data.features || [];
    validRows = toRows(features);

    const comparison = biomeComparison();

    updateSummaryCards(features);
    initMap(features);
    populateBiomeFilter();
    renderClassesChart("");
    renderCorrelation("");
    renderBiomeChart(comparison);
    renderAnswer(comparison);
  })
  .catch((error) => {
    console.error(error);
    showLoadError();
  });
