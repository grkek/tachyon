module Tachyon
  module Geometry
    module Plane
      # Vertex layout: [x, y, z, nx, ny, nz, u, v] — 8 floats per vertex
      # Plane lies on XZ, normal pointing up (+Y)
      def self.generate(width : Float32 = 1.0f32, height : Float32 = 1.0f32) : {Array(Float32), Array(UInt32)}
        hw = width / 2.0f32
        hh = height / 2.0f32

        vertices = [
          # pos                          normal              uv
          -hw, 0.0f32, -hh, 0.0f32, 1.0f32, 0.0f32, 0.0f32, 0.0f32, # back-left
          hw, 0.0f32, -hh, 0.0f32, 1.0f32, 0.0f32, 1.0f32, 0.0f32,  # back-right
          hw, 0.0f32, hh, 0.0f32, 1.0f32, 0.0f32, 1.0f32, 1.0f32,   # front-right
          -hw, 0.0f32, hh, 0.0f32, 1.0f32, 0.0f32, 0.0f32, 1.0f32,  # front-left
        ] of Float32

        indices = [
          0_u32, 2_u32, 1_u32,
          2_u32, 0_u32, 3_u32,
        ] of UInt32

        {vertices, indices}
      end
    end
  end
end
