module Tachyon
  module Renderer
    class Mesh
      Log = ::Log.for(self)

      getter vao : LibGL::GLuint = 0_u32
      getter vbo : LibGL::GLuint = 0_u32
      getter ebo : LibGL::GLuint = 0_u32
      getter index_count : Int32 = 0
      getter vertex_count : Int32 = 0
      getter vertices : Array(Float32)
      getter indices : Array(UInt32)
      getter stride : Int32
      getter bounds_min : Math::Vector3 = Math::Vector3.zero
      getter bounds_max : Math::Vector3 = Math::Vector3.zero

      @indexed : Bool = false
      @has_uvs : Bool = false

      STRIDE_UV    = 8 * sizeof(Float32)
      STRIDE_NO_UV = 6 * sizeof(Float32)

      def initialize(@vertices : Array(Float32), @indices : Array(UInt32), *, has_uvs : Bool)
        @indexed = true
        @has_uvs = has_uvs
        @stride = has_uvs ? 8 : 6
        @vertex_count = @vertices.size // @stride
        @index_count = @indices.size

        compute_bounds
        setup_gpu_buffers
      end

      def initialize(@vertices : Array(Float32), @indices : Array(UInt32))
        @indexed = true
        @has_uvs = false
        @stride = 6
        @vertex_count = @vertices.size // @stride
        @index_count = @indices.size

        compute_bounds
        setup_gpu_buffers
      end

      def initialize(@vertices : Array(Float32))
        @indexed = false
        @has_uvs = false
        @stride = 6
        @indices = [] of UInt32
        @vertex_count = @vertices.size // @stride
        @index_count = 0

        compute_bounds
        setup_gpu_buffers
      end

      def draw
        LibGL.glBindVertexArray(@vao)
        if @indexed
          LibGL.glDrawElements(LibGL::GL_TRIANGLES, @index_count, LibGL::GL_UNSIGNED_INT, Pointer(Void).null)
        else
          LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, @vertex_count)
        end
        LibGL.glBindVertexArray(0)
      end

      def raycast(ray_origin : Math::Vector3, ray_dir : Math::Vector3, model_matrix : Math::Matrix4) : Float32?
        return nil if @indices.empty?

        inverse = model_matrix.inverse

        local_origin = inverse.transform_point(ray_origin)
        local_end = inverse.transform_point(ray_origin + ray_dir)
        local_dir = (local_end - local_origin).normalize

        closest : Float32? = nil

        tri = 0
        while tri < @indices.size
          i0 = @indices[tri].to_i * @stride
          i1 = @indices[tri + 1].to_i * @stride
          i2 = @indices[tri + 2].to_i * @stride

          v0 = Math::Vector3.new(@vertices[i0], @vertices[i0 + 1], @vertices[i0 + 2])
          v1 = Math::Vector3.new(@vertices[i1], @vertices[i1 + 1], @vertices[i1 + 2])
          v2 = Math::Vector3.new(@vertices[i2], @vertices[i2 + 1], @vertices[i2 + 2])

          t = ray_triangle_intersection(local_origin, local_dir, v0, v1, v2)
          if t
            if closest.nil? || t < closest.not_nil!
              closest = t
            end
          end

          tri += 3
        end

        closest
      end

      def destroy
        LibGL.glDeleteBuffers(1, pointerof(@vbo))
        LibGL.glDeleteBuffers(1, pointerof(@ebo)) if @indexed
        LibGL.glDeleteVertexArrays(1, pointerof(@vao))
      end

      private def compute_bounds
        return if @vertices.empty?

        min_x = Float32::MAX
        min_y = Float32::MAX
        min_z = Float32::MAX
        max_x = -Float32::MAX
        max_y = -Float32::MAX
        max_z = -Float32::MAX

        i = 0
        while i < @vertices.size
          x = @vertices[i]
          y = @vertices[i + 1]
          z = @vertices[i + 2]

          min_x = x if x < min_x
          min_y = y if y < min_y
          min_z = z if z < min_z
          max_x = x if x > max_x
          max_y = y if y > max_y
          max_z = z if z > max_z

          i += @stride
        end

        @bounds_min = Math::Vector3.new(min_x, min_y, min_z)
        @bounds_max = Math::Vector3.new(max_x, max_y, max_z)
      end

      private def ray_triangle_intersection(origin : Math::Vector3, dir : Math::Vector3,
                                            v0 : Math::Vector3, v1 : Math::Vector3, v2 : Math::Vector3) : Float32?
        epsilon = 0.000001f32

        edge1 = v1 - v0
        edge2 = v2 - v0
        h = dir.cross(edge2)
        a = edge1.dot(h)

        return nil if a > -epsilon && a < epsilon

        f = 1.0f32 / a
        s = origin - v0
        u = f * s.dot(h)
        return nil if u < 0.0f32 || u > 1.0f32

        q = s.cross(edge1)
        v = f * dir.dot(q)
        return nil if v < 0.0f32 || u + v > 1.0f32

        t = f * edge2.dot(q)
        return nil if t < epsilon

        t
      end

      private def setup_gpu_buffers
        LibGL.glGenVertexArrays(1, pointerof(@vao))
        LibGL.glBindVertexArray(@vao)

        LibGL.glGenBuffers(1, pointerof(@vbo))
        LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @vbo)
        LibGL.glBufferData(
          LibGL::GL_ARRAY_BUFFER,
          @vertices.size.to_i64 * sizeof(Float32),
          @vertices.to_unsafe.as(Pointer(Void)),
          LibGL::GL_STATIC_DRAW
        )

        if @indexed
          LibGL.glGenBuffers(1, pointerof(@ebo))
          LibGL.glBindBuffer(LibGL::GL_ELEMENT_ARRAY_BUFFER, @ebo)
          LibGL.glBufferData(
            LibGL::GL_ELEMENT_ARRAY_BUFFER,
            @indices.size.to_i64 * sizeof(UInt32),
            @indices.to_unsafe.as(Pointer(Void)),
            LibGL::GL_STATIC_DRAW
          )
        end

        setup_attributes
        LibGL.glBindVertexArray(0)
      end

      private def setup_attributes
        stride = @has_uvs ? STRIDE_UV : STRIDE_NO_UV

        LibGL.glEnableVertexAttribArray(0)
        LibGL.glVertexAttribPointer(0, 3, LibGL::GL_FLOAT, LibGL::GL_FALSE, stride, Pointer(Void).null)

        LibGL.glEnableVertexAttribArray(1)
        LibGL.glVertexAttribPointer(1, 3, LibGL::GL_FLOAT, LibGL::GL_FALSE, stride, Pointer(Void).new(3_u64 * sizeof(Float32)))

        if @has_uvs
          LibGL.glEnableVertexAttribArray(2)
          LibGL.glVertexAttribPointer(2, 2, LibGL::GL_FLOAT, LibGL::GL_FALSE, stride, Pointer(Void).new(6_u64 * sizeof(Float32)))
        end
      end
    end
  end
end
