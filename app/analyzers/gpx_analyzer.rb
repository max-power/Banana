class GPXAnalyzer < ActiveStorage::Analyzer
  # Only run this analyzer if the file is a GPX
  def self.accept?(blob)
    blob.filename.extension.casecmp?("gpx") || blob.content_type == "application/gpx+xml"
  end

  def metadata
    download_blob_to_tempfile do |file|
      ::GPX::Activity.new(file.read).to_h
    end
  end
end
