module ApplicationHelper
    def format_distance(meters)
        number_to_human(meters, precision: 2, significant: false, units: { unit: "m", thousand: "km" })
    end

    def format_elevation(meters)
        number_to_human(meters, units: { unit: "m" })
    end
end
