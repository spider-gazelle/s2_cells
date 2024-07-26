class S2Cells::CellId
  include CellBase
  include Comparable(CellId)

  getter id : UInt64

  def hash : UInt64
    id
  end

  def ==(other : CellId)
    @id == other.id
  end

  def <=>(other : CellId)
    @id <=> other.id
  end

  def initialize(@id)
  end

  # ToToken returns a hex-encoded string of the uint64 cell id, with leading
  # zeros included but trailing zeros stripped.
  def to_token : String
    token = @id.to_s(16).rjust(16, '0').rstrip('0')
    return "X" if token.size == 0
    token
  end

  # returns a cell given a hex-encoded string of its uint64 ID
  def self.from_token(token : String)
    raise ArgumentError.new("token size was #{token.bytesize}, max size is 16 bytes") if token.bytesize > 16
    # pad to 16 characters
    self.new(token.ljust(16, '0').to_u64(16))
  end

  def parent(level)
    new_lsb = self.class.lsb_for_level(level)
    s2 = CellId.new((@id & ((~new_lsb) &+ 1)) | new_lsb)

    raise InvalidLevel.new(level) unless valid?(s2.id)
    s2
  end

  def prev
    CellId.new(@id - (lsb << 1))
  end

  def next
    CellId.new(@id + (lsb << 1))
  end

  getter level : Int32 do
    return MAX_LEVEL if leaf?

    level = -1
    x = (@id & 0xffffffff_u64)

    if x != 0
      level += 16
    else
      x = ((@id >> 32) & 0xffffffff_u64)
    end

    # 2s compliment
    x &= ((~x) &+ 1)

    level += 8 unless (x & 0x00005555_u64).zero?
    level += 4 unless (x & 0x00550055_u64).zero?
    level += 2 unless (x & 0x05050505_u64).zero?
    level += 1 unless (x & 0x11111111_u64).zero?
    level
  end

  def self.from_point(p : Point)
    face, u, v = xyz_to_face_uv(p)
    i = st_to_ij(uv_to_st(u))
    j = st_to_ij(uv_to_st(v))

    from_face_ij(face, i, j)
  end

  def self.from_face_pos_level(face : Int, pos : UInt64, level : Int) : CellId
    face = face.to_u64
    raise ArgumentError.new("Invalid face: #{face} (must be in range 0..5)") unless (0_u64..5_u64).includes?(face)

    # Ensure that the position fits within the bits allocated by the level
    pos_length = level * 2
    max_pos = (1_u64 << pos_length) - 1_u64
    pos &= max_pos # Mask the position to fit the level's precision

    # Shift the face to the top three bits of the UInt64
    id = face << POS_BITS
    id = id + (pos | 1_u64)

    lsb_on_level = lsb_for_level(level)
    CellId.new((id & (~lsb_on_level &+ 1)) | lsb_on_level)
  end

  def self.range_begin(level : Int)
    from_face_pos_level(0_u64, 0_u64, 0).child_begin(level)
  end

  def self.range_end(level : Int)
    from_face_pos_level(5_u64, 0_u64, 0).child_end(level)
  end

  def self.walk(level : Int, &)
    begin_cell = range_begin(level)
    cellid_int = begin_cell.id
    endid_int = range_end(level).id

    # Doubling the lsb yields the increment between positions at a certain
    # level as 64-bit IDs. See CellId docstring for bit encoding.
    increment = begin_cell.lsb << 1

    while cellid_int != endid_int
      yield new(cellid_int)
      cellid_int += increment
    end
  end

  def self.xyz_to_face_uv(p : Point) : Tuple(UInt64, Float64, Float64)
    face = p.largest_abs_component

    pface = case face
            when 0_u64 then p.x
            when 1_u64 then p.y
            else            p.z
            end

    face += 3_u64 if pface < 0.0

    u, v = valid_face_xyz_to_uv(face, p)
    {face, u, v}
  end

  def self.uv_to_st(u : Float64)
    return 0.5 * Math.sqrt(1.0 + 3.0 * u) if u >= 0.0
    1.0 - 0.5 * Math.sqrt(1.0 - 3.0 * u)
  end

  def self.st_to_ij(s : Float64) : UInt64
    {0_u64, {MAX_SIZE - 1_u64, (MAX_SIZE * s).floor.to_u64}.min}.max
  end

  def self.valid_face_xyz_to_uv(face : UInt64, p : Point)
    raise "invalid face xyz" unless p.dot_prod(face_uv_to_xyz(face, 0.0, 0.0)) > 0

    case face
    when 0 then [p.y / p.x, p.z / p.x]
    when 1 then [-p.x / p.y, p.z / p.y]
    when 2 then [-p.x / p.z, -p.y / p.z]
    when 3 then [p.z / p.x, p.y / p.x]
    when 4 then [p.z / p.y, -p.x / p.y]
    else        [-p.y / p.z, -p.x / p.z]
    end
  end

  def self.face_uv_to_xyz(face : UInt64, u : Float64, v : Float64)
    case face
    when 0 then Point.new(1_f64, u, v)
    when 1 then Point.new(-u, 1_f64, v)
    when 2 then Point.new(-u, -v, 1_f64)
    when 3 then Point.new(-1_f64, -v, -u)
    when 4 then Point.new(v, -1_f64, -u)
    else        Point.new(v, u, -1_f64)
    end
  end

  def self.from_face_ij(face : UInt64, i : Int128 | UInt64, j : Int128 | UInt64) : CellId
    n = face << (POS_BITS - 1)
    bits = face & SWAP_MASK

    7.downto(0) do |k|
      mask = (1_u64 << LOOKUP_BITS) - 1
      bits += (((i >> (k * LOOKUP_BITS)) & mask) << (LOOKUP_BITS + 2))
      bits += (((j >> (k * LOOKUP_BITS)) & mask) << 2)
      bits = LOOKUP_POS[bits]
      n |= (bits >> 2) << (k * 2 * LOOKUP_BITS)
      bits &= SWAP_MASK | INVERT_MASK
    end

    new(n * 2 + 1)
  end

  # Conversion of from_face_ij_wrap method
  def self.from_face_ij_wrap(face : UInt64, i : Int128, j : Int128) : CellId
    # Convert (i, j) to (u, v)
    scale = 1.0 / MAX_SIZE.to_f
    u = scale * ((i << 1) + 1 - MAX_SIZE_I)
    v = scale * ((j << 1) + 1 - MAX_SIZE_I)

    # Convert from (u, v) back to face, (s, t) and then to (i, j)
    face, u, v = xyz_to_face_uv(face_uv_to_xyz(face, u, v))
    from_face_ij(
      face,
      st_to_ij(0.5 * (u + 1)),
      st_to_ij(0.5 * (v + 1)),
    )
  end

  def self.from_face_ij_same(face : UInt64, i : Int128, j : Int128, same_face : Bool)
    if same_face
      from_face_ij(face, i, j)
    else
      from_face_ij_wrap(face, i, j)
    end
  end

  def leaf?
    @id & 1 != 0
  end

  def child_begin
    old_lsb = lsb
    self.class.new(@id &- old_lsb &+ (old_lsb >> 2))
  end

  def child_begin(level : Int)
    raise "invalid level: #{level}" unless (0..30).includes?(level)
    self.class.new(@id &- lsb &+ self.class.lsb_for_level(level))
  end

  def child_end
    old_lsb = lsb
    self.class.new(@id &+ old_lsb &+ (old_lsb >> 2))
  end

  def child_end(level : Int)
    raise "invalid level: #{level}" unless (0..30).includes?(level)
    self.class.new(@id &+ lsb &+ self.class.lsb_for_level(level))
  end

  def prev
    self.class.new(@id &- (lsb << 1))
  end

  def next
    self.class.new(@id &+ (lsb << 1))
  end

  def children(level : Int32? = nil, &)
    if level
      cell_id = child_begin(level)
      ending = child_end(level)
    else
      cell_id = child_begin
      ending = child_end
    end

    while cell_id != ending
      yield cell_id
      cell_id = cell_id.next
    end
  end

  def children(level : Int32? = nil) : Array(CellId)
    cells = Array(CellId).new(4)
    children(level) { |child| cells << child }
    cells
  end

  def face?
    (@id & (self.class.lsb_for_level(0) - 1)) == 0
  end

  def parent : CellId
    raise "face cells don't have a parent" if face?
    new_lsb = lsb << 2
    self.class.new((@id & (~new_lsb &+ 1)) | new_lsb)
  end

  def parent(level : Int)
    current_level = self.level
    raise "invalid level: #{level}" unless (0...current_level).includes?(level)
    new_lsb = self.class.lsb_for_level(level)
    self.class.new((@id & (~new_lsb &+ 1)) | new_lsb)
  end

  def range_min
    self.class.new(@id &- (lsb &- 1))
  end

  def range_max
    self.class.new(@id &+ (lsb &- 1))
  end

  def self.valid?(cell_id : CellId)
    # 6 is an invalid face
    return false unless cell_id.face < NUM_FACES
    (cell_id.lsb & 0x1555555555555555_u64) != 0
  end

  private def valid?(cell_id : UInt64)
    self.class.valid? CellId.new(cell_id)
  end

  def valid?
    self.class.valid? self
  end

  def lsb
    @id & (~@id &+ 1) # This is equivalent to (@id & -@id) for signed integers
  end

  def self.lsb_for_level(level)
    1_u64 << (2 * (MAX_LEVEL - level))
  end

  def get_size_ij(level = self.level)
    1_u64 << (MAX_LEVEL - level)
  end

  def to_face_ij_orientation
    i, j = 0_u64, 0_u64
    face = self.face
    bits = face & SWAP_MASK

    7.downto(0) do |k|
      if k == 7
        nbits = MAX_LEVEL - 7 * LOOKUP_BITS
      else
        nbits = LOOKUP_BITS
      end

      bits += (
        self.id >> (k * 2 * LOOKUP_BITS + 1) &
        ((1 << (2 * nbits)) - 1)
      ) << 2
      bits = LOOKUP_IJ[bits]
      i += (bits >> (LOOKUP_BITS + 2)) << (k * LOOKUP_BITS)
      j += ((bits >> 2) & ((1 << LOOKUP_BITS) - 1)) << (k * LOOKUP_BITS)
      bits &= SWAP_MASK | INVERT_MASK
    end

    raise "Assertion failed" unless POS_TO_ORIENTATION[2] == 0
    raise "Assertion failed" unless SWAP_MASK == POS_TO_ORIENTATION[0]
    if (self.lsb & 0x1111111111111110_u64) != 0
      bits ^= SWAP_MASK
    end
    orientation = bits

    return {face, i, j, orientation}
  end

  getter face : UInt64 do
    # Shift right by 61 bits to move the top 3 bits to the least significant bit position.
    # Mask with binary 111 to isolate these three bits.
    (@id >> POS_BITS) & 0b111_u64
  end

  def get_edge_neighbors : Array(CellId)
    level = self.level
    size = self.get_size_ij(level)
    face, i, j, orientation = self.to_face_ij_orientation

    i = i.to_i128
    j = j.to_i128

    [
      (self.class.from_face_ij_same(face, i, j - size, j - size >= 0).parent(level)),
      (self.class.from_face_ij_same(face, i + size, j, i + size < MAX_SIZE_I).parent(level)),
      (self.class.from_face_ij_same(face, i, j + size, j + size < MAX_SIZE_I).parent(level)),
      (self.class.from_face_ij_same(face, i - size, j, i - size >= 0).parent(level)),
    ]
  end

  def get_vertex_neighbors(level : Int32) : Array(CellId)
    # "level" must be strictly less than this cell's level so that we can
    # determine which vertex this cell is closest to.
    raise "Invalid level" unless level < self.level

    face, i, j, orientation = self.to_face_ij_orientation
    i = i.to_i128
    j = j.to_i128

    # Determine the i- and j-offsets to the closest neighboring cell in
    # each direction. This involves looking at the next bit of "i" and
    # "j" to determine which quadrant of this->parent(level) this cell
    # lies in.
    halfsize = self.get_size_ij(level + 1).to_i128
    size = halfsize << 1
    if i & halfsize != 0
      ioffset = size
      isame = (i + size) < MAX_SIZE_I
    else
      ioffset = -size
      isame = (i - size) >= 0
    end

    if j & halfsize != 0
      joffset = size
      jsame = (j + size) < MAX_SIZE_I
    else
      joffset = -size
      jsame = (j - size) >= 0
    end

    neighbors = [] of CellId
    neighbors << self.parent(level)
    neighbors << self.class.from_face_ij_same(face, i + ioffset, j, isame).parent(level)
    neighbors << self.class.from_face_ij_same(face, i, j + joffset, jsame).parent(level)

    if isame || jsame
      neighbors << self.class.from_face_ij_same(face, i + ioffset, j + joffset, isame && jsame).parent(level)
    end

    neighbors
  end

  def get_all_neighbors(nbr_level : Int32 = self.level) : Array(CellId)
    face, i, j, orientation = self.to_face_ij_orientation
    i = i.to_i128
    j = j.to_i128

    # Find the coordinates of the lower left-hand leaf cell. Normalize (i, j).
    size = self.get_size_ij.to_i128
    i &= -size
    j &= -size

    nbr_size = self.get_size_ij(nbr_level).to_i128
    raise "Invalid neighborhood size" unless nbr_size <= size

    neighbors = [] of CellId

    # Compute the N-S, E-W, and diagonal neighbors in one pass.
    k = -nbr_size
    while true
      if k < 0
        same_face = (j + k >= 0)
      elsif k >= size
        same_face = (j + k < MAX_SIZE_I)
      else
        same_face = false
        # North and South neighbors
        neighbors << self.class.from_face_ij_same(face, i + k, j - nbr_size, j - size >= 0).parent(nbr_level)
        neighbors << self.class.from_face_ij_same(face, i + k, j + size, j + size < MAX_SIZE).parent(nbr_level)
      end

      # East and West neighbors
      neighbors << self.class.from_face_ij_same(face, i - nbr_size, j + k, same_face && i - size >= 0).parent(nbr_level)
      neighbors << self.class.from_face_ij_same(face, i + size, j + k, same_face && i + size < MAX_SIZE).parent(nbr_level)

      if k >= size
        break
      end
      k += nbr_size
    end

    neighbors
  end

  getter level : Int32 do
    if leaf?
      30
    else
      x = (@id & 0xffffffff_u64)
      level = -1
      if !x.zero?
        level += 16
      else
        x = ((@id >> 32) & 0xffffffff_u64)
      end

      x &= (~x &+ 1)
      level += 8 if x & 0x00005555_u64 != 0
      level += 4 if x & 0x00550055_u64 != 0
      level += 2 if x & 0x05050505_u64 != 0
      level += 1 if x & 0x11111111_u64 != 0
      level
    end
  end

  getter pos : UInt64 do
    @id & (UInt64::MAX >> FACE_BITS)
  end

  def get_center_si_ti
    face, i, j, orientation = self.to_face_ij_orientation

    if self.leaf?
      delta = 1
    elsif ((i ^ (self.id >> 2)) & 1) != 0_u64
      delta = 2
    else
      delta = 0
    end

    {face, 2_u64 &* i &+ delta, 2_u64 &* j &+ delta}
  end

  def self.st_to_uv(s : Float64) : Float64
    if s >= 0.5
      (1.0 / 3.0) * (4 * s * s - 1)
    else
      (1.0 / 3.0) * (1 - 4 * (1 - s) * (1 - s))
    end
  end

  def to_point_raw
    face, si, ti = self.get_center_si_ti
    self.class.face_uv_to_xyz(
      face,
      self.class.st_to_uv((0.5 / MAX_SIZE) * si),
      self.class.st_to_uv((0.5 / MAX_SIZE) * ti),
    )
  end

  def self.from_lat_lon(lat : Float64, lon : Float64)
    from_point LatLon.new(lat, lon).to_point
  end

  def self.from_lat_lon(latlon : LatLon)
    from_lat_lon latlon.lat, latlon.lon
  end

  def to_lat_lon : LatLon
    LatLon.from_point(self.to_point_raw)
  end

  private def cell_child_position(x : Float64, y : Float64, rx : Int32, ry : Int32, level : Int32) : Tuple(Float64, Float64)
    half_size = 1.0 / (1 << (level + 1))
    if rx == 0 && ry == 0
      {x, y}
    elsif rx == 0 && ry == 1
      {x, y + half_size}
    elsif rx == 1 && ry == 0
      {x + half_size, y}
    else # rx == 1 && ry == 1
      {x + half_size, y + half_size}
    end
  end

  private def lat_lon_from_xyz(x : Float64, y : Float64, z : Float64) : S2Cells::LatLon
    lat = Math.atan2(z, Math.sqrt(x*x + y*y)) * 180 / Math::PI
    lon = Math.atan2(y, x) * 180 / Math::PI
    S2Cells::LatLon.new(lat, lon)
  end

  def bounds : Bounds
    # Get the center point of the cell
    center = self.to_lat_lon

    # Calculate the size of the cell at this level
    size = 360.0 / (1_u64 << self.level)

    # Calculate the bounds
    lat_lo = (center.lat - size / 2).clamp(-90.0, 90.0)
    lat_hi = (center.lat + size / 2).clamp(-90.0, 90.0)
    lon_lo = center.lon - size / 2
    lon_hi = center.lon + size / 2

    # Handle longitude wraparound
    if lon_lo < -180.0
      lon_lo += 360.0
      lon_hi += 360.0
    elsif lon_hi > 180.0
      lon_lo -= 360.0
      lon_hi -= 360.0
    end

    Bounds.new(lat_lo, lat_hi, lon_lo, lon_hi)
  end
end
