module Tachyon
  module Renderer
    class Skybox
      Log = ::Log.for(self)

      getter cubemap_id : LibGL::GLuint = 0_u32
      @vao : LibGL::GLuint = 0_u32
      @vbo : LibGL::GLuint = 0_u32
      @shader : Shader

      # Unit cube vertices (inside faces)
      VERTICES = StaticArray[
        -1.0f32, 1.0f32, -1.0f32, -1.0f32, -1.0f32, -1.0f32, 1.0f32, -1.0f32, -1.0f32,
        1.0f32, -1.0f32, -1.0f32, 1.0f32, 1.0f32, -1.0f32, -1.0f32, 1.0f32, -1.0f32,
        -1.0f32, -1.0f32, 1.0f32, -1.0f32, -1.0f32, -1.0f32, -1.0f32, 1.0f32, -1.0f32,
        -1.0f32, 1.0f32, -1.0f32, -1.0f32, 1.0f32, 1.0f32, -1.0f32, -1.0f32, 1.0f32,
        1.0f32, -1.0f32, -1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32, 1.0f32, 1.0f32,
        1.0f32, 1.0f32, 1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, -1.0f32, -1.0f32,
        -1.0f32, -1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32, 1.0f32, 1.0f32, 1.0f32,
        1.0f32, 1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, -1.0f32, -1.0f32, 1.0f32,
        -1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32, 1.0f32,
        1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, -1.0f32,
        -1.0f32, -1.0f32, -1.0f32, -1.0f32, -1.0f32, 1.0f32, 1.0f32, -1.0f32, -1.0f32,
        1.0f32, -1.0f32, -1.0f32, -1.0f32, -1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32,
      ]

      def initialize
        @shader = Shader.new(Constants::SKYBOX_VERTEX, Constants::SKYBOX_FRAGMENT)
        setup_mesh
      end

      # Load 6 face images: +X, -X, +Y, -Y, +Z, -Z
      def load_faces(paths : Array(String))
        raise "Skybox requires exactly 6 face images" unless paths.size == 6

        LibGL.glGenTextures(1, pointerof(@cubemap_id))
        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @cubemap_id)

        LibSTBI.stbi_set_flip_vertically_on_load(0) # Cubemaps are NOT flipped

        paths.each_with_index do |path, i|
          w = 0; h = 0; ch = 0
          data = LibSTBI.stbi_load(path, pointerof(w), pointerof(h), pointerof(ch), 3)
          raise "Failed to load skybox face: #{path}" unless data

          LibGL.glTexImage2D(
            LibGL::GL_TEXTURE_CUBE_MAP_POSITIVE_X + i.to_u32,
            0, LibGL::GL_SRGB8.to_i32,
            w, h, 0,
            LibGL::GL_RGB, LibGL::GL_UNSIGNED_BYTE,
            data.as(Pointer(Void))
          )
          LibSTBI.stbi_image_free(data.as(Pointer(Void)))
        end

        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_R, LibGL::GL_CLAMP_TO_EDGE.to_i32)

        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, 0)
      end

      # Generate a simple gradient skybox procedurally
      def generate_gradient(top_color : Math::Vector3, bottom_color : Math::Vector3, size : Int32 = 64)
        LibGL.glGenTextures(1, pointerof(@cubemap_id))
        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @cubemap_id)

        pixels = Bytes.new(size * size * 3)

        6.times do |face|
          (0...size).each do |y|
            (0...size).each do |x|
              # Map y to 0..1 based on face
              t = case face
                  when 2 then 1.0f32 # +Y top
                  when 3 then 0.0f32 # -Y bottom
                  else        y.to_f32 / (size - 1).to_f32
                  end
              t = 1.0f32 - t # flip: top of image = top of sky

              r = (bottom_color.x + (top_color.x - bottom_color.x) * t).clamp(0.0f32, 1.0f32)
              g = (bottom_color.y + (top_color.y - bottom_color.y) * t).clamp(0.0f32, 1.0f32)
              b = (bottom_color.z + (top_color.z - bottom_color.z) * t).clamp(0.0f32, 1.0f32)

              idx = (y * size + x) * 3
              pixels[idx] = (r * 255).to_u8
              pixels[idx + 1] = (g * 255).to_u8
              pixels[idx + 2] = (b * 255).to_u8
            end
          end

          LibGL.glTexImage2D(
            LibGL::GL_TEXTURE_CUBE_MAP_POSITIVE_X + face.to_u32,
            0, LibGL::GL_RGB8.to_i32,
            size, size, 0,
            LibGL::GL_RGB, LibGL::GL_UNSIGNED_BYTE,
            pixels.to_unsafe.as(Pointer(Void))
          )
        end

        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_R, LibGL::GL_CLAMP_TO_EDGE.to_i32)

        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, 0)
      end

      def render(view : Math::Matrix4, projection : Math::Matrix4)
        LibGL.glDepthFunc(LibGL::GL_LEQUAL)
        @shader.use
        @shader.set_matrix4("uView", view)
        @shader.set_matrix4("uProjection", projection)

        LibGL.glBindVertexArray(@vao)
        LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @cubemap_id)
        @shader.set_int("uSkybox", 0)
        LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 36)
        LibGL.glBindVertexArray(0)

        LibGL.glDepthFunc(LibGL::GL_LESS)
      end

      def destroy
        @shader.destroy
        LibGL.glDeleteVertexArrays(1, pointerof(@vao))
        LibGL.glDeleteBuffers(1, pointerof(@vbo))
        LibGL.glDeleteTextures(1, pointerof(@cubemap_id)) if @cubemap_id != 0
      end

      private def setup_mesh
        LibGL.glGenVertexArrays(1, pointerof(@vao))
        LibGL.glBindVertexArray(@vao)

        LibGL.glGenBuffers(1, pointerof(@vbo))
        LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @vbo)
        LibGL.glBufferData(
          LibGL::GL_ARRAY_BUFFER,
          VERTICES.size.to_i64 * sizeof(Float32),
          VERTICES.to_unsafe.as(Pointer(Void)),
          LibGL::GL_STATIC_DRAW
        )

        LibGL.glEnableVertexAttribArray(0)
        LibGL.glVertexAttribPointer(0, 3, LibGL::GL_FLOAT, LibGL::GL_FALSE, 3 * sizeof(Float32), Pointer(Void).null)

        LibGL.glBindVertexArray(0)
      end
    end
  end
end
