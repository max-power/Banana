import { Controller } from "@hotwired/stimulus";
import maplibregl from "maplibre-gl";
import StyleFlipperControl from "maplibre-gl-style-flipper";

const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

export default class extends Controller {
  static targets = ["map", "filterBar"];
  static values = {
    bounds: Array,
    center: Array,
    zoom: Number,
    style: String,
    years: Array,
  };

  defaults = {
    center: [13.41, 52.52],
    zoom: 10,
    style: "carto-dark-nolabels",
  };

  mapStyles = {
    "openfreemap-liberty": {
      code: "liberty",
      url: "https://tiles.openfreemap.org/styles/liberty",
    },
    "carto-voyager": {
      code: "carto-voyager",
      url: "https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json",
    },
    "carto-voyager-nolabels": {
      code: "carto-voyager-nolabels",
      url: "https://basemaps.cartocdn.com/gl/voyager-nolabels-gl-style/style.json",
    },
    "carto-positron": {
      code: "carto-positron",
      url: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json",
    },
    "carto-positron-nolabels": {
      code: "carto-positron-nolabels",
      url: "https://basemaps.cartocdn.com/gl/positron-nolabels-gl-style/style.json",
    },
    "carto-dark": {
      code: "carto-dark",
      url: "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json",
    },
    "carto-dark-nolabels": {
      code: "carto-dark-nolabels",
      url: "https://basemaps.cartocdn.com/gl/dark-matter-nolabels-gl-style/style.json",
    },
  };

  connect() {
    this.selectedYear  = null;
    this.selectedMonth = null;
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
      this.selectedYear  = null;
      this.selectedMonth = null;
      this.buildFilterBar();
      this.refreshTiles();
    });
    yearRow.appendChild(allBtn);

    if (this.yearsValue.length > 0) {
      yearRow.appendChild(this.makeDivider());
      this.yearsValue.forEach((year) => {
        const btn = this.makeBtn(year, this.selectedYear === year, () => {
          if (this.selectedYear === year) {
            this.selectedYear  = null;
            this.selectedMonth = null;
          } else {
            this.selectedYear  = year;
            this.selectedMonth = null;
          }
          this.buildFilterBar();
          this.refreshTiles();
        });
        yearRow.appendChild(btn);
      });
    }

    bar.appendChild(yearRow);

    if (this.selectedYear) {
      const monthRow = document.createElement("div");
      monthRow.className = "heatmap-filter-row";
      MONTHS.forEach((label, i) => {
        const monthNum = i + 1;
        const btn = this.makeBtn(label, this.selectedMonth === monthNum, () => {
          this.selectedMonth = this.selectedMonth === monthNum ? null : monthNum;
          this.buildFilterBar();
          this.refreshTiles();
        });
        monthRow.appendChild(btn);
      });
      bar.appendChild(monthRow);
    }
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
    const qs = [];
    if (this.selectedYear)  qs.push(`year=${this.selectedYear}`);
    if (this.selectedMonth) qs.push(`month=${this.selectedMonth}`);
    return `/heatmap/{z}/{x}/{y}.png${qs.length ? "?" + qs.join("&") : ""}`;
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
      style: this.getMapStyle().url,
      center: bounds ? undefined : this.getMapCenter(),
      zoom:   bounds ? undefined : this.getMapZoom(),
      bounds: bounds || undefined,
      fitBoundsOptions: { padding: 40 },
      maxZoom: 16,
    });
    this.map.addControl(new maplibregl.FullscreenControl());
    this.map.addControl(new maplibregl.NavigationControl());

    const styleFlipperControl = new StyleFlipperControl(this.mapStyles);
    styleFlipperControl.setCurrentStyleCode(this.getMapStyle().code);
    this.map.addControl(styleFlipperControl, "bottom-left");
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

  getMapStyle() {
    return this.mapStyles[this.styleValue] || this.mapStyles[this.defaults.style];
  }
}
