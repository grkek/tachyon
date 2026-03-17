module Tachyon
  module Renderer
    class Canvas
      Log = ::Log.for(self)

      @shader : Shader
      @quad_vao : LibGL::GLuint = 0_u32
      @quad_vbo : LibGL::GLuint = 0_u32
      @font : Font
      @sprites : Array(Sprite) = [] of Sprite
      @projection : Math::Matrix4 = Math::Matrix4.identity
      @bg_r : Float32 = 0.0f32
      @bg_g : Float32 = 0.0f32
      @bg_b : Float32 = 0.0f32
      @bg_a : Float32 = 1.0f32
      @canvas_width : Float32 = 1280.0f32
      @canvas_height : Float32 = 720.0f32
      @active : Bool = false
      @default_texture : Texture

      getter active : Bool

      QUAD_VERTS = StaticArray[
        0.0f32, 0.0f32, 0.0f32, 0.0f32,
        1.0f32, 0.0f32, 1.0f32, 0.0f32,
        1.0f32, 1.0f32, 1.0f32, 1.0f32,
        0.0f32, 0.0f32, 0.0f32, 0.0f32,
        1.0f32, 1.0f32, 1.0f32, 1.0f32,
        0.0f32, 1.0f32, 0.0f32, 1.0f32,
      ]

      def initialize
        @shader = Shader.new(Constants::GUI_VERTEX_SHADER, Constants::GUI_FRAGMENT_SHADER)
        @font = Font.new
        @default_texture = Texture.solid_color(255_u8, 255_u8, 255_u8, 255_u8)
        setup_quad
      end

      def setup(width : Float32, height : Float32)
        @canvas_width = width
        @canvas_height = height
        @active = true
        @projection = Math::Matrix4.orthographic(
          0.0f32, width,
          height, 0.0f32,
          -1000.0f32, 1000.0f32
        )
      end

      def background(r : Float32, g : Float32, b : Float32, a : Float32 = 1.0f32)
        @bg_r = r; @bg_g = g; @bg_b = b; @bg_a = a
      end

      def add_sprite(sprite : Sprite)
        @sprites << sprite
      end

      def remove_sprite(sprite : Sprite)
        @sprites.delete(sprite)
      end

      def render(viewport_width : Int32, viewport_height : Int32)
        return unless @active

        LibGL.glDisable(LibGL::GL_DEPTH_TEST)
        LibGL.glDisable(LibGL::GL_CULL_FACE)
        LibGL.glEnable(LibGL::GL_BLEND)
        LibGL.glBlendFunc(LibGL::GL_SRC_ALPHA, LibGL::GL_ONE_MINUS_SRC_ALPHA)

        LibGL.glViewport(0, 0, viewport_width, viewport_height)
        LibGL.glClearColor(@bg_r, @bg_g, @bg_b, @bg_a)
        LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)

        @shader.use
        @shader.set_matrix4("uProjection", @projection)

        sorted = @sprites.sort_by(&.layer)
        sorted.each do |sprite|
          next unless sprite.visible
          draw_sprite(sprite)
        end

        LibGL.glDisable(LibGL::GL_BLEND)
        LibGL.glEnable(LibGL::GL_DEPTH_TEST)
        LibGL.glEnable(LibGL::GL_CULL_FACE)
      end

      def draw_text(text : String, x : Float32, y : Float32, scale : Float32 = 2.0f32,
                    r : Float32 = 1.0f32, g : Float32 = 1.0f32, b : Float32 = 1.0f32, a : Float32 = 1.0f32)
        @shader.use
        @shader.set_matrix4("uProjection", @projection)
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
        @default_texture.destroy
        LibGL.glDeleteVertexArrays(1, pointerof(@quad_vao))
        LibGL.glDeleteBuffers(1, pointerof(@quad_vbo))
      end

      private def draw_sprite(sprite : Sprite)
        w = sprite.width * sprite.scale_x
        h = sprite.height * sprite.scale_y

        if tex = sprite.texture
          tex.bind(0)
          @shader.set_int("uHasTexture", 1)
        else
          @default_texture.bind(0)
          @shader.set_int("uHasTexture", 0)
        end

        @shader.set_int("uIsText", 0)
        @shader.set_int("uTexture", 0)
        @shader.set_vector2("uPosition", sprite.x, sprite.y)
        @shader.set_vector2("uSize", w, h)
        @shader.set_color("uColor", sprite.r, sprite.g, sprite.b, sprite.a)

        # Reset UVs to full quad
        full_verts = QUAD_VERTS
        LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @quad_vbo)
        LibGL.glBufferData(LibGL::GL_ARRAY_BUFFER,
          full_verts.size.to_i64 * sizeof(Float32),
          full_verts.to_unsafe.as(Pointer(Void)),
          LibGL::GL_DYNAMIC_DRAW)

        LibGL.glBindVertexArray(@quad_vao)
        LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 6)
        LibGL.glBindVertexArray(0)
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
