module Track
  class ElevationMetric
    def initialize(points)
      @elevations = points.map(&:elevation).compact
    end

    def gain  = deltas.select(&:positive?).sum.round
    def loss  = deltas.select(&:negative?).sum.abs.round
    def net   = (@elevations.last - @elevations.first).round
    def min   = @elevations.min&.round || 0
    def max   = @elevations.max&.round || 0
    def range = (max - min)

    private

    def deltas
      @deltas ||= @elevations.each_cons(2).map { |a, b| b - a }
    end
  end
end
