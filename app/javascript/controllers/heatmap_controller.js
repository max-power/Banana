import { Controller } from "@hotwired/stimulus";
import maplibregl from "maplibre-gl";

const STYLES = ["bright", "liberty", "positron", "dark", "fiord", "black", "white"];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

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

  styleThumbs = [
    { id: "bright",   label: "Bright",   bg: "#f0ece4", road1: "#d4a96a", road2: "#c8a070", water: "#a8d4e6", wx: 0,  wy: 24, ww: 18, wh: 12 },
    { id: "liberty",  label: "Liberty",  bg: "#f5ede3", road1: "#c8755a", road2: "#c8755a", water: "#b8d4a0", wx: 32, wy: 0,  ww: 20, wh: 14 },
    { id: "positron", label: "Positron", bg: "#f4f4f0", road1: "#b0b0b0", road2: "#b8b8b8", water: "#ccdce8", wx: 34, wy: 22, ww: 18, wh: 14 },
    { id: "dark",     label: "Dark",     bg: "#1a1a2e", road1: "#4a4a7a", road2: "#3a3a6a", water: "#0d2035", wx: 0,  wy: 24, ww: 20, wh: 12 },
    { id: "fiord",    label: "Fiord",    bg: "#253448", road1: "#3d5570", road2: "#344d65", water: "#1a2535", wx: 30, wy: 18, ww: 22, wh: 18 },
    { id: "black",    label: "Black",    bg: "#000000" },
    { id: "white",    label: "White",    bg: "#ffffff" },
  ];

  palettes = [
    { id: "purple", label: "Purple", stops: ["#5500f5", "#5500f5", "#ffffff"] },
    { id: "hot",    label: "Hot",    stops: ["#3f5efb", "#fc466b", "#ffffff"] },
    { id: "orange", label: "Orange", stops: ["#fc4a1a", "#f7b733", "#ffffff"] },
    { id: "red",    label: "Red",    stops: ["#b20a2c", "#fffbd5", "#ffffff"] },
    { id: "pink",   label: "Pink",   stops: ["#ffb1ff", "#ffb1ff", "#ffffff"] },
    { id: "cyber",  label: "Cyber",  stops: ["#00ff41", "#b4ff00", "#ffffff"] },
    { id: "ocean",  label: "Ocean",  stops: ["#03045e", "#0096c7", "#ffffff"] },
  ];

  connect() {
    this.selectedYear    = null;
    this.selectedMonth   = null;
    this.selectedType    = null;
    this.selectedPalette = localStorage.getItem("heatmap_palette") || "purple";
    this.selectedStyle   = localStorage.getItem("heatmap_style") || this.defaults.style;
    this.panelOpen       = true;
    this.buildFilterBar();
    this.setupMap();
    this.map.once("load", () => this.addHeatmapTiles());
  }

  // ── Filter UI ─────────────────────────────────────────────────────────────

  buildFilterBar() {
    const bar = this.filterBarTarget;
    bar.innerHTML = "";
    bar.classList.toggle("is-open", this.panelOpen);

    // Toggle button — always visible
    const toggleBtn = document.createElement("button");
    toggleBtn.type = "button";
    toggleBtn.className = "heatmap-panel-toggle";
    toggleBtn.title = "Filters";
    toggleBtn.textContent = "☰";
    toggleBtn.addEventListener("click", () => {
      this.panelOpen = !this.panelOpen;
      bar.classList.toggle("is-open", this.panelOpen);
    });
    bar.appendChild(toggleBtn);

    // Panel body
    const body = document.createElement("div");
    body.className = "heatmap-panel-body";

    body.appendChild(this.buildSection("Year", this.buildYearOptions()));

    if (this.typesValue.length > 1) {
      body.appendChild(this.buildSection("Type", this.buildTypeOptions()));
    }

    body.appendChild(this.buildSection("Palette", this.buildPaletteOptions()));
    body.appendChild(this.buildSection("Style", this.buildStyleOptions()));

    bar.appendChild(body);
  }

  buildSection(label, content) {
    const section = document.createElement("div");
    section.className = "heatmap-panel-section";
    const h = document.createElement("p");
    h.className = "heatmap-panel-label";
    h.textContent = label;
    section.appendChild(h);
    section.appendChild(content);
    return section;
  }

  buildYearOptions() {
    const wrap = document.createElement("div");

    wrap.appendChild(this.makeBtn("All", !this.selectedYear, () => {
      this.selectedYear  = null;
      this.selectedMonth = null;
      this.buildFilterBar();
      this.refreshTiles();
    }));

    this.yearsValue.forEach((year) => {
      wrap.appendChild(this.makeBtn(String(year), this.selectedYear === year, () => {
        this.selectedYear  = this.selectedYear === year ? null : year;
        this.selectedMonth = null;
        this.buildFilterBar();
        this.refreshTiles();
      }));

      // Month grid expands inline below the selected year
      if (this.selectedYear === year) {
        const grid = document.createElement("div");
        grid.className = "heatmap-month-grid";
        MONTHS.forEach((name, i) => {
          const month = i + 1;
          const btn = this.makeBtn(name, this.selectedMonth === month, () => {
            this.selectedMonth = this.selectedMonth === month ? null : month;
            this.buildFilterBar();
            this.refreshTiles();
          });
          btn.classList.add("heatmap-filter-btn--month");
          grid.appendChild(btn);
        });
        wrap.appendChild(grid);
      }
    });

    return wrap;
  }

  buildTypeOptions() {
    const wrap = document.createElement("div");

    wrap.appendChild(this.makeBtn("All", !this.selectedType, () => {
      this.selectedType = null;
      this.buildFilterBar();
      this.refreshTiles();
    }));

    this.typesValue.forEach((type) => {
      wrap.appendChild(this.makeBtn(type.replace(/_/g, " "), this.selectedType === type, () => {
        this.selectedType = this.selectedType === type ? null : type;
        this.buildFilterBar();
        this.refreshTiles();
      }));
    });

    return wrap;
  }

  buildPaletteOptions() {
    const wrap = document.createElement("div");
    wrap.className = "heatmap-palette-row";

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
      wrap.appendChild(btn);
    });

    return wrap;
  }

  buildStyleOptions() {
    const wrap = document.createElement("div");
    wrap.className = "heatmap-palette-row";

    this.styleThumbs.forEach(({ id, label, bg, road1, road2, water, wx, wy, ww, wh }) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.title = label;
      btn.className = "heatmap-style-btn" + (this.selectedStyle === id ? " active" : "");
      btn.innerHTML = road1 ? `
        <svg viewBox="0 0 52 36" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice">
          <rect width="52" height="36" fill="${bg}"/>
          <rect x="${wx}" y="${wy}" width="${ww}" height="${wh}" fill="${water}" opacity="0.7"/>
          <path d="M0 18 L52 18" stroke="${road1}" stroke-width="3"/>
          <path d="M22 0 L22 36" stroke="${road2}" stroke-width="2"/>
        </svg>` : `
        <svg viewBox="0 0 52 36" xmlns="http://www.w3.org/2000/svg">
          <rect width="52" height="36" fill="${bg}"/>
        </svg>`;
      btn.addEventListener("click", () => {
        this.selectedStyle = id;
        localStorage.setItem("heatmap_style", id);
        this.buildFilterBar();
        this.map.setStyle(STYLE_URL(id));
        this.map.once("style.load", () => this.addHeatmapTiles());
      });
      wrap.appendChild(btn);
    });

    return wrap;
  }

  makeBtn(label, active, onClick) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.textContent = label;
    btn.className = "heatmap-filter-btn" + (active ? " active" : "");
    btn.addEventListener("click", onClick);
    return btn;
  }

  // ── Tile URL ──────────────────────────────────────────────────────────────

  get tileUrl() {
    const qs = new URLSearchParams();
    if (this.selectedYear)    qs.set("year",    this.selectedYear);
    if (this.selectedMonth)   qs.set("month",   this.selectedMonth);
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
