module GPX
    class ElevationMetric
        attr_reader :profile

        def initialize(points)
          @profile = points.map(&:elevation).compact
        end

        def gain    = deltas.select(&:positive?).sum.round
        def loss    = deltas.select(&:negative?).sum.abs.round
        def net     = (profile.last - profile.first).round
        def min     = profile.min&.round || 0
        def max     = profile.max&.round || 0
        def range   = (max - min)

        private

        def deltas
          @deltas ||= profile.each_cons(2).map { |e1, e2| e2 - e1 }
        end
    end
end
