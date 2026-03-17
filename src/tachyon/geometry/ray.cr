module Tachyon
  module Math
    struct Ray
      property origin : Vector3
      property direction : Vector3

      def initialize(@origin : Vector3, @direction : Vector3)
      end

      def point_at(t : Float32) : Vector3
        @origin + @direction * t
      end

      # Ray-AABB intersection (slab method)
      # Returns distance t, or nil if no hit
      def intersects_aabb?(aabb : AABB) : Float32?
        inv_dir = Vector3.new(
          @direction.x != 0.0f32 ? 1.0f32 / @direction.x : Float32::MAX,
          @direction.y != 0.0f32 ? 1.0f32 / @direction.y : Float32::MAX,
          @direction.z != 0.0f32 ? 1.0f32 / @direction.z : Float32::MAX
        )

        t1 = (aabb.min.x - @origin.x) * inv_dir.x
        t2 = (aabb.max.x - @origin.x) * inv_dir.x
        t3 = (aabb.min.y - @origin.y) * inv_dir.y
        t4 = (aabb.max.y - @origin.y) * inv_dir.y
        t5 = (aabb.min.z - @origin.z) * inv_dir.z
        t6 = (aabb.max.z - @origin.z) * inv_dir.z

        tmin = ::Math.max(::Math.max(::Math.min(t1, t2), ::Math.min(t3, t4)), ::Math.min(t5, t6)).to_f32
        tmax = ::Math.min(::Math.min(::Math.max(t1, t2), ::Math.max(t3, t4)), ::Math.max(t5, t6)).to_f32

        return nil if tmax < 0.0f32
        return nil if tmin > tmax

        tmin >= 0.0f32 ? tmin : tmax
      end

      # Ray-sphere intersection
      # Returns distance t, or nil if no hit
      def intersects_sphere?(center : Vector3, radius : Float32) : Float32?
        oc = @origin - center
        a = @direction.dot(@direction)
        b = 2.0f32 * oc.dot(@direction)
        c = oc.dot(oc) - radius * radius
        discriminant = b * b - 4.0f32 * a * c

        return nil if discriminant < 0.0f32

        sqrt_disc = ::Math.sqrt(discriminant).to_f32
        t = (-b - sqrt_disc) / (2.0f32 * a)
        return t if t > 0.0f32

        t = (-b + sqrt_disc) / (2.0f32 * a)
        t > 0.0f32 ? t : nil
      end

      # Ray-plane intersection
      # Returns distance t, or nil if parallel
      def intersects_plane?(plane_normal : Vector3, plane_point : Vector3) : Float32?
        denom = plane_normal.dot(@direction)
        return nil if denom.abs < 0.0001f32

        t = (plane_point - @origin).dot(plane_normal) / denom
        t >= 0.0f32 ? t : nil
      end
    end
  end
end
