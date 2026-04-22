import { Controller } from "@hotwired/stimulus";
import maplibregl from "maplibre-gl";

const STYLES = ["bright", "liberty", "positron", "dark", "fiord", "black", "white"];

const FLAT_STYLE = (color) => ({
  version: 8,
  sources: {},
  layers: [{ id: "background", type: "background", paint: { "background-color": color } }],
});

const STYLE_URL = (s) => {
  if (s === "black") return FLAT_STYLE("#000000");
  if (s === "white") return FLAT_STYLE("#ffffff");
  return `https://tiles.openfreemap.org/styles/${s}`;
};

export default class extends Controller {
  static targets = ["map", "filterBar"];
  static values = {
    bounds: Array,
    center: Array,
    zoom: Number,
    style: String,
    years: Array,
    types: Array,
  };

  defaults = {
    center: [13.41, 52.52],
    zoom: 10,
    style: "dark",
  };

  palettes = [
    { id: "purple", label: "Purple", stops: ["#5500f5", "#5500f5", "#ffffff"] },
    { id: "hot",    label: "Hot",    stops: ["#3f5efb", "#fc466b", "#ffffff"] },
    { id: "orange", label: "Orange", stops: ["#fc4a1a", "#f7b733", "#ffffff"] },
    { id: "red",    label: "Red",    stops: ["#b20a2c", "#fffbd5", "#ffffff"] },
    { id: "pink",   label: "Pink",   stops: ["#ffb1ff", "#ffb1ff", "#ffffff"] },
    { id: "cyber",  label: "Cyber",  stops: ["#00ff41", "#b4ff00", "#ffffff"] },
  ]

  connect() {
    this.selectedYear    = null;
    this.selectedType    = null;
    this.selectedPalette = localStorage.getItem("heatmap_palette") || "purple";
    this.selectedStyle   = localStorage.getItem("heatmap_style") || this.defaults.style;
    this.buildFilterBar();
    this.setupMap();
    this.map.once("load", () => this.addHeatmapTiles());
  }

  // ── Filter UI ─────────────────────────────────────────────────────────────

  buildFilterBar() {
    const bar = this.filterBarTarget;
    bar.innerHTML = "";

    const yearRow = document.createElement("div");
    yearRow.className = "heatmap-filter-row";

    const allBtn = this.makeBtn("All", !this.selectedYear, () => {
      this.selectedYear = null;
      this.buildFilterBar();
      this.refreshTiles();
    });
    yearRow.appendChild(allBtn);

    if (this.yearsValue.length > 0) {
      yearRow.appendChild(this.makeDivider());
      this.yearsValue.forEach((year) => {
        const btn = this.makeBtn(year, this.selectedYear === year, () => {
          this.selectedYear = this.selectedYear === year ? null : year;
          this.buildFilterBar();
          this.refreshTiles();
        });
        yearRow.appendChild(btn);
      });
    }

    bar.appendChild(yearRow);

    if (this.typesValue.length > 1) {
      const typeRow = document.createElement("div");
      typeRow.className = "heatmap-filter-row";

      const allBtn = this.makeBtn("All", !this.selectedType, () => {
        this.selectedType = null;
        this.buildFilterBar();
        this.refreshTiles();
      });
      typeRow.appendChild(allBtn);
      typeRow.appendChild(this.makeDivider());

      this.typesValue.forEach((type) => {
        const btn = this.makeBtn(type.replace(/_/g, " "), this.selectedType === type, () => {
          this.selectedType = this.selectedType === type ? null : type;
          this.buildFilterBar();
          this.refreshTiles();
        });
        typeRow.appendChild(btn);
      });
      bar.appendChild(typeRow);
    }

    const paletteRow = document.createElement("div");
    paletteRow.className = "heatmap-filter-row";
    this.palettes.forEach(({ id, label, stops }) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.title = label;
      btn.className = "heatmap-palette-btn" + (this.selectedPalette === id ? " active" : "");
      btn.style.background = `linear-gradient(to right, ${stops.join(", ")})`;
      btn.addEventListener("click", () => {
        this.selectedPalette = id;
        localStorage.setItem("heatmap_palette", id);
        this.buildFilterBar();
        this.refreshTiles();
      });
      paletteRow.appendChild(btn);
    });
    bar.appendChild(paletteRow);

    const styleRow = document.createElement("div");
    styleRow.className = "heatmap-filter-row";
    STYLES.forEach((style) => {
      const btn = this.makeBtn(style.charAt(0).toUpperCase() + style.slice(1), this.selectedStyle === style, () => {
        this.selectedStyle = style;
        localStorage.setItem("heatmap_style", style);
        this.buildFilterBar();
        this.map.setStyle(STYLE_URL(style));
        this.map.once("style.load", () => this.addHeatmapTiles());
      });
      styleRow.appendChild(btn);
    });
    bar.appendChild(styleRow);
  }

  makeBtn(label, active, onClick) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.textContent = label;
    btn.className = "heatmap-filter-btn" + (active ? " active" : "");
    btn.addEventListener("click", onClick);
    return btn;
  }

  makeDivider() {
    const span = document.createElement("span");
    span.className = "heatmap-filter-divider";
    return span;
  }

  // ── Tile URL ──────────────────────────────────────────────────────────────

  get tileUrl() {
    const qs = new URLSearchParams();
    if (this.selectedYear)    qs.set("year",    this.selectedYear);
    if (this.selectedType)    qs.set("type",    this.selectedType);
    if (this.selectedPalette) qs.set("palette", this.selectedPalette);
    const q = qs.toString();
    return `/heatmap/{z}/{x}/{y}.png${q ? "?" + q : ""}`;
  }

  refreshTiles() {
    if (!this.map.isStyleLoaded()) return;
    if (this.map.getLayer("heatmap-layer")) this.map.removeLayer("heatmap-layer");
    if (this.map.getSource("heatmap"))      this.map.removeSource("heatmap");
    this.addHeatmapTiles();
  }

  // ── Map setup ─────────────────────────────────────────────────────────────

  setupMap() {
    const bounds = this.hasBoundsValue && this.boundsValue.length === 4
      ? [[this.boundsValue[0], this.boundsValue[1]], [this.boundsValue[2], this.boundsValue[3]]]
      : null;

    this.map = new maplibregl.Map({
      container: this.mapTarget,
      style: STYLE_URL(this.selectedStyle),
      center: bounds ? undefined : this.getMapCenter(),
      zoom:   bounds ? undefined : this.getMapZoom(),
      bounds: bounds || undefined,
      fitBoundsOptions: { padding: 40 },
      maxZoom: 16,
    });
    this.map.addControl(new maplibregl.FullscreenControl());
    this.map.addControl(new maplibregl.NavigationControl());
  }

  addHeatmapTiles() {
    this.map.addSource("heatmap", {
      type: "raster",
      tiles: [this.tileUrl],
      tileSize: 256,
      minzoom: 0,
      maxzoom: 16,
    });

    this.map.addLayer({
      id: "heatmap-layer",
      type: "raster",
      source: "heatmap",
      paint: {
        "raster-opacity": 0.9,
        "raster-fade-duration": 150,
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

}
