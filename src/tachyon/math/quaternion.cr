module Tachyon
  module Math
    struct Quaternion
      property x : Float32
      property y : Float32
      property z : Float32
      property w : Float32

      def initialize(@x : Float32 = 0.0f32, @y : Float32 = 0.0f32, @z : Float32 = 0.0f32, @w : Float32 = 1.0f32)
      end

      # Identity (no rotation)
      def self.identity : Quaternion
        Quaternion.new(0.0f32, 0.0f32, 0.0f32, 1.0f32)
      end

      # From axis-angle (angle in radians)
      def self.from_axis_angle(axis : Vector3, angle_rad : Float32) : Quaternion
        half = angle_rad * 0.5f32
        s = ::Math.sin(half).to_f32
        a = axis.normalize
        Quaternion.new(a.x * s, a.y * s, a.z * s, ::Math.cos(half).to_f32)
      end

      # From Euler angles (in radians, applied as Y * X * Z)
      def self.from_euler(x_rad : Float32, y_rad : Float32, z_rad : Float32) : Quaternion
        cx = ::Math.cos(x_rad * 0.5f32).to_f32
        sx = ::Math.sin(x_rad * 0.5f32).to_f32
        cy = ::Math.cos(y_rad * 0.5f32).to_f32
        sy = ::Math.sin(y_rad * 0.5f32).to_f32
        cz = ::Math.cos(z_rad * 0.5f32).to_f32
        sz = ::Math.sin(z_rad * 0.5f32).to_f32

        Quaternion.new(
          sx * cy * cz - cx * sy * sz,
          cx * sy * cz + sx * cy * sz,
          cx * cy * sz - sx * sy * cz,
          cx * cy * cz + sx * sy * sz
        )
      end

      # Quaternion multiplication (combines rotations)
      def *(other : Quaternion) : Quaternion
        Quaternion.new(
          @w * other.x + @x * other.w + @y * other.z - @z * other.y,
          @w * other.y - @x * other.z + @y * other.w + @z * other.x,
          @w * other.z + @x * other.y - @y * other.x + @z * other.w,
          @w * other.w - @x * other.x - @y * other.y - @z * other.z
        )
      end

      # Rotate a vector by this quaternion
      def rotate(v : Vector3) : Vector3
        qv = Vector3.new(@x, @y, @z)
        uv = qv.cross(v)
        uuv = qv.cross(uv)
        v + (uv * @w + uuv) * 2.0f32
      end

      def magnitude : Float32
        ::Math.sqrt(@x * @x + @y * @y + @z * @z + @w * @w).to_f32
      end

      def normalize : Quaternion
        mag = magnitude
        return Quaternion.identity if mag == 0.0f32
        Quaternion.new(@x / mag, @y / mag, @z / mag, @w / mag)
      end

      def conjugate : Quaternion
        Quaternion.new(-@x, -@y, -@z, @w)
      end

      def inverse : Quaternion
        mag_sq = @x * @x + @y * @y + @z * @z + @w * @w
        return Quaternion.identity if mag_sq == 0.0f32
        c = conjugate
        Quaternion.new(c.x / mag_sq, c.y / mag_sq, c.z / mag_sq, c.w / mag_sq)
      end

      # Spherical linear interpolation
      def self.slerp(a : Quaternion, b : Quaternion, t : Float32) : Quaternion
        dot = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w

        # Flip sign if needed for shortest path
        b_adj = dot < 0.0f32 ? Quaternion.new(-b.x, -b.y, -b.z, -b.w) : b
        dot = dot.abs

        # Fall back to lerp for very close quaternions
        if dot > 0.9995f32
          result = Quaternion.new(
            a.x + (b_adj.x - a.x) * t,
            a.y + (b_adj.y - a.y) * t,
            a.z + (b_adj.z - a.z) * t,
            a.w + (b_adj.w - a.w) * t
          )
          return result.normalize
        end

        theta = ::Math.acos(dot).to_f32
        sin_theta = ::Math.sin(theta).to_f32
        wa = ::Math.sin((1.0f32 - t) * theta).to_f32 / sin_theta
        wb = ::Math.sin(t * theta).to_f32 / sin_theta

        Quaternion.new(
          wa * a.x + wb * b_adj.x,
          wa * a.y + wb * b_adj.y,
          wa * a.z + wb * b_adj.z,
          wa * a.w + wb * b_adj.w
        )
      end

      # Convert to a 4x4 rotation matrix
      def to_matrix4 : Matrix4
        xx = @x * @x
        yy = @y * @y
        zz = @z * @z
        xy = @x * @y
        xz = @x * @z
        yz = @y * @z
        wx = @w * @x
        wy = @w * @y
        wz = @w * @z

        m = Matrix4.identity
        m[0, 0] = 1.0f32 - 2.0f32 * (yy + zz)
        m[0, 1] = 2.0f32 * (xy + wz)
        m[0, 2] = 2.0f32 * (xz - wy)
        m[1, 0] = 2.0f32 * (xy - wz)
        m[1, 1] = 1.0f32 - 2.0f32 * (xx + zz)
        m[1, 2] = 2.0f32 * (yz + wx)
        m[2, 0] = 2.0f32 * (xz + wy)
        m[2, 1] = 2.0f32 * (yz - wx)
        m[2, 2] = 1.0f32 - 2.0f32 * (xx + yy)
        m
      end

      def to_s(io : IO) : Nil
        io << "Quaternion(#{@x}, #{@y}, #{@z}, #{@w})"
      end
    end
  end
end
