module Tachyon
  module Renderer
    class InstancedMesh
      Log = ::Log.for(self)

      getter mesh : Mesh
      getter material : Material
      getter instance_count : Int32 = 0

      @instance_vbo : LibGL::GLuint = 0_u32
      @max_instances : Int32
      @instance_matrices : Array(Float32)

      # Each instance stores a 4x4 model matrix = 16 floats
      FLOATS_PER_INSTANCE = 16

      def initialize(@mesh : Mesh, @material : Material, @max_instances : Int32 = 1024)
        @instance_matrices = Array(Float32).new(@max_instances * FLOATS_PER_INSTANCE, 0.0f32)
        setup_instance_buffer
      end

      def set_instance_matrix(index : Int32, matrix : Math::Matrix4)
        return if index < 0 || index >= @max_instances
        offset = index * FLOATS_PER_INSTANCE
        16.times do |i|
          @instance_matrices[offset + i] = matrix.to_unsafe[i]
        end
      end

      def set_instance_count(@instance_count : Int32)
        @instance_count = @instance_count.clamp(0, @max_instances)
      end

      def upload
        return if @instance_count <= 0

        LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @instance_vbo)
        upload_size = @instance_count.to_i64 * FLOATS_PER_INSTANCE * sizeof(Float32)
        LibGL.glBufferSubData(LibGL::GL_ARRAY_BUFFER, 0, upload_size,
          @instance_matrices.to_unsafe.as(Pointer(Void)))
      end

      def draw(shader : Shader)
        return if @instance_count <= 0

        @material.apply(shader)

        LibGL.glBindVertexArray(@mesh.vao)
        LibGL.glDrawElementsInstanced(
          LibGL::GL_TRIANGLES,
          @mesh.index_count,
          LibGL::GL_UNSIGNED_INT,
          Pointer(Void).null,
          @instance_count
        )
        LibGL.glBindVertexArray(0)
      end

      def destroy
        LibGL.glDeleteBuffers(1, pointerof(@instance_vbo))
      end

      private def setup_instance_buffer
        LibGL.glBindVertexArray(@mesh.vao)

        LibGL.glGenBuffers(1, pointerof(@instance_vbo))
        LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @instance_vbo)
        LibGL.glBufferData(LibGL::GL_ARRAY_BUFFER,
          @max_instances.to_i64 * FLOATS_PER_INSTANCE * sizeof(Float32),
          Pointer(Void).null,
          LibGL::GL_DYNAMIC_DRAW)

        # Instance model matrix uses attribute locations 5, 6, 7, 8 (one vec4 per row)
        4.times do |row|
          location = 5_u32 + row.to_u32
          LibGL.glEnableVertexAttribArray(location)
          LibGL.glVertexAttribPointer(
            location, 4, LibGL::GL_FLOAT, LibGL::GL_FALSE,
            FLOATS_PER_INSTANCE * sizeof(Float32),
            Pointer(Void).new(row.to_u64 * 4_u64 * sizeof(Float32))
          )
          LibGL.glVertexAttribDivisor(location, 1)
        end

        LibGL.glBindVertexArray(0)
      end
    end
  end
end
