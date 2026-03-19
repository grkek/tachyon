module Tachyon
  module Math
    struct Vector4
      property x : Float32
      property y : Float32
      property z : Float32
      property w : Float32

      def initialize(@x : Float32 = 0.0f32, @y : Float32 = 0.0f32, @z : Float32 = 0.0f32, @w : Float32 = 0.0f32)
      end

      def to_vector3 : Vector3
        if @w != 0.0f32 && @w != 1.0f32
          Vector3.new(@x / @w, @y / @w, @z / @w)
        else
          Vector3.new(@x, @y, @z)
        end
      end

      # Normalize the plane equation so (x,y,z) is a unit normal
      def normalized_plane : Vector4
        len = ::Math.sqrt(@x * @x + @y * @y + @z * @z).to_f32
        return self if len < 0.000001f32
        inv = 1.0f32 / len
        Vector4.new(@x * inv, @y * inv, @z * inv, @w * inv)
      end
    end
  end
end
