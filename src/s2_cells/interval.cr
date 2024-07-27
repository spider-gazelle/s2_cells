require "math"

module S2Cells
  abstract struct Interval
    # Initialize with low and high bounds
    def initialize(lo : Float | Int, hi : Float | Int)
      @lo = lo.to_f
      @hi = hi.to_f
    end

    # String representation of the Interval object
    def to_s : String
      "#{self.class.name}: (#{@lo}, #{@hi})"
    end

    # Accessor methods for lo and hi
    getter lo : Float64
    getter hi : Float64

    # Method to get bound by index
    def bound(i : Int) : Float64
      case i
      when 0 then @lo
      when 1 then @hi
      else        raise "Index out of bounds"
      end
    end

    # Method to get both bounds as a tuple
    def bounds : Tuple(Float64, Float64)
      {@lo, @hi}
    end

    # Class method to return an empty Interval
    def self.empty : Interval
      Interval.new(0.0, 0.0)
    end
  end

  struct LineInterval < Interval
    def initialize(lo : Float | Int = 1.0, hi : Float | Int = 0.0)
      super(lo, hi)
    end

    def ==(other : LineInterval) : Bool
      (self.lo == other.lo && self.hi == other.hi) || (self.empty? && other.empty?)
    end

    def hash : UInt64
      {@lo, @hi}.hash
    end

    def self.from_point_pair(a : Float | Int, b : Float | Int) : LineInterval
      if a <= b
        new(a, b)
      else
        new(b, a)
      end
    end

    def contains(other : LineInterval | Float | Int) : Bool
      case other
      when LineInterval
        return true if other.empty?
        other.lo >= self.lo && other.hi <= self.hi
      else
        other = other.to_f
        other >= self.lo && other <= self.hi
      end
    end

    def interior_contains(other : LineInterval | Float | Int) : Bool
      case other
      when LineInterval
        return true if other.empty?
        other.lo > self.lo && other.hi < self.hi
      else
        other = other.to_f
        other > self.lo && other < self.hi
      end
    end

    def intersects(other : LineInterval) : Bool
      if self.lo <= other.lo
        other.lo <= self.hi && other.lo <= other.hi
      else
        self.lo <= other.hi && self.lo <= self.hi
      end
    end

    def interior_intersects(other : LineInterval) : Bool
      other.lo < self.hi && self.lo < other.hi && self.lo < self.hi && other.lo <= other.hi
    end

    def union(other : LineInterval) : LineInterval
      return other if self.empty?
      return self if other.empty?
      LineInterval.new({self.lo, other.lo}.min, {self.hi, other.hi}.max)
    end

    def intersection(other : LineInterval) : LineInterval
      LineInterval.new({self.lo, other.lo}.max, {self.hi, other.hi}.min)
    end

    def expanded(radius : Float | Int) : LineInterval
      raise "Radius must be non-negative" if radius.negative?
      return self if self.empty?
      radius = radius.to_f
      LineInterval.new(self.lo - radius, self.hi + radius)
    end

    def get_center : Float64
      0.5 * (self.lo + self.hi)
    end

    def get_length : Float64
      self.hi - self.lo
    end

    def empty? : Bool
      self.lo > self.hi
    end

    def approx_equals?(other : LineInterval, max_error : Float64 = 1e-15) : Bool
      return other.get_length.to_f <= max_error if self.empty?
      return self.get_length.to_f <= max_error if other.empty?
      (other.lo - self.lo).abs + (other.hi - self.hi).abs <= max_error
    end
  end

  struct SphereInterval < Interval
    def initialize(lo : Float | Int = Math::PI, hi : Float | Int = -Math::PI, args_checked : Bool = false)
      if args_checked
        super(lo, hi)
      else
        clamped_lo, clamped_hi = lo, hi
        if lo == -Math::PI && hi != Math::PI
          clamped_lo = Math::PI
        end
        if hi == -Math::PI && lo != Math::PI
          clamped_hi = Math::PI
        end
        super(clamped_lo, clamped_hi)
      end
      raise "Invalid interval" unless valid?
    end

    def ==(other : SphereInterval) : Bool
      self.lo == other.lo && self.hi == other.hi
    end

    def self.from_point_pair(a : Float64, b : Float64) : SphereInterval
      raise "Value out of bounds" unless a.abs <= Math::PI && b.abs <= Math::PI
      a = Math::PI if a == -Math::PI
      b = Math::PI if b == -Math::PI
      if positive_distance(a, b) <= Math::PI
        new(a, b, args_checked: true)
      else
        new(b, a, args_checked: true)
      end
    end

    def self.positive_distance(a : Float64, b : Float64) : Float64
      d = b - a
      d >= 0 ? d : (b + Math::PI) - (a - Math::PI)
    end

    def self.full : SphereInterval
      new(-Math::PI, Math::PI, args_checked: true)
    end

    def full? : Bool
      (self.hi - self.lo) == 2 * Math::PI
    end

    def valid? : Bool
      self.lo.abs <= Math::PI &&
        self.hi.abs <= Math::PI &&
        !(self.lo == -Math::PI && self.hi != Math::PI) &&
        !(self.hi == -Math::PI && self.lo != Math::PI)
    end

    def inverted? : Bool
      self.lo > self.hi
    end

    def empty? : Bool
      self.lo - self.hi == 2 * Math::PI
    end

    def get_center : Float64
      center = 0.5 * (self.lo + self.hi)
      if !inverted?
        center
      elsif center <= 0
        center + Math::PI
      else
        center - Math::PI
      end
    end

    def get_length : Float64
      length = self.hi - self.lo
      if length >= 0
        length
      else
        length += 2 * Math::PI
        length > 0.0 ? length : -1.0
      end
    end

    def complement : SphereInterval
      self.lo == self.hi ? self.class.full : self.class.new(self.hi, self.lo)
    end

    def approx_equals(other : SphereInterval, max_error = 1e-15) : Bool
      if self.empty?
        other.get_length <= max_error
      elsif other.empty?
        self.get_length <= max_error
      else
        (other.lo - self.lo).modulo(2 * Math::PI).abs + (other.hi - self.hi).modulo(2 * Math::PI).abs <= max_error
      end
    end

    def fast_contains(other : Float64) : Bool
      if self.inverted?
        (other >= self.lo || other <= self.hi) && !self.empty?
      else
        other >= self.lo && other <= self.hi
      end
    end

    def contains(other : SphereInterval | Float64) : Bool
      case other
      when SphereInterval
        if self.inverted?
          if other.inverted?
            other.lo >= self.lo && other.hi <= self.hi
          else
            (other.lo >= self.lo || other.hi <= self.hi) && !self.empty?
          end
        else
          if other.inverted?
            self.full? || other.empty?
          else
            other.lo >= self.lo && other.hi <= self.hi
          end
        end
      else
        raise "Value out of bounds" unless other.abs <= Math::PI
        other = Math::PI if other == -Math::PI
        fast_contains(other)
      end
    end

    def interior_contains(other : SphereInterval | Float64) : Bool
      case other
      when SphereInterval
        if self.inverted?
          if !other.inverted?
            other.lo > self.lo || other.hi < self.hi
          else
            (other.lo > self.lo && other.hi < self.hi) || other.empty?
          end
        else
          if other.inverted?
            self.full? || other.empty?
          else
            (other.lo > self.lo && other.hi < self.hi) || self.full?
          end
        end
      else
        raise "Value out of bounds" unless other.abs <= Math::PI
        other = Math::PI if other == -Math::PI
        if self.inverted?
          other > self.lo || other < self.hi
        else
          (other > self.lo && other < self.hi) || self.full?
        end
      end
    end

    def intersects(other : SphereInterval) : Bool
      return false if self.empty? || other.empty?
      if self.inverted?
        other.inverted? || other.lo <= self.hi || other.hi >= self.lo
      else
        if other.inverted?
          other.lo <= self.hi || other.hi >= self.lo
        else
          other.lo <= self.hi && other.hi >= self.lo
        end
      end
    end

    def interior_intersects(other : SphereInterval) : Bool
      return false if self.empty? || other.empty? || self.lo == self.hi
      if self.inverted?
        other.inverted? || other.lo < self.hi || other.hi > self.lo
      else
        if other.inverted?
          other.lo < self.hi || other.hi > self.lo
        else
          (other.lo < self.hi && other.hi > self.lo) || self.full?
        end
      end
    end

    def union(other : SphereInterval) : SphereInterval
      return self if other.empty?

      if fast_contains(other.lo)
        if fast_contains(other.hi)
          return self.contains(other) ? self : self.class.full
        end
        return self.class.new(self.lo, other.hi, args_checked: true)
      end

      if fast_contains(other.hi)
        return self.class.new(other.lo, self.hi, args_checked: true)
      end

      if self.empty? || other.fast_contains(self.lo)
        return other
      end

      dlo = self.class.positive_distance(other.hi, self.lo)
      dhi = self.class.positive_distance(self.hi, other.lo)
      if dlo < dhi
        self.class.new(other.lo, self.hi, args_checked: true)
      else
        self.class.new(self.lo, other.hi, args_checked: true)
      end
    end

    def intersection(other : SphereInterval) : SphereInterval
      return self.class.empty if other.empty?
      if fast_contains(other.lo)
        if fast_contains(other.hi)
          return other.get_length < self.get_length ? other : self
        end
        return self.class.new(other.lo, self.hi, args_checked: true)
      end

      if fast_contains(other.hi)
        return self.class.new(self.lo, other.hi, args_checked: true)
      end

      if other.fast_contains(self.lo)
        return self
      end
      raise "Intervals do not intersect" unless intersects(other)
      self.class.empty
    end

    def expanded(radius : Float64) : SphereInterval
      raise "Radius must be non-negative" if radius < 0
      return self if self.empty?

      two_pi = 2 * Math::PI
      return self.class.full if (self.get_length + 2 * radius) >= (two_pi - 1e-15)

      lo = (self.lo - radius).remainder two_pi
      hi = (self.hi + radius).remainder two_pi
      lo = Math::PI if lo <= -Math::PI

      self.class.new(lo, hi)
    end

    def get_complement_center : Float64
      if self.lo != self.hi
        return complement.get_center
      else
        self.hi <= 0 ? self.hi + Math::PI : self.hi - Math::PI
      end
    end

    def get_directed_hausdorff_distance(other : SphereInterval) : Float64
      return 0.0 if other.contains(self)
      return Math::PI if other.empty?

      other_complement_center = other.get_complement_center
      if self.contains(other_complement_center)
        return self.class.positive_distance(other.hi, other_complement_center)
      else
        hi_hi = if self.class.new(other.hi, other_complement_center).contains(self.hi)
                  self.class.positive_distance(other.hi, self.hi)
                else
                  0
                end

        lo_lo = if self.class.new(other_complement_center, other.lo).contains(self.lo)
                  self.class.positive_distance(self.lo, other.lo)
                else
                  0
                end

        raise "Invalid distance calculation" if hi_hi <= 0 && lo_lo <= 0
        {hi_hi, lo_lo}.max
      end
    end
  end
end
