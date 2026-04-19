module ApplicationHelper
  include Pagy::NumericHelperLoader

  ACTIVITY_TYPE_COLORS = {
    "cycling"  => "hsl(254 100% 48%)",
    "running"  => "hsl(20 90% 55%)",
    "hiking"   => "hsl(140 50% 42%)",
    "walking"  => "hsl(200 75% 50%)",
    "swimming" => "hsl(185 80% 42%)",
  }.freeze

  def day_bubble_style(type_activities, max_dist)
    dist  = type_activities.sum(&:distance).to_f
    size  = (20 + 28 * Math.sqrt(dist / [ max_dist, 1 ].max)).round
    color = ACTIVITY_TYPE_COLORS.fetch(type_activities.first&.activity_type.to_s, ACTIVITY_TYPE_COLORS["cycling"])
    "width: #{size}px; background: #{color};"
  end

  def max_day_distance(activities)
    activities.group_by { |a| [ a.start_time&.to_date, a.activity_type ] }
              .values
              .map { |acts| acts.sum(&:distance) }
              .max.to_f
  end

  def activity_type_color(type)
    ACTIVITY_TYPE_COLORS.fetch(type.to_s, ACTIVITY_TYPE_COLORS["cycling"])
  end

  def week_range_label(days)
    first, last = days.first, days.last
    if first.month == last.month
      "#{first.strftime('%b')} #{first.day}–#{last.day}"
    else
      "#{first.strftime('%b')} #{first.day} – #{last.strftime('%b')} #{last.day}"
    end
  end
  def format_distance(meters)
    return "—" unless meters
    number_to_human(meters, precision: 2, significant: false, units: { unit: "m", thousand: "km" })
  end

  def format_elevation(meters)
    return "—" unless meters
    number_to_human(meters, units: { unit: "m" })
  end

  def format_duration(seconds)
    return "—" unless seconds
    total = seconds.to_i
    h = total / 3600
    m = (total % 3600) / 60
    s = total % 60
    h > 0 ? "#{h}:%02d:%02d" % [ m, s ] : "%d:%02d" % [ m, s ]
  end

  def format_speed(mps)
    return "—" unless mps&.positive?
    "#{(mps * 3.6).round(1)} km/h"
  end

  def activity_svg_path(geojson_str)
    return nil if geojson_str.blank?

    geojson = JSON.parse(geojson_str)
    lines = case geojson["type"]
            when "LineString"      then [ geojson["coordinates"] ]
            when "MultiLineString" then geojson["coordinates"]
            else return nil
            end

    all_pts = lines.flatten(1)
    xs = all_pts.map { |x, *| x.to_f }
    ys = all_pts.map { |_, y, *| y.to_f }
    xmin, xmax = xs.min, xs.max
    ymin, ymax = ys.min, ys.max
    w = xmax - xmin
    h = ymax - ymin
    return nil if w < 0.00001 || h < 0.00001

    vw, vh, pad = 200.0, 100.0, 8.0
    scale = [ (vw - pad * 2) / w, (vh - pad * 2) / h ].min
    ox = (vw - w * scale) / 2.0
    oy = (vh - h * scale) / 2.0

    lines.map do |pts|
      pts.each_with_index.map do |(x, y, *), i|
        px = (ox + (x.to_f - xmin) * scale).round(1)
        py = (vh - oy - (y.to_f - ymin) * scale).round(1)
        i.zero? ? "M #{px},#{py}" : "L #{px},#{py}"
      end.join(" ")
    end.join(" ")
  end

  def activity_map_png(activity)
    image_tag polymorphic_path(activity, format: :png), loading: "lazy", alt: ""
  end

  def activity_map_svg(activity)
    return unless (d = activity_svg_path(activity.geojson_path))
    content_tag(:svg, viewBox: "0 0 200 100", xmlns: "http://www.w3.org/2000/svg", aria_hidden: true) do
      content_tag(:path, "", d: d, fill: "none", stroke: "currentColor",
                            "stroke-width": "2.5", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end
end
