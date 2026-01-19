import { Controller } from "@hotwired/stimulus";
import maplibregl from "maplibre-gl";

export default class extends Controller {
  static values = {
    url: String,
  };

  connect() {
    const mapStyles = ["liberty", "bright", "positron", "fiord", "dark"];

    this.map = new maplibregl.Map({
      container: this.element,
      center: [52.4, 13.5],
      style: "https://tiles.openfreemap.org/styles/liberty",
      attributionControl: false,
      zoom: 1,
      //interactive: false,
    });

    this.map.on("load", () => this.addRoute());
    this.map.on("sourcedata", (e) => this.fitBounds(e));
  }

  disconnect() {
    this.map.remove();
  }

  addRoute() {
    this.map.addSource("route", {
      type: "geojson",
      data: this.urlValue,
    });

    this.map.addLayer({
      id: "route",
      type: "line",
      source: "route",
      layout: {
        "line-join": "round",
        "line-cap": "round",
      },
      paint: {
        "line-color": "#f35",
        "line-width": 3,
      },
    });
  }

  fitBounds(e) {
    if (e.sourceId === "route" && e.isSourceLoaded) {
      const coords = e.source.data.coordinates;
      if (!coords || coords.length === 0) return;

      // Flatten MultiLineString to a simple array of [lon, lat]
      const flatCoords = coords.flatMap((segment) =>
        segment.map((coord) => [coord[0], coord[1]]),
      );

      const bounds = flatCoords.reduce(
        (acc, coord) => acc.extend(coord),
        new maplibregl.LngLatBounds(flatCoords[0], flatCoords[0]),
      );

      this.map.fitBounds(bounds, {
        padding: { top: 12, bottom: 12, left: 12, right: 12 },
        duration: 0,
      });
    }
  }
}
