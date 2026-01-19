import { Controller } from "@hotwired/stimulus";
import maplibregl from "maplibre-gl";
import StyleFlipperControl from "maplibre-gl-style-flipper";

// Connects to data-controller="heatmap"
export default class extends Controller {
  static targets = ["map"];
  static values = {
    trackUrl: String,
    center: Array,
    zoom: Number,
    style: String,
    lineColor: String,
    lineWidth: Number,
  };

  defaults = {
    center: [13.41, 52.52],
    zoom: 10,
    style: "carto-voyager",
    lineColor: "#FF3333",
    lineWidth: 3,
    lineOpacity: 0.2,
  };

  mapStyles = {
    "openfreemap-liberty": {
      code: "liberty",
      url: "https://tiles.openfreemap.org/styles/liberty",
      image: "",
    },
    "carto-voyager": {
      code: "carto-voyager",
      url: "https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json",
      image:
        "https://carto.com/help/images/building-maps/basemaps/voyager_labels.png",
    },
    "carto-voyager-nolabels": {
      code: "carto-voyager-nolabels",
      url: "https://basemaps.cartocdn.com/gl/voyager-nolabels-gl-style/style.json",
      image:
        "https://carto.com/help/images/building-maps/basemaps/voyager_no_labels.png",
    },
    "carto-positron": {
      code: "carto-positron",
      url: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json",
      image:
        "https://carto.com/help/images/building-maps/basemaps/positron_labels.png",
    },
    "carto-positron-nolabels": {
      code: "carto-positron-nolabels",
      url: "https://basemaps.cartocdn.com/gl/positron-nolabels-gl-style/style.json",
      image:
        "https://carto.com/help/images/building-maps/basemaps/positron_no_labels.png",
    },
    "carto-dark": {
      code: "carto-dark",
      url: "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json",
      image:
        "https://carto.com/help/images/building-maps/basemaps/dark_labels.png",
    },
    "carto-dark-nolabels": {
      code: "carto-dark-nolabels",
      url: "https://basemaps.cartocdn.com/gl/dark-matter-nolabels-gl-style/style.json",
      image:
        "https://carto.com/help/images/building-maps/basemaps/dark_no_labels.png",
    },
  };

  connect() {
    if (!this.map) this.setupMap();
    this.map.once("load", () => {
      this.addVectorTiles();
      //this.addRasterTiles();
    });
  }

  setupMap() {
    this.map = new maplibregl.Map({
      container: this.mapTarget,
      style: this.getMapStyle().url,
      center: this.getMapCenter(),
      zoom: this.getMapZoom(),
      maxZoom: 15,
    });
    this.map.addControl(new maplibregl.FullscreenControl());
    this.map.addControl(new maplibregl.NavigationControl());
    this.map.addControl(new maplibregl.GlobeControl());
    //this.map.addControl(new maplibregl.TerrainControl({ source: "terrain" }));
    // this.map.addControl(new maplibregl.ScaleControl({ maxWidth: 80, unit: "metric" }));

    const styleFlipperControl = new StyleFlipperControl(this.mapStyles);
    // Set the initial style code
    styleFlipperControl.setCurrentStyleCode(this.getMapStyle().code);
    this.map.addControl(styleFlipperControl, "bottom-left");
  }

  addRasterTiles() {
    const source_options = {
      type: "raster",
      tiles: ["http://localhost:8000/tiles/{z}/{x}/{y}.png"],
      tileSize: 256,
      minzoom: 0,
      maxzoom: 16,
    };
    this.map.on("load", () => {
      this.map.addSource("heatmap-raster-tiles", source_options);
      this.map.addLayer({
        id: "hotpot",
        type: "raster",
        source: "heatmap-raster-tiles",
      });
    });
  }

  addVectorTiles() {
    this.map.addSource("postgis-vector-tiles", {
      type: "vector",
      tiles: ["http://localhost:3003/heatmap/{z}/{x}/{y}.mvt"],
      tileSize: 512,
    });

    this.map.addLayer({
      id: "heatmap-vector-tiles",
      type: "line",
      source: "postgis-vector-tiles",
      "source-layer": "activities",
      layout: {
        "line-join": "round",
        "line-cap": "round",
      },
      paint: {
        "line-opacity": this.getLineOpacity(),
        "line-color": this.getLineColor(),
        "line-width": this.getLineWidth(),
      },
    });
  }

  getMapCenter() {
    return Array.isArray(this.centerValue) && this.centerValue.length === 2
      ? this.centerValue
      : this.defaults.center;
  }

  getMapZoom() {
    return this.zoomValue || this.defaults.zoom;
  }

  getMapStyle() {
    return (
      this.mapStyles[this.styleValue] || this.mapStyles[this.defaults.style]
    );
  }

  getLineColor() {
    return this.lineColorValue || this.defaults.lineColor;
  }

  getLineWidth() {
    return this.lineWidthValue || this.defaults.lineWidth;
  }

  getLineOpacity() {
    return this.lineOpacityValue || this.defaults.lineOpacity;
  }
}
