module Tachyon
  module Geometry
    module Cube
      # Generates a cube centered at origin.
      # Vertex layout: [x, y, z, nx, ny, nz, u, v] — 8 floats per vertex
      def self.generate(width : Float32 = 1.0f32, height : Float32 = 1.0f32, depth : Float32 = 1.0f32) : {Array(Float32), Array(UInt32)}
        hw = width / 2.0f32
        hh = height / 2.0f32
        hd = depth / 2.0f32

        vertices = [] of Float32
        indices = [] of UInt32

        add_face = ->(p0 : Math::Vector3, p1 : Math::Vector3, p2 : Math::Vector3, p3 : Math::Vector3, normal : Math::Vector3) {
          base = (vertices.size // 8).to_u32

          # UV corners: 0,0 -> 1,0 -> 1,1 -> 0,1
          uvs = [{0.0f32, 0.0f32}, {1.0f32, 0.0f32}, {1.0f32, 1.0f32}, {0.0f32, 1.0f32}]

          {p0, p1, p2, p3}.each_with_index do |p, i|
            vertices << p.x << p.y << p.z
            vertices << normal.x << normal.y << normal.z
            vertices << uvs[i][0] << uvs[i][1]
          end

          indices << base << base + 1 << base + 2
          indices << base + 2 << base + 3 << base
        }

        # Front (+Z)
        add_face.call(
          Math::Vector3.new(-hw, -hh, hd), Math::Vector3.new(hw, -hh, hd),
          Math::Vector3.new(hw, hh, hd), Math::Vector3.new(-hw, hh, hd),
          Math::Vector3.new(0.0f32, 0.0f32, 1.0f32)
        )

        # Back (-Z)
        add_face.call(
          Math::Vector3.new(hw, -hh, -hd), Math::Vector3.new(-hw, -hh, -hd),
          Math::Vector3.new(-hw, hh, -hd), Math::Vector3.new(hw, hh, -hd),
          Math::Vector3.new(0.0f32, 0.0f32, -1.0f32)
        )

        # Top (+Y)
        add_face.call(
          Math::Vector3.new(-hw, hh, hd), Math::Vector3.new(hw, hh, hd),
          Math::Vector3.new(hw, hh, -hd), Math::Vector3.new(-hw, hh, -hd),
          Math::Vector3.new(0.0f32, 1.0f32, 0.0f32)
        )

        # Bottom (-Y)
        add_face.call(
          Math::Vector3.new(-hw, -hh, -hd), Math::Vector3.new(hw, -hh, -hd),
          Math::Vector3.new(hw, -hh, hd), Math::Vector3.new(-hw, -hh, hd),
          Math::Vector3.new(0.0f32, -1.0f32, 0.0f32)
        )

        # Right (+X)
        add_face.call(
          Math::Vector3.new(hw, -hh, hd), Math::Vector3.new(hw, -hh, -hd),
          Math::Vector3.new(hw, hh, -hd), Math::Vector3.new(hw, hh, hd),
          Math::Vector3.new(1.0f32, 0.0f32, 0.0f32)
        )

        # Left (-X)
        add_face.call(
          Math::Vector3.new(-hw, -hh, -hd), Math::Vector3.new(-hw, -hh, hd),
          Math::Vector3.new(-hw, hh, hd), Math::Vector3.new(-hw, hh, -hd),
          Math::Vector3.new(-1.0f32, 0.0f32, 0.0f32)
        )

        {vertices, indices}
      end
    end
  end
end
