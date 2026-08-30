const dataFile = "002_data_for_story.json";

const violenceMetrics = [
  {
    key: "homicidio_doloso",
    label: "Homicídio doloso",
    pluralLabel: "homicídios dolosos",
    totalElement: "homicide-total"
  },
  {
    key: "feminicidio",
    label: "Feminicídio",
    pluralLabel: "feminicídios",
    totalElement: "femicide-total"
  },
  {
    key: "suicidio",
    label: "Suicídio",
    pluralLabel: "suicídios",
    totalElement: "suicide-total"
  }
];

const mapColors = ["#2b6cb0", "#6aaed6", "#f1f4ee", "#f0a35b", "#b83232"];
const missingColor = "#d6d9d2";
const numberFormatter = new Intl.NumberFormat("pt-BR");
const decimalFormatter = new Intl.NumberFormat("pt-BR", {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2
});
const slopeFormatter = new Intl.NumberFormat("pt-BR", {
  minimumFractionDigits: 4,
  maximumFractionDigits: 4
});
const ndviFormatter = new Intl.NumberFormat("pt-BR", {
  minimumFractionDigits: 3,
  maximumFractionDigits: 3
});

let map;
let stateLayer;
let storyFeatures = [];

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

function formatMetric(value) {
  const number = parseNumber(value);
  return number === null ? "Sem dado" : formatCount(number);
}

function formatSlope(value) {
  const number = parseNumber(value);

  if (number === null) {
    return "Sem dado";
  }

  const prefix = number > 0 ? "+" : "";
  return `${prefix}${slopeFormatter.format(number)}`;
}

function sumMetric(features, key) {
  return features.reduce((total, feature) => {
    const value = parseNumber(feature.properties[key]);
    return value === null ? total : total + value;
  }, 0);
}

function finiteFeatures(features, key) {
  return features.filter((feature) => parseNumber(feature.properties[key]) !== null);
}

function allViolenceValuesPresent(feature) {
  return violenceMetrics.every((metric) => parseNumber(feature.properties[metric.key]) !== null);
}

function topFeature(features, key, direction = "max") {
  const valid = finiteFeatures(features, key);

  if (valid.length === 0) {
    return null;
  }

  return valid.reduce((selected, feature) => {
    const currentValue = parseNumber(feature.properties[key]);
    const selectedValue = parseNumber(selected.properties[key]);
    return direction === "min"
      ? currentValue < selectedValue ? feature : selected
      : currentValue > selectedValue ? feature : selected;
  }, valid[0]);
}

function updateSummaryCards(features) {
  const totals = Object.fromEntries(
    violenceMetrics.map((metric) => [metric.key, sumMetric(features, metric.key)])
  );
  const totalViolence = violenceMetrics.reduce((total, metric) => total + totals[metric.key], 0);
  const availableCount = features.filter(allViolenceValuesPresent).length;
  const topHomicide = topFeature(features, "homicidio_doloso");

  document.getElementById("violence-total").textContent = formatCount(totalViolence);

  violenceMetrics.forEach((metric) => {
    document.getElementById(metric.totalElement).textContent = formatCount(totals[metric.key]);
  });

  document.getElementById("data-summary").textContent = [
    `A base reúne ${formatCount(features.length)} unidades federativas, com valores completos de violência para ${formatCount(availableCount)} delas.`,
    `Nos registros disponíveis, aparecem ${formatCount(totals.homicidio_doloso)} homicídios dolosos, ${formatCount(totals.feminicidio)} feminicídios e ${formatCount(totals.suicidio)} suicídios.`,
    topHomicide ? `${cleanText(topHomicide.properties.NM_UF)} concentra o maior total de homicídios dolosos no recorte estadual.` : ""
  ].filter(Boolean).join(" ");
}

function quantileBreaks(values, classCount = 5) {
  const sorted = values
    .filter((value) => Number.isFinite(value))
    .slice()
    .sort((a, b) => a - b);

  if (sorted.length === 0) {
    return [];
  }

  return Array.from({ length: classCount }, (_, index) => {
    const position = Math.ceil(((index + 1) / classCount) * sorted.length) - 1;
    return sorted[Math.max(0, Math.min(position, sorted.length - 1))];
  });
}

function categoryIndex(value, breaks) {
  for (let index = 0; index < breaks.length; index += 1) {
    if (value <= breaks[index]) {
      return index;
    }
  }

  return breaks.length - 1;
}

function classificationForMetric(metricKey) {
  const values = storyFeatures
    .map((feature) => parseNumber(feature.properties[metricKey]))
    .filter((value) => value !== null);

  return {
    breaks: quantileBreaks(values, mapColors.length),
    min: values.length > 0 ? Math.min(...values) : null
  };
}

function colorForFeature(feature, metricKey, breaks) {
  const value = parseNumber(feature.properties[metricKey]);

  if (value === null || breaks.length === 0) {
    return missingColor;
  }

  return mapColors[categoryIndex(value, breaks)];
}

function selectedMetric() {
  const select = document.getElementById("map-metric");
  const key = select ? select.value : "homicidio_doloso";
  return violenceMetrics.find((metric) => metric.key === key) || violenceMetrics[0];
}

function mapStyle(metricKey, breaks) {
  return (feature) => {
    const hasValue = parseNumber(feature.properties[metricKey]) !== null;

    return {
      color: "#ffffff",
      fillColor: colorForFeature(feature, metricKey, breaks),
      fillOpacity: hasValue ? 0.82 : 0.45,
      opacity: 1,
      weight: 1
    };
  };
}

function statePopup(properties) {
  const rows = violenceMetrics.map((metric) => {
    return `<dt>${escapeHtml(metric.label)}</dt><dd>${formatMetric(properties[metric.key])}</dd>`;
  }).join("");

  return `
    <strong>${escapeHtml(properties.NM_UF)}</strong>
    <span>${escapeHtml(properties.SIGLA_UF)} · ${escapeHtml(properties.NM_REGIAO)}</span>
    <dl>
      ${rows}
      <dt>overall_slope</dt><dd>${formatSlope(properties.overall_slope)}</dd>
      <dt>NDVI inicial</dt><dd>${parseNumber(properties.ndvi_start) === null ? "Sem dado" : ndviFormatter.format(properties.ndvi_start)}</dd>
      <dt>NDVI final</dt><dd>${parseNumber(properties.ndvi_end) === null ? "Sem dado" : ndviFormatter.format(properties.ndvi_end)}</dd>
    </dl>
  `;
}

function bindStateInteractions(layer, metricKey, breaks) {
  layer.eachLayer((state) => {
    state.bindPopup(statePopup(state.feature.properties));
    state.bindTooltip(cleanText(state.feature.properties.NM_UF));

    state.on({
      mouseover(event) {
        event.target.setStyle({
          color: "#18211f",
          fillOpacity: 0.95,
          weight: 2
        });
        event.target.bringToFront();
      },
      mouseout(event) {
        event.target.setStyle(mapStyle(metricKey, breaks)(event.target.feature));
      }
    });
  });
}

function renderLegend(metric, classification) {
  const legend = document.getElementById("map-legend");

  if (!legend) {
    return;
  }

  if (classification.breaks.length === 0) {
    legend.textContent = "Sem dados para o indicador selecionado.";
    return;
  }

  let lowerBound = classification.min;
  const items = classification.breaks.map((upperBound, index) => {
    const label = index === 0
      ? `Até ${formatCount(upperBound)}`
      : `${formatCount(lowerBound + 1)} a ${formatCount(upperBound)}`;

    lowerBound = upperBound;

    return `
      <div class="legend-item">
        <span class="legend-swatch" style="background:${mapColors[index]}"></span>
        <span>${label}</span>
      </div>
    `;
  }).join("");

  legend.innerHTML = `
    <strong>${escapeHtml(metric.label)}</strong>
    ${items}
    <div class="legend-item">
      <span class="legend-swatch legend-swatch--missing"></span>
      <span>Sem dado</span>
    </div>
  `;
}

function updateMapMetric() {
  if (!map || storyFeatures.length === 0) {
    return;
  }

  const metric = selectedMetric();
  const classification = classificationForMetric(metric.key);

  if (stateLayer) {
    stateLayer.remove();
  }

  stateLayer = L.geoJSON(storyFeatures, {
    renderer: L.canvas({ padding: 0.5 }),
    style: mapStyle(metric.key, classification.breaks)
  }).addTo(map);

  bindStateInteractions(stateLayer, metric.key, classification.breaks);
  renderLegend(metric, classification);

  const bounds = stateLayer.getBounds();
  if (bounds.isValid()) {
    map.fitBounds(bounds, { padding: [24, 24] });
  }
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

function updateNdviSummary(features) {
  const valid = finiteFeatures(features, "overall_slope");
  const positive = valid.filter((feature) => parseNumber(feature.properties.overall_slope) > 0);
  const negative = valid.filter((feature) => parseNumber(feature.properties.overall_slope) < 0);
  const highest = topFeature(features, "overall_slope", "max");
  const lowest = topFeature(features, "overall_slope", "min");

  document.getElementById("ndvi-summary").textContent = [
    `Entre as ${formatCount(valid.length)} unidades federativas com NDVI, ${formatCount(positive.length)} apresentam tendência positiva e ${formatCount(negative.length)} apresentam queda.`,
    highest ? `${cleanText(highest.properties.NM_UF)} tem o maior aumento médio (${formatSlope(highest.properties.overall_slope)}).` : "",
    lowest ? `${cleanText(lowest.properties.NM_UF)} tem a maior redução (${formatSlope(lowest.properties.overall_slope)}).` : ""
  ].filter(Boolean).join(" ");
}

function renderNdviBars(features) {
  const container = document.getElementById("ndvi-bars");
  const rows = finiteFeatures(features, "overall_slope")
    .map((feature) => ({
      state: cleanText(feature.properties.NM_UF),
      uf: cleanText(feature.properties.SIGLA_UF),
      start: parseNumber(feature.properties.ndvi_start),
      end: parseNumber(feature.properties.ndvi_end),
      slope: parseNumber(feature.properties.overall_slope)
    }))
    .sort((a, b) => b.slope - a.slope);

  if (rows.length === 0) {
    container.textContent = "Não há valores de NDVI disponíveis.";
    return;
  }

  const maxAbs = Math.max(...rows.map((row) => Math.abs(row.slope)));

  container.innerHTML = rows.map((row) => {
    const width = maxAbs === 0 ? 0 : (Math.abs(row.slope) / maxAbs) * 50;
    const isPositive = row.slope >= 0;
    const left = isPositive ? 50 : 50 - width;
    const title = `${row.state}: NDVI ${row.start === null ? "sem dado" : ndviFormatter.format(row.start)} para ${row.end === null ? "sem dado" : ndviFormatter.format(row.end)}`;

    return `
      <div class="ndvi-row" title="${escapeHtml(title)}">
        <span class="ndvi-state">${escapeHtml(row.uf)}</span>
        <div class="ndvi-track">
          <span class="ndvi-zero"></span>
          <span
            class="ndvi-bar ${isPositive ? "is-positive" : "is-negative"}"
            style="left:${left}%; width:${width}%"
          ></span>
        </div>
        <strong>${formatSlope(row.slope)}</strong>
      </div>
    `;
  }).join("");
}

function pearsonCorrelation(rows, xKey, yKey) {
  const pairs = rows
    .map((feature) => ({
      feature,
      x: parseNumber(feature.properties[xKey]),
      y: parseNumber(feature.properties[yKey])
    }))
    .filter((row) => row.x !== null && row.y !== null);

  if (pairs.length < 2) {
    return { pairs, r: null, intercept: null, slope: null };
  }

  const meanX = pairs.reduce((total, row) => total + row.x, 0) / pairs.length;
  const meanY = pairs.reduce((total, row) => total + row.y, 0) / pairs.length;
  const covariance = pairs.reduce((total, row) => total + ((row.x - meanX) * (row.y - meanY)), 0);
  const sumX = pairs.reduce((total, row) => total + ((row.x - meanX) ** 2), 0);
  const sumY = pairs.reduce((total, row) => total + ((row.y - meanY) ** 2), 0);
  const denominator = Math.sqrt(sumX * sumY);
  const trendSlope = sumX === 0 ? null : covariance / sumX;

  return {
    pairs,
    r: denominator === 0 ? null : covariance / denominator,
    intercept: trendSlope === null ? null : meanY - (trendSlope * meanX),
    slope: trendSlope
  };
}

function correlationStrength(r) {
  const absolute = Math.abs(r);
  if (absolute < 0.2) return "muito fraca";
  if (absolute < 0.4) return "fraca";
  if (absolute < 0.6) return "moderada";
  if (absolute < 0.8) return "forte";
  return "muito forte";
}

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

function renderCorrelation(features) {
  const result = pearsonCorrelation(features, "overall_slope", "homicidio_doloso");
  const summary = document.getElementById("correlation-summary");
  const value = document.getElementById("correlation-value");
  const count = document.getElementById("correlation-count");
  const plot = document.getElementById("correlation-plot");

  if (result.r === null) {
    summary.textContent = "Não há pares suficientes para calcular a correlação.";
    value.textContent = "n/a";
    count.textContent = "";
    plot.textContent = "Sem dados suficientes para o gráfico.";
    return;
  }

  const direction = result.r < 0 ? "negativa" : "positiva";
  const rText = decimalFormatter.format(result.r);

  value.textContent = rText;
  count.textContent = `n = ${formatCount(result.pairs.length)}`;
  summary.textContent = `A correlação linear simples entre overall_slope e homicídio doloso é r = ${rText} (n = ${formatCount(result.pairs.length)}), uma associação ${correlationStrength(result.r)} e ${direction}. Neste recorte, a leitura é descritiva e não deve ser interpretada como causalidade.`;

  renderScatterPlot(plot, result);
}

function renderScatterPlot(container, result) {
  const width = 760;
  const height = 430;
  const margin = { top: 28, right: 28, bottom: 58, left: 78 };
  const innerWidth = width - margin.left - margin.right;
  const innerHeight = height - margin.top - margin.bottom;
  const xs = result.pairs.map((row) => row.x);
  const ys = result.pairs.map((row) => row.y);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const maxY = Math.max(...ys);
  const xPadding = (maxX - minX) * 0.08 || 0.001;
  const yMax = maxY * 1.08 || 1;
  const xScale = scaleLinear(minX - xPadding, maxX + xPadding, margin.left, margin.left + innerWidth);
  const yScale = scaleLinear(0, yMax, margin.top + innerHeight, margin.top);
  const xTicks = tickValues(minX, maxX, 5);
  const yTicks = tickValues(0, yMax, 5);
  const topStates = result.pairs
    .slice()
    .sort((a, b) => b.y - a.y)
    .slice(0, 3)
    .map((row) => row.feature.properties.SIGLA_UF);

  const regressionLine = result.slope === null ? "" : (() => {
    const x1 = minX;
    const x2 = maxX;
    const y1 = result.intercept + (result.slope * x1);
    const y2 = result.intercept + (result.slope * x2);

    return `
      <line
        class="trend-line"
        x1="${xScale(x1)}"
        y1="${yScale(y1)}"
        x2="${xScale(x2)}"
        y2="${yScale(y2)}"
      ></line>
    `;
  })();

  const grid = yTicks.map((tick) => `
    <g class="axis-grid">
      <line x1="${margin.left}" x2="${margin.left + innerWidth}" y1="${yScale(tick)}" y2="${yScale(tick)}"></line>
      <text x="${margin.left - 12}" y="${yScale(tick) + 4}" text-anchor="end">${formatCount(tick)}</text>
    </g>
  `).join("");

  const xAxis = xTicks.map((tick) => `
    <g class="axis-tick">
      <line x1="${xScale(tick)}" x2="${xScale(tick)}" y1="${margin.top + innerHeight}" y2="${margin.top + innerHeight + 6}"></line>
      <text x="${xScale(tick)}" y="${margin.top + innerHeight + 26}" text-anchor="middle">${formatSlope(tick)}</text>
    </g>
  `).join("");

  const points = result.pairs.map((row) => {
    const properties = row.feature.properties;
    const uf = cleanText(properties.SIGLA_UF);
    const isLabeled = topStates.includes(uf);

    return `
      <g class="scatter-point ${isLabeled ? "is-labeled" : ""}">
        <circle cx="${xScale(row.x)}" cy="${yScale(row.y)}" r="${isLabeled ? 6 : 4.5}">
          <title>${escapeHtml(cleanText(properties.NM_UF))}: ${formatSlope(row.x)} · ${formatCount(row.y)} homicídios dolosos</title>
        </circle>
        ${isLabeled ? `<text x="${xScale(row.x) + 9}" y="${yScale(row.y) - 8}">${escapeHtml(uf)}</text>` : ""}
      </g>
    `;
  }).join("");

  container.innerHTML = `
    <svg viewBox="0 0 ${width} ${height}" role="img" aria-label="Dispersão entre overall_slope de NDVI e homicídio doloso">
      <rect class="plot-background" x="${margin.left}" y="${margin.top}" width="${innerWidth}" height="${innerHeight}"></rect>
      ${grid}
      <line class="axis-line" x1="${margin.left}" x2="${margin.left}" y1="${margin.top}" y2="${margin.top + innerHeight}"></line>
      <line class="axis-line" x1="${margin.left}" x2="${margin.left + innerWidth}" y1="${margin.top + innerHeight}" y2="${margin.top + innerHeight}"></line>
      ${xAxis}
      ${regressionLine}
      ${points}
      <text class="axis-title" x="${margin.left + innerWidth / 2}" y="${height - 12}" text-anchor="middle">overall_slope</text>
      <text class="axis-title axis-title--y" transform="translate(18 ${margin.top + innerHeight / 2}) rotate(-90)" text-anchor="middle">homicídio doloso</text>
    </svg>
  `;
}

function showLoadError() {
  document.getElementById("data-summary").textContent = "Não foi possível carregar os dados desta história.";
  document.getElementById("violence-total").textContent = "0";
  document.getElementById("homicide-total").textContent = "0";
  document.getElementById("femicide-total").textContent = "0";
  document.getElementById("suicide-total").textContent = "0";
  document.getElementById("ndvi-summary").textContent = "Não foi possível carregar os dados de NDVI.";
  document.getElementById("correlation-summary").textContent = "Não foi possível calcular a correlação.";
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

    updateSummaryCards(features);
    initMap(features);
    updateNdviSummary(features);
    renderNdviBars(features);
    renderCorrelation(features);
  })
  .catch(showLoadError);
