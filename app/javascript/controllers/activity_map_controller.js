import { Controller } from "@hotwired/stimulus";
import maplibregl from "maplibre-gl";

const STYLES = ["bright", "liberty", "positron", "dark", "fiord"];
const STYLE_URL = (s) => `https://tiles.openfreemap.org/styles/${s}`;

export default class extends Controller {
  static targets = ["map", "elevation", "playButton", "speedButton", "styleOption", "timeline", "timelineTrack", "timelineFill", "timelineThumb", "timelineLabel"];
  static values  = { url: String, arrowUrl: String };

  connect() {
    this.speedMultiplier = 1;
    const savedStyle = localStorage.getItem("mapStyle") || "bright";

    this.map = new maplibregl.Map({
      container: this.mapTarget,
      center: [0, 0],
      style: STYLE_URL(savedStyle),
      attributionControl: false,
      zoom: 1,
    });

    this.map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), "top-right");
    this.map.addControl(this.tiltControl(), "top-right");
    this.setActiveStyle(savedStyle);

    this.map.on("load", () => {
      this.loadRoute();
      this.addTerrainLayer();
    });
  }

  tiltControl() {
    return {
      onAdd: (map) => {
        const container = document.createElement("div");
        container.className = "maplibregl-ctrl maplibregl-ctrl-group";
        const btn = document.createElement("button");
        btn.type = "button";
        btn.title = "Toggle tilt";
        btn.className = "map-tilt-btn";
        btn.textContent = "3D";
        btn.addEventListener("click", () => {
          map.easeTo({ pitch: map.getPitch() > 10 ? 0 : 60, duration: 500 });
        });
        container.appendChild(btn);
        return container;
      },
      onRemove: () => {},
    };
  }

  disconnect() {
    if (this.animFrameId) cancelAnimationFrame(this.animFrameId);
    this.map.remove();
  }

  // ── Style switching ───────────────────────────────────────────────────────

  changeStyle({ params: { style } }) {
    localStorage.setItem("mapStyle", style);
    this.setActiveStyle(style);
    if (this.playing) this.pause();
    this.map.setStyle(STYLE_URL(style));
    this.map.once("style.load", () => {
      this.addTerrainLayer();
      this.applyRouteLayers();
    });
  }

  setActiveStyle(style) {
    this.styleOptionTargets.forEach((btn) =>
      btn.classList.toggle("active", btn.dataset.activityMapStyleParam === style)
    );
  }

  // ── Route loading ─────────────────────────────────────────────────────────

  async loadRoute() {
    const response = await fetch(this.urlValue);
    this.routeFeature = await response.json();
    const geometry = this.routeFeature?.geometry;
    if (!geometry) return;

    this.animCoords   = this.flattenCoords(geometry);
    this.animProgress = 0;
    this.playing      = false;

    // Pre-calculate cumulative distances so animation speed is constant in
    // geographic terms rather than per-coordinate (which distorts at slow/
    // stopped sections where GPS points are densely packed).
    this.animDistances = [0];
    for (let i = 1; i < this.animCoords.length; i++) {
      this.animDistances.push(
        this.animDistances[i - 1] + this.haversine(this.animCoords[i - 1], this.animCoords[i])
      );
    }
    this.animTotalDist = this.animDistances.at(-1) || 1;

    // ~1 ms per metre (1 s per km), clamped to 10 – 90 s
    this.animDuration = Math.max(10000, Math.min(this.animTotalDist, 90000));

    if (this.hasPlayButtonTarget) this.playButtonTarget.disabled = false;

    this.applyRouteLayers();
    this.fitBoundsToGeometry(geometry);
    this.addStartEndMarkers(this.routeFeature.properties);
    this.renderElevationProfile(this.animCoords);

    // Terrain tiles load asynchronously — once they arrive, MapLibre adjusts
    // the 3D projection, which shifts the effective camera on mountainous routes
    // (wider-looking line, offset markers). Re-fitting after idle corrects this.
    // Markers auto-reposition because they listen to the resulting move event.
    this.map.once("idle", () => this.fitBoundsToGeometry(geometry));
  }

  applyRouteLayers() {
    const geometry = this.routeFeature?.geometry;
    if (!geometry) return;

    this.map.addSource("route", { type: "geojson", data: geometry });
    this.map.addLayer({
      id: "route", type: "line", source: "route",
      layout: { "line-join": "round", "line-cap": "round" },
      paint:  { "line-color": "#f35", "line-width": 3 },
    });

    this.map.addSource("route-progress", {
      type: "geojson",
      data: { type: "LineString", coordinates: [] },
    });
    this.map.addLayer({
      id: "route-progress", type: "line", source: "route-progress",
      layout: { "line-join": "round", "line-cap": "round" },
      paint:  { "line-color": "#f35", "line-width": 5 },
    });

    this.addRouteLayerArrows();
    this.addHoverMarker();

    // Restore animation state if mid-playback was interrupted by style change
    if (this.animProgress > 0) this.showRouteProgress(this.animProgress);
  }

  flattenCoords(geometry) {
    if (geometry.type === "LineString")      return geometry.coordinates;
    if (geometry.type === "MultiLineString") return geometry.coordinates.flat();
    return [];
  }

  fitBoundsToGeometry(geometry) {
    const bounds = new maplibregl.LngLatBounds();
    const extend = (c) => bounds.extend(c);
    if (geometry.type === "LineString")           geometry.coordinates.forEach(extend);
    else if (geometry.type === "MultiLineString") geometry.coordinates.forEach((l) => l.forEach(extend));
    if (bounds.isEmpty()) return;

    this.map.resize(); // ensure container dimensions are current
    const camera = this.map.cameraForBounds(bounds, { padding: 60 });
    if (camera) this.map.jumpTo({ center: camera.center, zoom: camera.zoom, pitch: 0, bearing: 0 });
  }

  addStartEndMarkers({ start, end, waypoints } = {}) {
    if (waypoints?.length) {
      waypoints.forEach(({ start, end }, i) => {
        const n = i + 1;
        if (start) this.createWaypointMarker(start, n, "start");
        if (end)   this.createWaypointMarker(end,   n, "end");
      });
    } else {
      if (start) this.createMarker(start, "icon-activity-start");
      if (end)   this.createMarker(end,   "icon-activity-end");
    }
  }

  createMarker(coord, iconClass) {
    const el = document.createElement("div");
    el.className = iconClass;
    new maplibregl.Marker({ element: el }).setLngLat(coord).addTo(this.map);
  }

  createWaypointMarker(coord, number, type) {
    const el = document.createElement("div");
    el.className = `icon-tour-waypoint icon-tour-waypoint--${type}`;
    el.textContent = number;
    new maplibregl.Marker({ element: el }).setLngLat(coord).addTo(this.map);
  }

  addRouteLayerArrows() {
    const img = new Image(32, 32);
    img.src = this.arrowUrlValue;
    img.onload = () => {
      if (this.map.hasImage("direction-arrow")) this.map.removeImage("direction-arrow");
      this.map.addImage("direction-arrow", img, { sdf: true });
      this.map.addLayer({
        id: "route-layer-arrows", type: "symbol", source: "route",
        layout: {
          "symbol-placement": "line", "symbol-spacing": 20,
          "icon-allow-overlap": true, "icon-image": "direction-arrow", "icon-size": 0.2,
        },
        paint: { "icon-color": "#ffffff" },
        minzoom: 6,
      });
    };
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  togglePlay() {
    this.playing ? this.pause() : this.play();
  }

  play() {
    if (!this.animCoords?.length) return;
    if (this.animProgress >= 1) this.animProgress = 0;

    this.playing = true;
    this.playButtonTarget.textContent = "⏸";
    this.map.setPaintProperty("route", "line-opacity", 0.2);
    if (this.hasTimelineTarget) this.timelineTarget.classList.add("visible");

    this.animStartTime = null;
    this.animFrameId = requestAnimationFrame((t) => this.animateFrame(t));
  }

  pause() {
    this.playing = false;
    this.playButtonTarget.textContent = "▶";
    if (this.animFrameId) { cancelAnimationFrame(this.animFrameId); this.animFrameId = null; }
  }

  cycleSpeed() {
    const steps = [1, 2, 3, 5, 10];
    const next  = steps[(steps.indexOf(this.speedMultiplier) + 1) % steps.length];
    this.speedMultiplier = next;
    this.animStartTime   = null; // recalculate from current progress at new speed
    if (this.hasSpeedButtonTarget)
      this.speedButtonTarget.textContent = `${next}×`;
  }

  animateFrame(timestamp) {
    const effectiveDuration = this.animDuration / this.speedMultiplier;
    if (!this.animStartTime)
      this.animStartTime = timestamp - this.animProgress * effectiveDuration;

    const progress = Math.min(1, (timestamp - this.animStartTime) / effectiveDuration);
    this.animProgress = progress;
    this.showRouteProgress(progress);

    if (progress < 1) {
      this.animFrameId = requestAnimationFrame((t) => this.animateFrame(t));
    } else {
      this.playing = false;
      this.playButtonTarget.textContent = "▶";
      this.map.setPaintProperty("route", "line-opacity", 1);
    }
  }

  showRouteProgress(progress) {
    // Binary search: find the coordinate index at the target distance
    const targetDist = progress * this.animTotalDist;
    const dists = this.animDistances;
    let lo = 0, hi = dists.length - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (dists[mid] <= targetDist) lo = mid; else hi = mid - 1;
    }
    const sliced = this.animCoords.slice(0, lo + 1);
    if (sliced.length < 2) return;

    this.map.getSource("route-progress").setData({ type: "LineString", coordinates: sliced });
    this.map.getSource("hover-point").setData({
      type: "Feature",
      geometry: { type: "Point", coordinates: sliced[sliced.length - 1] },
      properties: {},
    });
    this.updateTimeline(progress);
  }

  updateTimeline(progress) {
    if (!this.hasTimelineFillTarget) return;
    const pct = `${(progress * 100).toFixed(2)}%`;
    this.timelineFillTarget.style.width = pct;
    this.timelineThumbTarget.style.left = pct;
    if (this.totalDist) {
      this.timelineLabelTarget.textContent =
        `${this.fmtDist(progress * this.totalDist)} / ${this.fmtDist(this.totalDist)}`;
    }
  }

  // ── Timeline seeking ──────────────────────────────────────────────────────

  seekStart(e) {
    this.seekWasPlaying = this.playing;
    if (this.playing) this.pause();
    this.seekTo(e);
    this._onSeekMove = (e) => this.seekTo(e);
    this._onSeekEnd  = ()  => this.seekEnd();
    document.addEventListener("mousemove", this._onSeekMove);
    document.addEventListener("mouseup",   this._onSeekEnd);
  }

  seekTo(e) {
    const rect     = this.timelineTrackTarget.getBoundingClientRect();
    const progress = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    this.animProgress = progress;
    this.showRouteProgress(progress);
  }

  seekEnd() {
    document.removeEventListener("mousemove", this._onSeekMove);
    document.removeEventListener("mouseup",   this._onSeekEnd);
    if (this.seekWasPlaying) this.play();
  }

  // ── Elevation profile ─────────────────────────────────────────────────────

  renderElevationProfile(coords) {
    if (!this.hasElevationTarget) return;
    if (!coords.some((c) => c[2] != null)) return;

    const raw = [];
    let dist = 0;
    for (let i = 0; i < coords.length; i++) {
      if (i > 0) dist += this.haversine(coords[i - 1], coords[i]);
      if (coords[i][2] != null)
        raw.push({ dist, ele: coords[i][2], lng: coords[i][0], lat: coords[i][1] });
    }
    if (raw.length < 2) return;

    this.profilePoints = raw.map((p, i) => {
      const slice = raw.slice(Math.max(0, i - 3), Math.min(raw.length, i + 4));
      return { ...p, ele: slice.reduce((s, q) => s + q.ele, 0) / slice.length };
    });
    this.totalDist = this.profilePoints.at(-1).dist;

    const eles = this.profilePoints.map((p) => p.ele);
    const minE = Math.min(...eles), maxE = Math.max(...eles);
    const range = maxE - minE || 1;

    const W = 1000, H = 120, pt = 24, pb = 6, pl = 4, pr = 4;
    this.sp = { W, H, pt, pb, pl, pr, minE, maxE, range };

    const sx = (d) => pl + (d / this.totalDist) * (W - pl - pr);
    const sy = (e) => H - pb - ((e - minE) / range) * (H - pt - pb);

    const linePts = this.profilePoints.map((p) => `${sx(p.dist).toFixed(1)},${sy(p.ele).toFixed(1)}`).join(" L ");
    const area    = `M ${sx(0)},${H - pb} L ${linePts} L ${sx(this.totalDist)},${H - pb} Z`;

    const peakIdx = eles.indexOf(maxE);
    const peakX = sx(this.profilePoints[peakIdx].dist).toFixed(1);
    const peakY = sy(maxE).toFixed(1);

    this.elevationTarget.innerHTML = `
      <svg viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="none">
        <defs>
          <linearGradient id="ele-fill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%"   stop-color="currentColor" stop-opacity="0.25"/>
            <stop offset="100%" stop-color="currentColor" stop-opacity="0.04"/>
          </linearGradient>
        </defs>
        <path d="${area}" fill="url(#ele-fill)"/>
        <path d="M ${linePts}" fill="none" stroke="currentColor" stroke-width="2.5"
              stroke-linejoin="round" stroke-linecap="round"/>
        <line id="ele-cursor" x1="0" y1="${pt}" x2="0" y2="${H - pb}"
              stroke="currentColor" stroke-width="1.5" stroke-dasharray="3,3" opacity="0"/>
        <circle id="ele-dot" cx="0" cy="0" r="5"
                fill="white" stroke="currentColor" stroke-width="2.5" opacity="0"/>
        <text x="4" y="${sy(minE) - 4}" font-size="18" fill="currentColor" opacity="0.4">${Math.round(minE)} m</text>
        <text x="${peakX}" y="${Number(peakY) - 6}" font-size="18" fill="currentColor" opacity="0.4"
              text-anchor="middle">${Math.round(maxE)} m</text>
        <text x="${W - pr}" y="${H - pb - 4}" font-size="18" fill="currentColor" opacity="0.4"
              text-anchor="end">${this.fmtDist(this.totalDist)}</text>
      </svg>`.trim();

    this.eleCursor  = this.elevationTarget.querySelector("#ele-cursor");
    this.eleDot     = this.elevationTarget.querySelector("#ele-dot");
    this.eleTooltip = Object.assign(document.createElement("div"), { className: "elevation-tooltip" });
    this.elevationTarget.appendChild(this.eleTooltip);

    this.setupElevationInteraction();
  }

  setupElevationInteraction() {
    const fig = this.elevationTarget;

    fig.addEventListener("mousemove", (e) => {
      const rect  = fig.getBoundingClientRect();
      const xFrac = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
      const point = this.interpolateAtDist(xFrac * this.totalDist);

      this.updateCursor(xFrac, point);
      this.updateTooltip(point, e.clientX - rect.left, rect.width);
      this.map.getSource("hover-point").setData({
        type: "Feature",
        geometry: { type: "Point", coordinates: [point.lng, point.lat] },
        properties: {},
      });
    });

    fig.addEventListener("mouseleave", () => {
      this.eleCursor.setAttribute("opacity", "0");
      this.eleDot.setAttribute("opacity", "0");
      this.eleTooltip.hidden = true;
      this.map.getSource("hover-point").setData({ type: "Feature", geometry: null, properties: {} });
    });
  }

  updateCursor(xFrac, point) {
    const { W, H, pt, pb, pl, pr, minE, range } = this.sp;
    const svgX = (pl + xFrac * (W - pl - pr)).toFixed(1);
    const svgY = (H - pb - ((point.ele - minE) / range) * (H - pt - pb)).toFixed(1);

    this.eleCursor.setAttribute("x1", svgX);
    this.eleCursor.setAttribute("x2", svgX);
    this.eleCursor.setAttribute("opacity", "1");
    this.eleDot.setAttribute("cx", svgX);
    this.eleDot.setAttribute("cy", svgY);
    this.eleDot.setAttribute("opacity", "1");
  }

  updateTooltip(point, mouseX, figureWidth) {
    this.eleTooltip.textContent = `${Math.round(point.ele)} m · ${this.fmtDist(point.dist)}`;
    this.eleTooltip.hidden = false;
    if (mouseX > figureWidth * 0.6) {
      this.eleTooltip.style.left  = "auto";
      this.eleTooltip.style.right = `${figureWidth - mouseX + 10}px`;
    } else {
      this.eleTooltip.style.left  = `${mouseX + 10}px`;
      this.eleTooltip.style.right = "auto";
    }
  }

  interpolateAtDist(targetDist) {
    const pts = this.profilePoints;
    let lo = 0, hi = pts.length - 1;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      if (pts[mid].dist < targetDist) lo = mid + 1; else hi = mid;
    }
    if (lo === 0) return pts[0];
    const a = pts[lo - 1], b = pts[lo];
    const t = (targetDist - a.dist) / (b.dist - a.dist);
    return {
      dist: targetDist,
      ele:  a.ele + t * (b.ele - a.ele),
      lng:  a.lng + t * (b.lng - a.lng),
      lat:  a.lat + t * (b.lat - a.lat),
    };
  }

  // ── Map hover marker ──────────────────────────────────────────────────────

  addHoverMarker() {
    this.map.addSource("hover-point", {
      type: "geojson",
      data: { type: "Feature", geometry: null, properties: {} },
    });
    this.map.addLayer({
      id: "hover-point", type: "circle", source: "hover-point",
      paint: {
        "circle-radius": 7,
        "circle-color": "#ffffff",
        "circle-stroke-color": "#f35",
        "circle-stroke-width": 3,
      },
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  haversine(c1, c2) {
    const R  = 6371000;
    const φ1 = (c1[1] * Math.PI) / 180, φ2 = (c2[1] * Math.PI) / 180;
    const Δφ = ((c2[1] - c1[1]) * Math.PI) / 180;
    const Δλ = ((c2[0] - c1[0]) * Math.PI) / 180;
    const a  = Math.sin(Δφ / 2) ** 2 + Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  fmtDist(m) {
    return m >= 1000 ? `${(m / 1000).toFixed(1)} km` : `${Math.round(m)} m`;
  }

  // ── Terrain ───────────────────────────────────────────────────────────────

  addTerrainLayer() {
    const tiles = ["https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"];
    this.map.addSource("hillshade_source", { type: "raster-dem", encoding: "terrarium", tiles, tileSize: 256, minzoom: 0, maxzoom: 14 });
    this.map.addSource("terrain_source",   { type: "raster-dem", encoding: "terrarium", tiles, tileSize: 256, minzoom: 0, maxzoom: 14 });
    this.map.setTerrain({ source: "terrain_source", exaggeration: 1.5 });
    this.map.addLayer({ id: "hillshade", type: "hillshade", source: "hillshade_source", paint: { "hillshade-exaggeration": 0.2 } });
  }
}
