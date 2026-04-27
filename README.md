# Banana

![Banana](banana.jpeg)

A self-hosted activity tracker for cyclists and other athletes. Upload GPX or FIT files, visualise your routes on an interactive map, explore a heatmap of all your rides, and organise multi-day trips into tours.

## Features

- **GPX & FIT import** — upload files from any GPS device or Strava export; both formats fully parsed in pure Ruby with no external dependencies
- **Device detection** — recording device extracted automatically from GPX `creator` attribute and FIT `file_id` / `device_info` messages (Garmin, Wahoo, Suunto, Polar, and more)
- **Duplicate detection** — two-phase check: metadata pre-filter (±30 min, ±5% distance) confirmed by `ST_HausdorffDistance` track comparison when geometry is available
- **Interactive maps** — MapLibre GL with multiple basemap styles (Bright, Liberty, Positron, Dark, Fiord), elevation profile with hover tooltip, animated timeline scrubber, 3D terrain, fullscreen mode, and Strava-style outlined track
- **Heatmap** — raster tile heatmap of all activities at any zoom level, filterable by year, month, and activity type; precomputed per activity and stored as compressed pixel bitmaps
- **Tours** — group multi-day activities into tours; pick a date range and matching activities are assigned automatically
- **Calendar** — monthly and yearly activity summaries
- **Filtering & sorting** — search by name, filter by activity type and year, sort by date / distance / elevation / name
- **Export** — GeoJSON, GPX, and static PNG map image per activity
- **Email/password authentication** — standard registration and login

## Tech stack

- **Rails 8** — Hotwire (Turbo + Stimulus), Solid Queue / Cache / Cable, import maps
- **PostgreSQL + PostGIS** — geometry stored as spatial types; segments stored as `LineString` for efficient spatial queries
- **MapLibre GL** — client-side map rendering with [OpenFreeMap](https://openfreemap.org) tiles
- **Active Storage** — file storage with custom `GpxAnalyzer` and `FitAnalyzer`; analysis runs synchronously on upload so metadata is available immediately

## File analysis pipeline

Both GPX and FIT files go through the same pipeline on upload:

1. **Parse** — `GPX::Parser` (Nokogiri XML) or `FIT::Parser` (pure Ruby binary) extracts raw track points
2. **Normalise** — points become `Track::Point` objects with `lat`, `lon`, `elevation`, `time`
3. **Clean** — `Track::Cleaner` splits the track into segments, discarding zero points, time errors, distance jumps > 500 m, and speed outliers
4. **Profile** — `ActivityProfile.for(type)` selects speed thresholds per activity type (cycling, running, walking, or a permissive default)
5. **Analyse** — `Track::ElevationMetric` and `Track::Segment` compute gain/loss, distance, and moving time per segment
6. **Store** — metadata written to the `activities` table; segments stored as PostGIS `LineString` geometries

## Installation

### Self-hosted (Linux, Docker)

See **[INSTALL.md](INSTALL.md)** for the non-technical guide — install Docker, run `./start.sh`, done.

### Developer setup

**Requirements:** Ruby (see `.ruby-version`), PostgreSQL with PostGIS, libvips

```sh
bundle install
rails db:create db:schema:load
rails server
```

Create your account by visiting `/registrations/new`.

## Heatmap tiles

Heatmap tiles are precomputed per activity as compressed pixel bitmaps and stored in the `activity_tiles` table. To rebuild all tiles:

```sh
bin/rails heatmap:rebuild
# or for a single user:
bin/rails "heatmap:rebuild[you@example.com]"
```

To clear all tiles:

```sh
bin/rails heatmap:clear
```

## Optional: static map images

Activity cards and share pages show a static PNG map thumbnail if the `libgd-gis` gem is available. To enable:

```sh
# macOS
brew install libgd
```

Then uncomment in `Gemfile`:

```ruby
gem "libgd-gis"
```

```sh
bundle install
```

Without libgd the app falls back to an inline SVG path preview.

## Deployment

Banana ships with a `config/deploy.yml` for [Kamal](https://kamal-deploy.org). Set `RAILS_MASTER_KEY` in your environment and run:

```sh
kamal setup
kamal deploy
```

## License

MIT
