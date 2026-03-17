module Tachyon
  module Geometry
    module Torus
      # Vertex layout: [x, y, z, nx, ny, nz, u, v] — 8 floats per vertex
      # major_radius: distance from center to tube center
      # minor_radius: tube radius
      def self.generate(major_radius : Float32 = 1.0f32, minor_radius : Float32 = 0.4f32,
                        major_segments : Int32 = 32, minor_segments : Int32 = 16) : {Array(Float32), Array(UInt32)}
        vertices = [] of Float32
        indices = [] of UInt32

        (0..major_segments).each do |i|
          u = i.to_f32 / major_segments.to_f32
          theta = u * 2.0f32 * ::Math::PI.to_f32
          cos_theta = ::Math.cos(theta).to_f32
          sin_theta = ::Math.sin(theta).to_f32

          (0..minor_segments).each do |j|
            v = j.to_f32 / minor_segments.to_f32
            phi = v * 2.0f32 * ::Math::PI.to_f32
            cos_phi = ::Math.cos(phi).to_f32
            sin_phi = ::Math.sin(phi).to_f32

            # Position
            x = (major_radius + minor_radius * cos_phi) * cos_theta
            y = minor_radius * sin_phi
            z = (major_radius + minor_radius * cos_phi) * sin_theta

            # Normal (direction from tube center to surface point)
            nx = cos_phi * cos_theta
            ny = sin_phi
            nz = cos_phi * sin_theta

            vertices << x << y << z
            vertices << nx << ny << nz
            vertices << u << v
          end
        end

        # Indices
        (0...major_segments).each do |i|
          (0...minor_segments).each do |j|
            current = (i * (minor_segments + 1) + j).to_u32
            next_ring = current + (minor_segments + 1).to_u32

            indices << current
            indices << current + 1
            indices << next_ring

            indices << current + 1
            indices << next_ring + 1
            indices << next_ring
          end
        end

        {vertices, indices}
      end
    end
  end
end
