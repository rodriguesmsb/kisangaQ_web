// path to the municipalities data file
const municipalitiesFile = "brazil_municipalities.json";


// create a function to fill map according to 



// load the municipalities data
fetch(municipalitiesFile)
.then(response => response.json())
.then(data => {
    // add the municipalities data to leaflet map
    const municipalitiesLayer = L.geoJSON(data, {

        // create basic style for the municipalities
        style: {
            color: "#8b6432",
            weight: 0.4,
            fillOpacity: 0.5,
            fillColor: "#d8c3a5"
        },

        // add a popup to each municipality with its name
        onEachFeature: function (feature, layer) {
            const municipalityName = feature.properties.NM_MUN;
            const biome = feature.properties.bioma;
            layer.bindPopup(`<strong>${municipalityName}</strong><br>Biome: ${biome}`);
            console.log(feature.properties);
        }
    }).addTo(map);

    window.fitBounds(municipalitiesLayer.getBounds());
});
  

