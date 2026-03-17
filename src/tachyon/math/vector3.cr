module Tachyon
  module Math
    struct Vector3
      property x : Float32
      property y : Float32
      property z : Float32

      def initialize(@x : Float32 = 0.0f32, @y : Float32 = 0.0f32, @z : Float32 = 0.0f32)
      end

      def initialize(x : Float64, y : Float64, z : Float64)
        @x = x.to_f32
        @y = y.to_f32
        @z = z.to_f32
      end

      # Arithmetic operators
      def +(other : Vector3) : Vector3
        Vector3.new(@x + other.x, @y + other.y, @z + other.z)
      end

      def -(other : Vector3) : Vector3
        Vector3.new(@x - other.x, @y - other.y, @z - other.z)
      end

      def *(scalar : Float32) : Vector3
        Vector3.new(@x * scalar, @y * scalar, @z * scalar)
      end

      def *(scalar : Float64) : Vector3
        self * scalar.to_f32
      end

      def /(scalar : Float32) : Vector3
        Vector3.new(@x / scalar, @y / scalar, @z / scalar)
      end

      def - : Vector3
        Vector3.new(-@x, -@y, -@z)
      end

      # Vector operations
      def dot(other : Vector3) : Float32
        @x * other.x + @y * other.y + @z * other.z
      end

      def cross(other : Vector3) : Vector3
        Vector3.new(
          @y * other.z - @z * other.y,
          @z * other.x - @x * other.z,
          @x * other.y - @y * other.x
        )
      end

      def magnitude : Float32
        ::Math.sqrt(@x * @x + @y * @y + @z * @z).to_f32
      end

      def magnitude_squared : Float32
        @x * @x + @y * @y + @z * @z
      end

      def normalize : Vector3
        mag = magnitude
        return Vector3.zero if mag == 0.0f32
        self / mag
      end

      def distance(other : Vector3) : Float32
        (self - other).magnitude
      end

      def self.lerp(a : Vector3, b : Vector3, t : Float32) : Vector3
        a + (b - a) * t
      end

      # Common constants
      def self.zero : Vector3
        Vector3.new(0.0f32, 0.0f32, 0.0f32)
      end

      def self.one : Vector3
        Vector3.new(1.0f32, 1.0f32, 1.0f32)
      end

      def self.up : Vector3
        Vector3.new(0.0f32, 1.0f32, 0.0f32)
      end

      def self.right : Vector3
        Vector3.new(1.0f32, 0.0f32, 0.0f32)
      end

      def self.forward : Vector3
        Vector3.new(0.0f32, 0.0f32, -1.0f32)
      end

      # Conversion
      def to_a : StaticArray(Float32, 3)
        StaticArray[x, y, z]
      end

      def to_s(io : IO) : Nil
        io << "Vector3(#{@x}, #{@y}, #{@z})"
      end
    end
  end
end
