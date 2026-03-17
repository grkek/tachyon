module Tachyon
  module Math
    struct AABB
      property min : Vector3
      property max : Vector3

      def initialize(@min : Vector3 = Vector3.zero, @max : Vector3 = Vector3.zero)
      end

      def self.from_center_size(center : Vector3, size : Vector3) : AABB
        half = size * 0.5f32
        AABB.new(center - half, center + half)
      end

      def intersects?(other : AABB) : Bool
        @min.x <= other.max.x && @max.x >= other.min.x &&
          @min.y <= other.max.y && @max.y >= other.min.y &&
          @min.z <= other.max.z && @max.z >= other.min.z
      end

      def contains?(point : Vector3) : Bool
        point.x >= @min.x && point.x <= @max.x &&
          point.y >= @min.y && point.y <= @max.y &&
          point.z >= @min.z && point.z <= @max.z
      end

      def center : Vector3
        (@min + @max) * 0.5f32
      end

      def size : Vector3
        @max - @min
      end

      def expand(point : Vector3) : AABB
        AABB.new(
          Vector3.new(
            ::Math.min(@min.x, point.x).to_f32,
            ::Math.min(@min.y, point.y).to_f32,
            ::Math.min(@min.z, point.z).to_f32
          ),
          Vector3.new(
            ::Math.max(@max.x, point.x).to_f32,
            ::Math.max(@max.y, point.y).to_f32,
            ::Math.max(@max.z, point.z).to_f32
          )
        )
      end
    end
  end
end
