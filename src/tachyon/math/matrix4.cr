module Tachyon
  module Math
    struct Matrix4
      # Column-major storage (OpenGL convention)
      # Layout: [col0.x, col0.y, col0.z, col0.w, col1.x, col1.y, ...]
      getter data : StaticArray(Float32, 16)

      def initialize
        @data = StaticArray(Float32, 16).new(0.0f32)
      end

      def initialize(@data : StaticArray(Float32, 16))
      end

      # Element access: [column, row]
      def [](col : Int32, row : Int32) : Float32
        @data[col * 4 + row]
      end

      def []=(col : Int32, row : Int32, value : Float32)
        @data[col * 4 + row] = value
      end

      # Identity matrix
      def self.identity : Matrix4
        m = Matrix4.new
        m.data[0] = 1.0f32
        m.data[5] = 1.0f32
        m.data[10] = 1.0f32
        m.data[15] = 1.0f32
        m
      end

      # Matrix multiplication
      def *(other : Matrix4) : Matrix4
        result = Matrix4.new
        4.times do |col|
          4.times do |row|
            sum = 0.0f32
            4.times do |k|
              sum += self[k, row] * other[col, k]
            end
            result[col, row] = sum
          end
        end
        result
      end

      # Vector4 multiplication
      def *(v : Vector4) : Vector4
        Vector4.new(
          @data[0] * v.x + @data[4] * v.y + @data[8] * v.z + @data[12] * v.w,
          @data[1] * v.x + @data[5] * v.y + @data[9] * v.z + @data[13] * v.w,
          @data[2] * v.x + @data[6] * v.y + @data[10] * v.z + @data[14] * v.w,
          @data[3] * v.x + @data[7] * v.y + @data[11] * v.z + @data[15] * v.w,
        )
      end

      # Transform a Vector3 as a point (w=1)
      def transform_point(point : Vector3) : Vector3
        x = @data[0] * point.x + @data[4] * point.y + @data[8] * point.z + @data[12]
        y = @data[1] * point.x + @data[5] * point.y + @data[9] * point.z + @data[13]
        z = @data[2] * point.x + @data[6] * point.y + @data[10] * point.z + @data[14]
        w = @data[3] * point.x + @data[7] * point.y + @data[11] * point.z + @data[15]
        if w != 0.0f32 && w != 1.0f32
          Vector3.new(x / w, y / w, z / w)
        else
          Vector3.new(x, y, z)
        end
      end

      # Transform a Vector3 as a direction (w=0)
      def transform_direction(v : Vector3) : Vector3
        x = self[0, 0] * v.x + self[1, 0] * v.y + self[2, 0] * v.z
        y = self[0, 1] * v.x + self[1, 1] * v.y + self[2, 1] * v.z
        z = self[0, 2] * v.x + self[1, 2] * v.y + self[2, 2] * v.z
        Vector3.new(x, y, z)
      end

      # Translation matrix

      def self.translation(x : Float32, y : Float32, z : Float32) : Matrix4
        m = identity
        m[3, 0] = x
        m[3, 1] = y
        m[3, 2] = z
        m
      end

      def self.translation(v : Vector3) : Matrix4
        translation(v.x, v.y, v.z)
      end

      # Scale matrix

      def self.scale(x : Float32, y : Float32, z : Float32) : Matrix4
        m = Matrix4.new
        m[0, 0] = x
        m[1, 1] = y
        m[2, 2] = z
        m[3, 3] = 1.0f32
        m
      end

      def self.scale(v : Vector3) : Matrix4
        scale(v.x, v.y, v.z)
      end

      # Rotation around X axis
      def self.rotation_x(angle_rad : Float32) : Matrix4
        c = ::Math.cos(angle_rad).to_f32
        s = ::Math.sin(angle_rad).to_f32
        m = identity
        m[1, 1] = c
        m[2, 1] = -s
        m[1, 2] = s
        m[2, 2] = c
        m
      end

      # Rotation around Y axis
      def self.rotation_y(angle_rad : Float32) : Matrix4
        c = ::Math.cos(angle_rad).to_f32
        s = ::Math.sin(angle_rad).to_f32
        m = identity
        m[0, 0] = c
        m[2, 0] = s
        m[0, 2] = -s
        m[2, 2] = c
        m
      end

      # Rotation around Z axis
      def self.rotation_z(angle_rad : Float32) : Matrix4
        c = ::Math.cos(angle_rad).to_f32
        s = ::Math.sin(angle_rad).to_f32
        m = identity
        m[0, 0] = c
        m[1, 0] = -s
        m[0, 1] = s
        m[1, 1] = c
        m
      end

      # Perspective projection (symmetric frustum)
      def self.perspective(fov_rad : Float32, aspect : Float32, near : Float32, far : Float32) : Matrix4
        tan_half_fov = ::Math.tan(fov_rad / 2.0f32).to_f32
        m = Matrix4.new
        m[0, 0] = 1.0f32 / (aspect * tan_half_fov)
        m[1, 1] = 1.0f32 / tan_half_fov
        m[2, 2] = -(far + near) / (far - near)
        m[2, 3] = -1.0f32
        m[3, 2] = -(2.0f32 * far * near) / (far - near)
        m
      end

      # Orthographic projection
      def self.orthographic(left : Float32, right : Float32, bottom : Float32, top : Float32, near : Float32, far : Float32) : Matrix4
        m = Matrix4.new
        m[0, 0] = 2.0f32 / (right - left)
        m[1, 1] = 2.0f32 / (top - bottom)
        m[2, 2] = -2.0f32 / (far - near)
        m[3, 0] = -(right + left) / (right - left)
        m[3, 1] = -(top + bottom) / (top - bottom)
        m[3, 2] = -(far + near) / (far - near)
        m[3, 3] = 1.0f32
        m
      end

      # Look-at view matrix
      def self.look_at(eye : Vector3, target : Vector3, up : Vector3) : Matrix4
        f = (target - eye).normalize # Forward
        s = f.cross(up).normalize    # Right
        u = s.cross(f)               # Up (recalculated)

        m = identity
        m[0, 0] = s.x
        m[1, 0] = s.y
        m[2, 0] = s.z
        m[0, 1] = u.x
        m[1, 1] = u.y
        m[2, 1] = u.z
        m[0, 2] = -f.x
        m[1, 2] = -f.y
        m[2, 2] = -f.z
        m[3, 0] = -s.dot(eye)
        m[3, 1] = -u.dot(eye)
        m[3, 2] = f.dot(eye)
        m
      end

      def inverse : Matrix4
        m = @data
        a00 = m[0]; a01 = m[1]; a02 = m[2]; a03 = m[3]
        a10 = m[4]; a11 = m[5]; a12 = m[6]; a13 = m[7]
        a20 = m[8]; a21 = m[9]; a22 = m[10]; a23 = m[11]
        a30 = m[12]; a31 = m[13]; a32 = m[14]; a33 = m[15]

        b00 = a00 * a11 - a01 * a10
        b01 = a00 * a12 - a02 * a10
        b02 = a00 * a13 - a03 * a10
        b03 = a01 * a12 - a02 * a11
        b04 = a01 * a13 - a03 * a11
        b05 = a02 * a13 - a03 * a12
        b06 = a20 * a31 - a21 * a30
        b07 = a20 * a32 - a22 * a30
        b08 = a20 * a33 - a23 * a30
        b09 = a21 * a32 - a22 * a31
        b10 = a21 * a33 - a23 * a31
        b11 = a22 * a33 - a23 * a32

        det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06
        return Matrix4.identity if det.abs < 0.000001f32

        inv_det = 1.0f32 / det

        result = StaticArray(Float32, 16).new(0.0f32)
        result[0] = (a11 * b11 - a12 * b10 + a13 * b09) * inv_det
        result[1] = (a02 * b10 - a01 * b11 - a03 * b09) * inv_det
        result[2] = (a31 * b05 - a32 * b04 + a33 * b03) * inv_det
        result[3] = (a22 * b04 - a21 * b05 - a23 * b03) * inv_det
        result[4] = (a12 * b08 - a10 * b11 - a13 * b07) * inv_det
        result[5] = (a00 * b11 - a02 * b08 + a03 * b07) * inv_det
        result[6] = (a32 * b02 - a30 * b05 - a33 * b01) * inv_det
        result[7] = (a20 * b05 - a22 * b02 + a23 * b01) * inv_det
        result[8] = (a10 * b10 - a11 * b08 + a13 * b06) * inv_det
        result[9] = (a01 * b08 - a00 * b10 - a03 * b06) * inv_det
        result[10] = (a30 * b04 - a31 * b02 + a33 * b00) * inv_det
        result[11] = (a21 * b02 - a20 * b04 - a23 * b00) * inv_det
        result[12] = (a11 * b07 - a10 * b09 - a12 * b06) * inv_det
        result[13] = (a00 * b09 - a01 * b07 + a02 * b06) * inv_det
        result[14] = (a31 * b01 - a30 * b03 - a32 * b00) * inv_det
        result[15] = (a20 * b03 - a21 * b01 + a22 * b00) * inv_det

        Matrix4.new(result)
      end

      # Raw pointer for OpenGL uniform uploads
      def to_unsafe : Pointer(Float32)
        @data.to_unsafe
      end

      def to_s(io : IO) : Nil
        io << "Matrix4[\n"
        4.times do |row|
          io << "  "
          4.times do |col|
            io << sprintf("%.4f", self[col, row])
            io << ", " unless col == 3
          end
          io << "\n"
        end
        io << "]"
      end
    end
  end
end
