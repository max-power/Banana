module GPX
  class Parser
    attr_reader :profile

    def initialize(data, profile: nil)
      @data = data
      @profile = profile || default_profile
      @cleaner = Cleaner.new(profile)
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

    def raw_points
      @raw_points ||= parsed_document.xpath("//trkpt").map { Point.from_xml(it) }
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

    def default_profile
      ActivityProfile.new(name: "Default",  moving_speed_m_s: 0.5, max_speed_m_s: 60.0)
    end
  end
end
