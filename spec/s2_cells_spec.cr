require "./spec_helper"

module S2Cells
  describe S2Cells do
    it "should convert lat lng to a cell id" do
      {
        {0x47a1cbd595522b39_u64, 49.703498679, 11.770681595},
        {0x46525318b63be0f9_u64, 55.685376759, 12.588490937},
        {0x52b30b71698e729d_u64, 45.486546517, -93.449700022},
        {0x46ed8886cfadda85_u64, 58.299984854, 23.049300056},
        {0x3663f18a24cbe857_u64, 34.364439040, 108.330699969},
        {0x10a06c0a948cf5d_u64, -30.694551352, -30.048758753},
        {0x2b2bfd076787c5df_u64, -25.285264027, 133.823116966},
        {0xb09dff882a7809e1_u64, -75.000000031, 0.000000133},
        {0x94daa3d000000001_u64, -24.694439215, -47.537363213},
        {0x87a1000000000001_u64, 38.899730392, -99.901813021},
        {0x4fc76d5000000001_u64, 81.647200334, -55.631712940},
        {0x3b00955555555555_u64, 10.050986518, 78.293170610},
        {0x1dcc469991555555_u64, -34.055420593, 18.551140038},
        {0xb112966aaaaaaaab_u64, -69.219262171, 49.670072392},
      }.each do |(id, lat, lng)|
        lat_lng = LatLng.from_degrees(lat, lng)
        point = lat_lng.to_point
        cell = CellId.from_point(point)
        cell.id.should eq(id)

        CellId.from_lat_lng(lat_lng).id.should eq(id)
        S2Cells.at(lat, lng).id.should eq(id)
      end
    end

    it "should convert tokens" do
      {
        {"1", 0x1000000000000000_u64},
        {"3", 0x3000000000000000_u64},
        {"14", 0x1400000000000000_u64},
        {"41", 0x4100000000000000_u64},
        {"094", 0x0940000000000000_u64},
        {"537", 0x5370000000000000_u64},
        {"3fec", 0x3fec000000000000_u64},
        {"72f3", 0x72f3000000000000_u64},
        {"52b8c", 0x52b8c00000000000_u64},
        {"990ed", 0x990ed00000000000_u64},
        {"4476dc", 0x4476dc0000000000_u64},
        {"2a724f", 0x2a724f0000000000_u64},
        {"7d4afc4", 0x7d4afc4000000000_u64},
        {"b675785", 0xb675785000000000_u64},
        {"40cd6124", 0x40cd612400000000_u64},
        {"3ba32f81", 0x3ba32f8100000000_u64},
        {"08f569b5c", 0x08f569b5c0000000_u64},
        {"385327157", 0x3853271570000000_u64},
        {"166c4d1954", 0x166c4d1954000000_u64},
        {"96f48d8c39", 0x96f48d8c39000000_u64},
        {"0bca3c7f74c", 0x0bca3c7f74c00000_u64},
        {"1ae3619d12f", 0x1ae3619d12f00000_u64},
        {"07a77802a3fc", 0x07a77802a3fc0000_u64},
        {"4e7887ec1801", 0x4e7887ec18010000_u64},
        {"4adad7ae74124", 0x4adad7ae74124000_u64},
        {"90aba04afe0c5", 0x90aba04afe0c5000_u64},
        {"8ffc3f02af305c", 0x8ffc3f02af305c00_u64},
        {"6fa47550938183", 0x6fa4755093818300_u64},
        {"aa80a565df5e7fc", 0xaa80a565df5e7fc0_u64},
        {"01614b5e968e121", 0x01614b5e968e1210_u64},
        {"aa05238e7bd3ee7c", 0xaa05238e7bd3ee7c_u64},
        {"48a23db9c2963e5b", 0x48a23db9c2963e5b_u64},
      }.each do |(token, id)|
        cell = CellId.from_token(token)
        cell.id.should eq id
        cell.to_token.should eq token
      end
    end
  end

  it "should generate the correct face" do
    CellId.from_lat_lng(0.0, 0.0).face.should eq 0
    CellId.from_lat_lng(0.0, 90.0).face.should eq 1
    CellId.from_lat_lng(90.0, 0.0).face.should eq 2
    CellId.from_lat_lng(0.0, 180.0).face.should eq 3
    CellId.from_lat_lng(0.0, -90.0).face.should eq 4
    CellId.from_lat_lng(-90.0, 0.0).face.should eq 5
  end

  it "test parent child relationship" do
    cell_id = CellId.from_face_pos_level(3, 0x12345678_u64, CellId::MAX_LEVEL - 4)

    cell_id.face.should eq 3
    cell_id.pos.to_s(2).should eq 0x12345700.to_s(2)
    cell_id.level.should eq(CellId::MAX_LEVEL - 4)
    cell_id.valid?.should be_true
    cell_id.leaf?.should be_false

    cell_id.child_begin(cell_id.level + 2).pos.should eq 0x12345610
    cell_id.child_begin.pos.should eq 0x12345640
    cell_id.parent.pos.should eq 0x12345400
    cell_id.parent(cell_id.level - 2).pos.should eq 0x12345000

    cell_id.child_begin.next.next.next.next.should eq cell_id.child_end
    cell_id.child_begin(CellId::MAX_LEVEL).should eq cell_id.range_min
    cell_id.child_end(CellId::MAX_LEVEL).should eq cell_id.range_max.next

    # Check that cells are represented by the position of their center
    # alngg the Hilbert curve.
    (cell_id.range_min.id &+ cell_id.range_max.id).should eq(2_u64 &* cell_id.id)
  end

  it "should be able to switch between lat lang and cell ids" do
    INVERSE_ITERATIONS.times do
      cell_id = get_random_cell_id(CellId::MAX_LEVEL)
      cell_id.leaf?.should be_true
      cell_id.level.should eq CellId::MAX_LEVEL
      center = cell_id.to_lat_lng
      CellId.from_lat_lng(center).id.should eq cell_id.id
    end
  end

  it "should be able to switch between tokens and cell ids" do
    TOKEN_ITERATIONS.times do
      cell_id = get_random_cell_id
      token = cell_id.to_token
      (token.size <= 16).should be_true
      CellId.from_token(token).id.should eq cell_id.id
    end
  end

  it "should be able to obtain neighbours" do
    # Check the edge neighbors of face 1.
    out_faces = {5, 3, 2, 0}
    face_nbrs = CellId.from_face_pos_level(1, 0, 0).get_edge_neighbors
    face_nbrs.each_with_index do |face_nbr, i|
      face_nbr.face?.should be_true
      face_nbr.face.should eq out_faces[i]?
    end

    # Check the vertex neighbors of the center of face 2 at level 5.
    neighbors = CellId.from_point(Point.new(0, 0, 1)).get_vertex_neighbors(5)
    neighbors.sort!
    neighbors.each_with_index do |neighbor, i|
      neighbor.id.should eq(CellId.from_face_ij(
        2,
        (1_u64 << 29) - (i < 2 ? 1 : 0),
        (1_u64 << 29) - (i == 0 || i == 3 ? 1 : 0)
      ).parent(5).id)
    end

    neighbors.each_with_index do |neighbor, i|
      neighbor.should eq(CellId.from_face_ij(
        2,
        (1_u64 << 29) - (i < 2 ? 1 : 0),
        (1_u64 << 29) - (i == 0 || i == 3 ? 1 : 0)
      ).parent(5))
    end

    # Check the vertex neighbors of the corner of faces 0, 4, and 5.
    cell_id = CellId.from_face_pos_level(0, 0, CellId::MAX_LEVEL)
    neighbors = cell_id.get_vertex_neighbors(0)
    neighbors.sort!
    neighbors.size.should eq 3

    CellId.from_face_pos_level(0, 0, 0).should eq neighbors[0]
    CellId.from_face_pos_level(4, 0, 0).should eq neighbors[1]
    CellId.from_face_pos_level(5, 0, 0).should eq neighbors[2]

    # check a bunch
    NEIGHBORS_ITERATIONS.times do
      cell_id = get_random_cell_id
      cell_id = cell_id.parent if cell_id.leaf?
      max_diff = {6, CellId::MAX_LEVEL - cell_id.level - 1}.min
      level = max_diff == 0 ? cell_id.level : cell_id.level + rand(max_diff)
      raise "level < cell_id.level" unless level >= cell_id.level
      raise "level == MAX_LEVEL" if level >= CellId::MAX_LEVEL

      all, expected = {Set(CellId).new, Set(CellId).new}
      neighbors = cell_id.get_all_neighbors(level)
      all.concat neighbors
      cell_id.children(level + 1).each do |child|
        all.add(child.parent)
        expected.concat(child.get_vertex_neighbors(level))
      end

      all_a = all.map(&.id).uniq!.sort
      expect_a = expected.map(&.id).uniq!.sort

      all_a.size.should eq expect_a.size
      all_a.should eq expect_a
    end
  end

  it "should work with faces" do
    edge_counts = Hash(Point, Int32).new(0)
    vertex_counts = Hash(Point, Int32).new(0)

    6.times do |face|
      cell_id = CellId.from_face_pos_level(face, 0, 0)
      cell = Cell.new(cell_id)
      cell.id.should eq cell_id
      cell.face.should eq face
      cell.level.should eq 0

      cell.orientation.should eq(face & SWAP_MASK)
      cell.leaf?.should eq false

      4.times do |k|
        edge_counts[cell.get_edge_raw(k)] += 1
        vertex_counts[cell.get_vertex_raw(k)] += 1

        cell.get_vertex_raw(k).dot_prod(cell.get_edge_raw(k)).should eq 0.0
        cell.get_vertex_raw((k + 1) & 3)
          .dot_prod(cell.get_edge_raw(k))
          .should eq 0.0

        cell
          .get_vertex_raw(k)
          .cross_prod(cell.get_vertex_raw((k + 1) & 3))
          .normalize
          .dot_prod(cell.get_edge(k))
          .should be_close(1.0, 0.000001)
      end
    end

    edge_counts.values.each { |count| count.should eq 2 }
    vertex_counts.values.each { |count| count.should eq 3 }
  end

  it "generates the correct covering for a given region" do
    coverer = RegionCoverer.new

    p1 = LatLng.from_degrees(33.0, -122.0)
    p2 = LatLng.from_degrees(33.1, -122.1)

    cell_ids = coverer.get_covering(LatLngRect.from_point_pair(p1, p2))
    ids = cell_ids.map(&.id).sort

    target = [
      9291041754864156672_u64,
      9291043953887412224_u64,
      9291044503643226112_u64,
      9291045878032760832_u64,
      9291047252422295552_u64,
      9291047802178109440_u64,
      9291051650468806656_u64,
      9291052200224620544_u64,
    ]
    ids.should eq(target)
  end
end
