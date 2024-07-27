struct S2Cells::CellUnion
  getter cell_ids : Array(CellId)

  def initialize(cell_ids : Array(CellId)? = nil, raw : Bool = true)
    if cell_ids.nil?
      @cell_ids = [] of CellId
    else
      @cell_ids = cell_ids.map do |cell_id|
        cell_id.is_a?(CellId) ? cell_id : CellId.new(cell_id)
      end
      normalize if raw
    end
  end

  def ==(other : CellUnion) : Bool
    other.is_a?(CellUnion) && @cell_ids == other.cell_ids
  end

  def hash : UInt64
    @cell_ids.hash
  end

  def to_s : String
    "#{self.class.name}: #{@cell_ids}"
  end

  def self.get_union(x : CellUnion, y : CellUnion) : CellUnion
    new(x.cell_ids + y.cell_ids)
  end

  def self.get_intersection(cell_union : CellUnion, cell_id : CellId) : CellUnion
    if cell_union.contains(cell_id)
      new([cell_id])
    else
      index = cell_union.cell_ids.bsearch_index { |id| id >= cell_id.range_min } || 0
      idmax = cell_id.range_max
      intersected_cell_ids = [] of CellId
      while index < cell_union.cell_ids.size && cell_union.cell_ids[index] <= idmax
        intersected_cell_ids << cell_union.cell_ids[index]
        index += 1
      end
      new(intersected_cell_ids)
    end
  end

  def self.get_intersection(x : CellUnion, y : CellUnion) : CellUnion
    i, j = 0, 0
    cell_ids = [] of CellId
    while i < x.num_cells && j < y.num_cells
      imin = x.cell_ids[i].range_min
      jmin = y.cell_ids[j].range_min
      if imin > jmin
        if x.cell_ids[i] <= y.cell_ids[j].range_max
          cell_ids << x.cell_ids[i]
          i += 1
        else
          j = y.cell_ids.bsearch_index { |id| id >= imin } || (j + 1)
          j -= 1 if j > 0 && x.cell_ids[i] <= y.cell_ids[j].range_max
        end
      elsif jmin > imin
        if y.cell_ids[j] <= x.cell_ids[i].range_max
          cell_ids << y.cell_ids[j]
          j += 1
        else
          i = x.cell_ids.bsearch_index { |id| id >= jmin } || (i + 1)
          i -= 1 if i > 0 && y.cell_ids[j] <= x.cell_ids[i].range_max
        end
      else
        if x.cell_ids[i] < y.cell_ids[j]
          cell_ids << x.cell_ids[i]
          i += 1
        else
          cell_ids << y.cell_ids[j]
          j += 1
        end
      end
    end

    cell_union = new(cell_ids)
    cell_union.normalize
    cell_union
  end

  def expand(level : Int32)
    output = [] of CellId
    level_lsb = CellId.lsb_for_level(level)
    i = num_cells - 1
    while i >= 0
      cell_id = @cell_ids[i]
      if cell_id.lsb < level_lsb
        cell_id = cell_id.parent(level)
        while i > 0 && cell_id.contains(@cell_ids[i - 1])
          i -= 1
        end
      end
      output << cell_id
      cell_id.append_all_neighbors(level, output)
      i -= 1
    end
    @cell_ids = output
  end

  def expand(min_radius : Angle, max_level_diff : Int32)
    min_level = CellId::MAX_LEVEL
    @cell_ids.each do |cell_id|
      min_level = {min_level, cell_id.level}.min
    end

    radius_level = CellId.min_width.get_max_level(min_radius.radians)
    if radius_level == 0 && min_radius.radians > CellId.min_width.get_value(0)
      expand(0)
    end
    expand({min_level + max_level_diff, radius_level}.min)
  end

  def self.get_difference(x : CellUnion, y : CellUnion) : CellUnion
    cell_ids = [] of CellId
    x.cell_ids.each do |cell_id|
      __get_difference(cell_id, y, cell_ids)
    end

    cell_union = new(cell_ids)
    cell_union.normalize
    cell_union
  end

  private def self.__get_difference(cell_id : CellId, y : CellUnion, cell_ids : Array(CellId))
    if !y.intersects(cell_id)
      cell_ids << cell_id
    elsif !y.contains(cell_id)
      cell_id.children.each do |child|
        __get_difference(child, y, cell_ids)
      end
    end
  end

  def num_cells : Int32
    @cell_ids.size
  end

  def cell_id(i : Int32) : CellId
    @cell_ids[i]
  end

  def normalize
    @cell_ids.sort!
    output = [] of CellId
    @cell_ids.each do |cell_id|
      next if output.any? && output.last.contains(cell_id)

      while output.any? && cell_id.contains(output.last)
        output.pop
      end

      while output.size >= 3
        if (output[-3].id ^ output[-2].id ^ output[-1].id) != cell_id.id
          break
        end

        mask = cell_id.lsb << 1
        mask = ~(mask + (mask << 1))
        id_masked = (cell_id.id & mask)
        if (output[-3].id & mask) != id_masked || (output[-2].id & mask) != id_masked || (output[-1].id & mask) != id_masked || cell_id.face?
          break
        end

        output.pop
        output.pop
        output.pop
        cell_id = cell_id.parent
      end

      output << cell_id
    end

    if output.size < num_cells
      @cell_ids = output
      return true
    end
    false
  end

  def denormalize(min_level : Int32, level_mod : Int32) : Array(CellId)
    raise "Invalid min_level" unless min_level >= 0 && min_level <= CellId::MAX_LEVEL
    raise "Invalid level_mod" unless level_mod >= 1 && level_mod <= 3

    cell_ids = [] of CellId
    @cell_ids.each do |cell_id|
      level = cell_id.level
      new_level = [min_level, level].max
      if level_mod > 1
        new_level += ((CellId::MAX_LEVEL - (new_level - min_level)) % level_mod)
        new_level = [CellId::MAX_LEVEL, new_level].min
      end
      if new_level == level
        cell_ids << cell_id
      else
        cell_id.children(new_level).each do |child|
          cell_ids << child
        end
      end
    end
    cell_ids
  end

  def contains(other : CellUnion | CellId | Cell | Point) : Bool
    case other
    in Cell
      contains(other.id)
    in CellId
      cell_id = other
      index = @cell_ids.bsearch_index { |id| id >= cell_id } || 0
      if index < @cell_ids.size && @cell_ids[index].range_min <= cell_id
        return true
      end
      index != 0 && @cell_ids[index - 1].range_max >= cell_id
    in Point
      contains(CellId.from_point(other))
    in CellUnion
      other.cell_ids.each do |cell_id|
        return false unless contains(cell_id)
      end
      true
    end
  end

  def intersects(other : CellUnion | CellId) : Bool
    case other
    in CellId
      cell_id = other
      index = @cell_ids.bsearch_index { |id| id >= cell_id } || 0
      if index != @cell_ids.size && @cell_ids[index].range_min <= cell_id.range_max
        return true
      end
      index != 0 && @cell_ids[index - 1].range_max >= cell_id.range_min
    in CellUnion
      other.cell_ids.each do |cell_id|
        return true if intersects(cell_id)
      end
      false
    end
  end

  def get_rect_bound : LatLngRect
    bound = LatLngRect.empty
    @cell_ids.each do |cell_id|
      bound = bound.union(Cell.new(cell_id).get_rect_bound)
    end
    bound
  end
end
