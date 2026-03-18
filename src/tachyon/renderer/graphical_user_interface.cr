module Tachyon
  module Renderer
    class GraphicalUserInterface
      Log = ::Log.for(self)

      @shader : Shader
      @quad_vao : LibGL::GLuint = 0_u32
      @quad_vbo : LibGL::GLuint = 0_u32
      @font : Font
      @projection : Math::Matrix4 = Math::Matrix4.identity

      QUAD_VERTS = StaticArray[
        0.0f32, 0.0f32, 0.0f32, 0.0f32,
        1.0f32, 0.0f32, 1.0f32, 0.0f32,
        1.0f32, 1.0f32, 1.0f32, 1.0f32,
        0.0f32, 0.0f32, 0.0f32, 0.0f32,
        1.0f32, 1.0f32, 1.0f32, 1.0f32,
        0.0f32, 1.0f32, 0.0f32, 1.0f32,
      ]

      def initialize
        @shader = Shader.from_file("gui")
        @font = Font.new
        setup_quad
      end

      def begin_frame(viewport_width : Int32, viewport_height : Int32)
        @projection = Math::Matrix4.orthographic(
          0.0f32, viewport_width.to_f32,
          viewport_height.to_f32, 0.0f32,
          -1.0f32, 1.0f32
        )

        LibGL.glDisable(LibGL::GL_DEPTH_TEST)
        LibGL.glDisable(LibGL::GL_CULL_FACE)
        LibGL.glEnable(LibGL::GL_BLEND)
        LibGL.glBlendFunc(LibGL::GL_SRC_ALPHA, LibGL::GL_ONE_MINUS_SRC_ALPHA)

        @shader.use
        @shader.set_matrix4("uProjection", @projection)
      end

      def end_frame
        LibGL.glDisable(LibGL::GL_BLEND)
        LibGL.glEnable(LibGL::GL_DEPTH_TEST)
        LibGL.glEnable(LibGL::GL_CULL_FACE)
      end

      def draw_rect(x : Float32, y : Float32, w : Float32, h : Float32,
                    r : Float32 = 1.0f32, g : Float32 = 1.0f32, b : Float32 = 1.0f32, a : Float32 = 1.0f32)
        @shader.use
        @shader.set_vector2("uPosition", x, y)
        @shader.set_vector2("uSize", w, h)
        @shader.set_color("uColor", r, g, b, a)
        @shader.set_int("uHasTexture", 0)
        @shader.set_int("uIsText", 0)

        loc_pos = LibGL.glGetUniformLocation(@shader.program, "uPosition")
        loc_size = LibGL.glGetUniformLocation(@shader.program, "uSize")
        loc_color = LibGL.glGetUniformLocation(@shader.program, "uColor")
        loc_proj = LibGL.glGetUniformLocation(@shader.program, "uProjection")

        LibGL.glBindVertexArray(@quad_vao)
        LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 6)
        LibGL.glBindVertexArray(0)
      end

      def draw_text(text : String, x : Float32, y : Float32, scale : Float32 = 2.0f32,
                    r : Float32 = 1.0f32, g : Float32 = 1.0f32, b : Float32 = 1.0f32, a : Float32 = 1.0f32)
        @shader.use
        @shader.set_int("uHasTexture", 1)
        @shader.set_int("uIsText", 1)
        @shader.set_color("uColor", r, g, b, a)

        LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @font.texture_id)
        @shader.set_int("uTexture", 0)

        char_w = @font.char_width.to_f32 * scale
        char_h = @font.char_height.to_f32 * scale
        cursor_x = x

        text.each_char do |c|
          u0, v0, u1, v1 = @font.char_uv(c)

          # Update quad UVs for this character
          char_verts = StaticArray[
            0.0f32, 0.0f32, u0, v0,
            1.0f32, 0.0f32, u1, v0,
            1.0f32, 1.0f32, u1, v1,
            0.0f32, 0.0f32, u0, v0,
            1.0f32, 1.0f32, u1, v1,
            0.0f32, 1.0f32, u0, v1,
          ]

          LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @quad_vbo)
          LibGL.glBufferData(LibGL::GL_ARRAY_BUFFER,
            char_verts.size.to_i64 * sizeof(Float32),
            char_verts.to_unsafe.as(Pointer(Void)),
            LibGL::GL_DYNAMIC_DRAW)

          @shader.set_vector2("uPosition", cursor_x, y)
          @shader.set_vector2("uSize", char_w, char_h)

          LibGL.glBindVertexArray(@quad_vao)
          LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 6)

          cursor_x += char_w
        end

        LibGL.glBindVertexArray(0)
      end

      def destroy
        @shader.destroy
        @font.destroy
        LibGL.glDeleteVertexArrays(1, pointerof(@quad_vao))
        LibGL.glDeleteBuffers(1, pointerof(@quad_vbo))
      end

      private def setup_quad
        LibGL.glGenVertexArrays(1, pointerof(@quad_vao))
        LibGL.glBindVertexArray(@quad_vao)
        LibGL.glGenBuffers(1, pointerof(@quad_vbo))
        LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @quad_vbo)
        LibGL.glBufferData(LibGL::GL_ARRAY_BUFFER,
          QUAD_VERTS.size.to_i64 * sizeof(Float32),
          QUAD_VERTS.to_unsafe.as(Pointer(Void)),
          LibGL::GL_DYNAMIC_DRAW)
        LibGL.glEnableVertexAttribArray(0)
        LibGL.glVertexAttribPointer(0, 2, LibGL::GL_FLOAT, LibGL::GL_FALSE, 4 * sizeof(Float32), Pointer(Void).null)
        LibGL.glEnableVertexAttribArray(1)
        LibGL.glVertexAttribPointer(1, 2, LibGL::GL_FLOAT, LibGL::GL_FALSE, 4 * sizeof(Float32), Pointer(Void).new(2_u64 * sizeof(Float32)))
        LibGL.glBindVertexArray(0)
      end
    end
  end
end
