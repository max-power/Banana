class FITAnalyzer < ActiveStorage::Analyzer
  def self.accept?(blob)
    blob.filename.extension.casecmp?("fit")
  end

  def metadata
    download_blob_to_tempfile do |file|
      ::FIT::Activity.new(file.read).to_h
    end
  end
end
