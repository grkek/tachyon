module Tachyon
  module Math
    # Six-plane frustum extracted from a view-projection matrix.
    # Each plane is stored as (a, b, c, d) where ax + by + cz + d = 0
    # with the normal pointing inward.
    struct Frustum
      getter planes : StaticArray(Vector4, 6)

      def initialize(vp : Matrix4)
        m = vp.data
        @planes = StaticArray(Vector4, 6).new(Vector4.new)

        # Left
        @planes[0] = Vector4.new(
          m[3] + m[0], m[7] + m[4], m[11] + m[8], m[15] + m[12]
        ).normalized_plane

        # Right
        @planes[1] = Vector4.new(
          m[3] - m[0], m[7] - m[4], m[11] - m[8], m[15] - m[12]
        ).normalized_plane

        # Bottom
        @planes[2] = Vector4.new(
          m[3] + m[1], m[7] + m[5], m[11] + m[9], m[15] + m[13]
        ).normalized_plane

        # Top
        @planes[3] = Vector4.new(
          m[3] - m[1], m[7] - m[5], m[11] - m[9], m[15] - m[13]
        ).normalized_plane

        # Near
        @planes[4] = Vector4.new(
          m[3] + m[2], m[7] + m[6], m[11] + m[10], m[15] + m[14]
        ).normalized_plane

        # Far
        @planes[5] = Vector4.new(
          m[3] - m[2], m[7] - m[6], m[11] - m[10], m[15] - m[14]
        ).normalized_plane
      end

      # Test if an AABB is at least partially inside the frustum
      def intersects_aabb?(aabb : AABB) : Bool
        @planes.each do |plane|
          # Find the AABB corner most aligned with the plane normal (p-vertex)
          px = plane.x > 0.0f32 ? aabb.max.x : aabb.min.x
          py = plane.y > 0.0f32 ? aabb.max.y : aabb.min.y
          pz = plane.z > 0.0f32 ? aabb.max.z : aabb.min.z

          # If the p-vertex is outside this plane, the AABB is fully outside
          if plane.x * px + plane.y * py + plane.z * pz + plane.w < 0.0f32
            return false
          end
        end
        true
      end
    end
  end
end
