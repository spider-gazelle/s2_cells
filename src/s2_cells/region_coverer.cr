class S2Cells::RegionCoverer
  @min_level : Int32
  @max_level : Int32
  @max_cells : Int32

  def initialize(@min_level = 0, @max_level = 30, @max_cells = 8)
  end

  def get_covering(min_lat : Float64, min_lon : Float64, max_lat : Float64, max_lon : Float64) : Array(S2Cells::CellId)
    validate_coordinates(min_lat, min_lon, max_lat, max_lon)

    covering = Set(S2Cells::CellId).new
    cell = S2Cells.at((min_lat + max_lat) / 2, (min_lon + max_lon) / 2).parent(@max_level)

    queue = [cell]
    while !queue.empty? && covering.size < @max_cells
      current = queue.shift
      if intersects_region?(current, min_lat, min_lon, max_lat, max_lon)
        if current.level == @max_level
          covering.add(current)
          puts "Added to covering: #{current.id}, Level: #{current.level}"
        else
          queue.concat(current.children)
        end
      end
    end

    # If we haven't filled the covering, expand outwards
    while covering.size < @max_cells
      neighbors = covering.flat_map { |c| c.get_all_neighbors }.uniq
      neighbors.each do |neighbor|
        break if covering.size >= @max_cells
        if intersects_region?(neighbor, min_lat, min_lon, max_lat, max_lon)
          covering.add(neighbor)
          puts "Added to covering: #{neighbor.id}, Level: #{neighbor.level}"
        end
      end
      break if neighbors.empty?
    end

    covering.to_a
  end

  private def validate_coordinates(min_lat : Float64, min_lon : Float64, max_lat : Float64, max_lon : Float64)
    raise ArgumentError.new("Invalid latitude range") if min_lat > max_lat
    raise ArgumentError.new("Invalid longitude range") if min_lon > max_lon
    raise ArgumentError.new("Latitude out of range") if min_lat < -90 || max_lat > 90
    raise ArgumentError.new("Longitude out of range") if min_lon < -180 || max_lon > 180
  end

  private def intersects_region?(cell : S2Cells::CellId, min_lat : Float64, min_lon : Float64, max_lat : Float64, max_lon : Float64) : Bool
    bounds = cell.bounds
    !(bounds.lat_hi < min_lat || bounds.lat_lo > max_lat ||
      bounds.lon_hi < min_lon || bounds.lon_lo > max_lon)
  end
end
