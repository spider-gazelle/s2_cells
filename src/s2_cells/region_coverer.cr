require "priority-queue"

struct S2Cells::RegionCoverer
  struct Candidate
    getter children : Array(Candidate)
    property cell : Cell
    property? terminal : Bool

    def initialize(@cell, @terminal)
      @children = [] of Candidate
    end

    def num_children : Int32
      @children.size
    end

    def <(other : Candidate) : Bool
      my_cell = @cell
      other_cell = other.cell
      raise "NotImplementedError" unless my_cell && other_cell
      my_cell.id < other_cell.id
    end
  end

  getter min_level : Int32
  getter max_level : Int32
  getter level_mod : Int32
  getter max_cells : Int32

  getter! region : LatLngRect

  @result : Array(CellId)
  @pq : Priority::Queue(Candidate)

  def initialize(
    @min_level = 0,
    @max_level = CellId::MAX_LEVEL,
    @level_mod = 1,
    @max_cells = 8,
    @region = nil,
    @result = [] of CellId,
    @pq = Priority::Queue(Candidate).new
  )
  end

  def min_level=(value : Int32)
    raise "Invalid min_level" unless value >= 0 && value <= CellId::MAX_LEVEL
    @min_level = value
  end

  def max_level=(value : Int32)
    raise "Invalid max_level" unless value >= 0 && value <= CellId::MAX_LEVEL
    @max_level = value
  end

  def level_mod=(value : Int32)
    raise "Invalid level_mod" unless value >= 1 && value <= 3
    @level_mod = value
  end

  def max_cells=(value : Int32)
    @max_cells = value
  end

  def get_covering(region : LatLngRect)
    @result.clear
    tmp_union = __get_cell_union(region)
    tmp_union.denormalize(@min_level, @level_mod)
  end

  def get_interior_covering(region : LatLngRect)
    @result.clear
    tmp_union = __get_interior_cell_union(region)
    tmp_union.denormalize(@min_level, @level_mod)
  end

  private def __new_candidate(cell : Cell) : Candidate?
    return nil unless region.may_intersect(cell)
    is_terminal = false
    if cell.level >= @min_level
      if @interior_covering
        if region.contains(cell)
          is_terminal = true
        elsif cell.level + @level_mod > @max_level
          return nil
        end
      else
        if cell.level + @level_mod > @max_level || region.contains(cell)
          is_terminal = true
        end
      end
    end

    Candidate.new cell, is_terminal
  end

  private def __max_children_shift : Int32
    2 * @level_mod
  end

  private def __expand_children(candidate : Candidate, cell : Cell, num_levels : Int32) : Int32
    num_levels -= 1
    num_terminals = 0
    cell.subdivide do |child_cell|
      if num_levels > 0
        if region.may_intersect(child_cell)
          num_terminals += __expand_children(candidate, child_cell, num_levels)
        end
        next
      end
      child = __new_candidate(child_cell)
      if child
        candidate.children << child
        num_terminals += 1 if child.terminal?
      end
    end
    num_terminals
  end

  private def __add_candidate(candidate : Candidate?)
    return unless candidate

    if candidate.terminal?
      @result << candidate.cell.id
      return
    end

    raise "Candidate should have no children" if candidate.num_children > 0

    num_levels = @level_mod
    num_levels = 1 if candidate.cell.level < @min_level
    num_terminals = __expand_children(candidate, candidate.cell, num_levels)

    if candidate.num_children == 0
      # Not needed due to GC
    elsif !@interior_covering && num_terminals == (1 << __max_children_shift) && candidate.cell.level >= @min_level
      candidate.terminal = true
      __add_candidate(candidate)
    else
      priority = ((candidate.cell.level << __max_children_shift) + candidate.num_children) << __max_children_shift + num_terminals
      @pq.push priority, candidate
    end
  end

  private def __get_initial_candidates
    if @max_cells >= 4
      cap = region.get_cap_bound
      level = {CellId.min_width.get_max_level(2 * cap.angle.radians), {@max_level, CellId::MAX_LEVEL - 1}.min}.min

      if @level_mod > 1 && level > @min_level
        level -= (level - @min_level) % @level_mod
      end

      if level > 0
        cell_id = CellId.from_point(cap.axis)
        vertex_neighbors = cell_id.get_vertex_neighbors(level)
        vertex_neighbors.each do |neighbor|
          __add_candidate(__new_candidate(Cell.new(neighbor)))
        end
        return
      end
    end

    6.times do |face|
      __add_candidate(__new_candidate(FACE_CELLS[face]))
    end
  end

  private def __get_covering(region : LatLngRect)
    raise "Priority queue not empty" unless @pq.empty?
    raise "Result not empty" unless @result.empty?
    @region = region

    __get_initial_candidates
    while !@pq.empty? && (!@interior_covering || @result.size < @max_cells)
      candidate = @pq.shift.value

      result_size = @interior_covering ? 0 : @pq.size
      if candidate.cell.level < @min_level || candidate.num_children == 1 || @result.size + result_size + candidate.num_children <= @max_cells
        candidate.children.each do |child|
          __add_candidate(child)
        end
      elsif @interior_covering
        # Do nothing here
      else
        candidate.terminal = true
        __add_candidate(candidate)
      end
    end

    @pq.clear
    @region = nil
  end

  private def __get_cell_union(region) : CellUnion
    @interior_covering = false
    __get_covering(region)
    CellUnion.new(@result)
  end

  private def __get_interior_cell_union(region) : CellUnion
    @interior_covering = true
    __get_covering(region)
    CellUnion.new(@result)
  end

  def self.flood_fill(region, start)
    all_nbrs = Set(CellId).new
    frontier = [] of CellId
    all_nbrs.add(start)
    frontier << start
    while !frontier.empty?
      cell_id = frontier.pop
      next unless region.may_intersect(Cell.new(cell_id))
      yield cell_id

      neighbors = cell_id.get_edge_neighbors
      neighbors.each do |nbr|
        if !all_nbrs.includes?(nbr)
          all_nbrs.add(nbr)
          frontier << nbr
        end
      end
    end
  end

  def self.get_simple_covering(region, start, level)
    flood_fill(region, CellId.from_point(start).parent(level))
  end
end
