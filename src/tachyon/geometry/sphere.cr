module Tachyon
  module Geometry
    module Sphere
      # Vertex layout: [x, y, z, nx, ny, nz, u, v] — 8 floats per vertex
      def self.generate(radius : Float32 = 1.0f32, segments : Int32 = 32, rings : Int32 = 16) : {Array(Float32), Array(UInt32)}
        vertices = [] of Float32
        indices = [] of UInt32

        (0..rings).each do |ring|
          phi = ::Math::PI * ring.to_f64 / rings.to_f64
          (0..segments).each do |seg|
            theta = 2.0 * ::Math::PI * seg.to_f64 / segments.to_f64

            x = (::Math.sin(phi) * ::Math.cos(theta)).to_f32
            y = ::Math.cos(phi).to_f32
            z = (::Math.sin(phi) * ::Math.sin(theta)).to_f32

            u = seg.to_f32 / segments.to_f32
            v = ring.to_f32 / rings.to_f32

            # Position
            vertices << x * radius << y * radius << z * radius
            # Normal
            vertices << x << y << z
            # UV
            vertices << u << v
          end
        end

        (0...rings).each do |ring|
          (0...segments).each do |seg|
            current = (ring * (segments + 1) + seg).to_u32
            next_row = current + (segments + 1).to_u32

            indices << current
            indices << current + 1
            indices << next_row

            indices << current + 1
            indices << next_row + 1
            indices << next_row
          end
        end

        {vertices, indices}
      end
    end
  end
end
