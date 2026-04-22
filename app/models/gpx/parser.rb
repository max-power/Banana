module GPX
  class Parser
    attr_reader :profile

    def initialize(data, profile: nil)
      @data    = data
      @profile = profile || default_profile
      @cleaner = Track::Cleaner.new(@profile)
    end

    def parsed_document
      @parsed_document ||= Nokogiri::XML(@data).remove_namespaces!
    end

    def activity_name
      parsed_document.at_xpath("//trk/name")&.text
    end

    def activity_type
      parsed_document.at_xpath("//trk/type")&.text
    end

    def device
      parsed_document.at_xpath("//gpx")&.[]("creator")&.strip&.presence
    end

    def raw_points
      @raw_points ||= parsed_document.xpath("//trkpt").map { |node| point_from_xml(node) }
    end

    def segments
      @segments ||= @cleaner.segments(raw_points)
    end

    def clean_points
      @clean_points ||= segments.flat_map(&:points)
    end

    def clean_report
      @cleaner.counter
    end

    private

    def point_from_xml(node)
      lat  = node[:lat].to_f
      lon  = node[:lon].to_f
      ele  = node.at_xpath("ele")&.text.to_f || 0.0
      time = (Time.iso8601(node.at_xpath("time")&.text).to_f rescue nil)
      Track::Point.new(lat: lat, lon: lon, elevation: ele, time: time)
    end

    def default_profile
      ActivityProfile.new(name: "Default", moving_speed_m_s: 0.5, max_speed_m_s: 60.0)
    end
  end
end
