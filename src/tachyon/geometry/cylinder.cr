module Tachyon
  module Geometry
    module Cylinder
      # Vertex layout: [x, y, z, nx, ny, nz, u, v] — 8 floats per vertex
      # Centered at origin, extends from -height/2 to +height/2 along Y
      def self.generate(radius : Float32 = 1.0f32, height : Float32 = 2.0f32, segments : Int32 = 32) : {Array(Float32), Array(UInt32)}
        vertices = [] of Float32
        indices = [] of UInt32
        half_h = height / 2.0f32

        # Side vertices
        (0..segments).each do |seg|
          theta = 2.0f32 * ::Math::PI.to_f32 * seg.to_f32 / segments.to_f32
          x = ::Math.cos(theta).to_f32
          z = ::Math.sin(theta).to_f32
          u = seg.to_f32 / segments.to_f32

          # Bottom vertex
          vertices << x * radius << -half_h << z * radius
          vertices << x << 0.0f32 << z
          vertices << u << 0.0f32

          # Top vertex
          vertices << x * radius << half_h << z * radius
          vertices << x << 0.0f32 << z
          vertices << u << 1.0f32
        end

        # Side indices
        (0...segments).each do |seg|
          b = (seg * 2).to_u32
          indices << b << b + 1 << b + 2
          indices << b + 2 << b + 1 << b + 3
        end

        # Top cap
        top_center = (vertices.size // 8).to_u32
        vertices << 0.0f32 << half_h << 0.0f32
        vertices << 0.0f32 << 1.0f32 << 0.0f32
        vertices << 0.5f32 << 0.5f32

        (0..segments).each do |seg|
          theta = 2.0f32 * ::Math::PI.to_f32 * seg.to_f32 / segments.to_f32
          x = ::Math.cos(theta).to_f32
          z = ::Math.sin(theta).to_f32
          vertices << x * radius << half_h << z * radius
          vertices << 0.0f32 << 1.0f32 << 0.0f32
          vertices << x * 0.5f32 + 0.5f32 << z * 0.5f32 + 0.5f32
        end

        (0...segments).each do |seg|
          indices << top_center
          indices << top_center + 2 + seg.to_u32
          indices << top_center + 1 + seg.to_u32
        end

        # Bottom cap
        bot_center = (vertices.size // 8).to_u32
        vertices << 0.0f32 << -half_h << 0.0f32
        vertices << 0.0f32 << -1.0f32 << 0.0f32
        vertices << 0.5f32 << 0.5f32

        (0..segments).each do |seg|
          theta = 2.0f32 * ::Math::PI.to_f32 * seg.to_f32 / segments.to_f32
          x = ::Math.cos(theta).to_f32
          z = ::Math.sin(theta).to_f32
          vertices << x * radius << -half_h << z * radius
          vertices << 0.0f32 << -1.0f32 << 0.0f32
          vertices << x * 0.5f32 + 0.5f32 << z * 0.5f32 + 0.5f32
        end

        (0...segments).each do |seg|
          indices << bot_center
          indices << bot_center + 1 + seg.to_u32
          indices << bot_center + 2 + seg.to_u32
        end

        {vertices, indices}
      end
    end
  end
end
