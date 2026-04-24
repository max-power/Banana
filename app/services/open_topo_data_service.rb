require "net/http"
require "json"

# Client for the Open-Topo-Data elevation API.
# Public instance: https://www.opentopodata.org — 100 points/request, 1 req/s.
# Self-hosted: set OPEN_TOPO_DATA_URL env var, e.g. http://localhost:5000/v1/srtm30m
class OpenTopoDataService
  BATCH_SIZE = 100
  DEFAULT_URL = "https://api.opentopodata.org/v1/srtm30m"

  class Error < StandardError; end

  def self.url
    ENV.fetch("OPEN_TOPO_DATA_URL", DEFAULT_URL)
  end

  # points: array of [lon, lat] pairs (WGS-84)
  # Returns array of elevations (Float or nil) in the same order.
  def self.elevations_for(points)
    results = []

    points.each_slice(BATCH_SIZE).each do |batch|
      sleep(1.1)  # public API rate limit: 1 req/s, add a small buffer

      # Use pipe-separated "lat,lon|lat,lon" string — the documented example format
      locations_str = batch.map { |lon, lat| "#{lat},#{lon}" }.join("|")

      uri     = URI(url)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"]       = "application/json"
      request.body = JSON.generate({ locations: locations_str })

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Open-Topo-Data returned #{response.code}: #{response.body.truncate(200)}"
      end

      data = JSON.parse(response.body)
      results.concat(data["results"].map { |r| r["elevation"]&.to_f })
    end

    results
  end
end
