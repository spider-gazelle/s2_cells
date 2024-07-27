require "math"

module S2Cells
  abstract struct Metric
    def initialize(@deriv : Float64, @dim : Int32)
    end

    def deriv : Float64
      @deriv
    end

    def get_value(level : Int) : Float64
      Math.ldexp(@deriv, -@dim * level)
    end

    def get_closest_level(value : Float64) : Int32
      factor = if @dim == 1
                 Math.sqrt(2.0)
               else
                 2.0
               end
      get_min_level(factor * value)
    end

    def get_min_level(value : Float64) : Int32
      return CellId::MAX_LEVEL if value <= 0

      m, x = Math.frexp(value / @deriv)
      level = {0, {CellId::MAX_LEVEL, -((x - 1) >> (@dim - 1))}.min}.max
      raise "Invalid level" unless level == CellId::MAX_LEVEL || get_value(level) <= value
      raise "Invalid level" unless level == 0 || get_value(level - 1) > value
      level
    end

    def get_max_level(value : Float64) : Int32
      return CellId::MAX_LEVEL if value <= 0

      m, x = Math.frexp(@deriv / value)
      level = {0, {CellId::MAX_LEVEL, (x - 1) >> (@dim - 1)}.min}.max
      raise "Invalid level" unless level == 0 || get_value(level) >= value
      raise "Invalid level" unless level == CellId::MAX_LEVEL || get_value(level + 1) < value
      level
    end

    private def max(a : Int32, b : Int32) : Int32
      a > b ? a : b
    end

    private def min(a : Int32, b : Int32) : Int32
      a < b ? a : b
    end
  end

  struct LengthMetric < Metric
    def initialize(deriv : Float64)
      super(deriv, 1)
    end
  end

  struct AreaMetric < Metric
    def initialize(deriv : Float64)
      super(deriv, 2)
    end
  end

  AVG_ANGLE_SPAN = LengthMetric.new(Math::PI / 2)         # true for all projections
  MIN_ANGLE_SPAN = LengthMetric.new(4.0 / 3.0)            # quadratic projection
  MAX_ANGLE_SPAN = LengthMetric.new(1.704897179199218452) # quadratic projection

  AVG_EDGE = LengthMetric.new(1.459213746386106062)     # quadratic projection
  MIN_EDGE = LengthMetric.new(2 * Math.sqrt(2.0) / 3.0) # quadratic projection
  MAX_EDGE = LengthMetric.new(MAX_ANGLE_SPAN.deriv)     # true for all projections

  AVG_DIAG = LengthMetric.new(2.060422738998471683)     # quadratic projection
  MIN_DIAG = LengthMetric.new(8 * Math.sqrt(2.0) / 9.0) # quadratic projection
  MAX_DIAG = LengthMetric.new(2.438654594434021032)     # quadratic projection

  AVG_WIDTH = LengthMetric.new(1.434523672886099389)     # quadratic projection
  MIN_WIDTH = LengthMetric.new(2 * Math.sqrt(2.0) / 3.0) # quadratic projection
  MAX_WIDTH = LengthMetric.new(MAX_ANGLE_SPAN.deriv)     # true for all projections

  AVG_AREA = AreaMetric.new(4 * Math::PI / 6.0)       # Average cell area for all projections
  MIN_AREA = AreaMetric.new(8 * Math.sqrt(2.0) / 9.0) # Minimum cell area for quadratic projections
  MAX_AREA = AreaMetric.new(2.635799256963161491)     # Maximum cell area for quadratic projections
end
