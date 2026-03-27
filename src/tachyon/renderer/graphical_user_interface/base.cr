module Tachyon
  module Renderer
    module GraphicalUserInterface
      class Base
        Log = ::Log.for(self)

        @shader : Shader
        @quad_vao : LibGL::GLuint = 0_u32
        @quad_vbo : LibGL::GLuint = 0_u32
        @font_manager : FontManager
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
          @font_manager = FontManager.new
          setup_quad
        end

        def font_manager : FontManager
          @font_manager
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
          LibGL.glBindVertexArray(@quad_vao)
          LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 6)
          LibGL.glBindVertexArray(0)
        end

        def draw_text(text : String, x : Float32, y : Float32, scale : Float32 = 2.0f32,
                      r : Float32 = 1.0f32, g : Float32 = 1.0f32, b : Float32 = 1.0f32, a : Float32 = 1.0f32,
                      font_id : Int32 = 0)
          if font_id > 0
            draw_text_ttf(text, x, y, scale, r, g, b, a, font_id)
          else
            draw_text_bitmap(text, x, y, scale, r, g, b, a)
          end
        end

        def draw_bevel_raised(x : Float32, y : Float32, w : Float32, h : Float32)
          bw = Theme::BEVEL_WIDTH.to_f32
          lt = Theme::BEVEL_LIGHT
          dk = Theme::BEVEL_DARK

          # Top edges (light)
          draw_rect(x, y, w, 1, lt[0], lt[1], lt[2], 1.0f32)
          draw_rect(x, y + 1, w - 1, 1, lt[0], lt[1], lt[2], 0.5f32)

          # Left edges (light)
          draw_rect(x, y, 1, h, lt[0], lt[1], lt[2], 1.0f32)
          draw_rect(x + 1, y, 1, h - 1, lt[0], lt[1], lt[2], 0.5f32)

          # Bottom edges (dark)
          draw_rect(x, y + h - 1, w, 1, dk[0], dk[1], dk[2], 1.0f32)
          draw_rect(x + 1, y + h - 2, w - 1, 1, dk[0], dk[1], dk[2], 0.5f32)

          # Right edges (dark)
          draw_rect(x + w - 1, y, 1, h, dk[0], dk[1], dk[2], 1.0f32)
          draw_rect(x + w - 2, y + 1, 1, h - 1, dk[0], dk[1], dk[2], 0.5f32)
        end

        def draw_bevel_sunken(x : Float32, y : Float32, w : Float32, h : Float32)
          lt = Theme::BEVEL_LIGHT
          dk = Theme::BEVEL_DARK

          # Top edges (dark for sunken)
          draw_rect(x, y, w, 1, dk[0], dk[1], dk[2], 1.0f32)
          draw_rect(x, y + 1, w - 1, 1, dk[0], dk[1], dk[2], 0.5f32)

          # Left edges (dark for sunken)
          draw_rect(x, y, 1, h, dk[0], dk[1], dk[2], 1.0f32)
          draw_rect(x + 1, y, 1, h - 1, dk[0], dk[1], dk[2], 0.5f32)

          # Bottom edges (light for sunken)
          draw_rect(x, y + h - 1, w, 1, lt[0], lt[1], lt[2], 1.0f32)
          draw_rect(x + 1, y + h - 2, w - 1, 1, lt[0], lt[1], lt[2], 0.5f32)

          # Right edges (light for sunken)
          draw_rect(x + w - 1, y, 1, h, lt[0], lt[1], lt[2], 1.0f32)
          draw_rect(x + w - 2, y + 1, 1, h - 1, lt[0], lt[1], lt[2], 0.5f32)
        end

        def draw_panel(cmd : Scripting::GUI::DrawCall)
          bg = {cmd.r, cmd.g, cmd.b}
          draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, bg[0], bg[1], bg[2], cmd.a)
          draw_bevel_raised(cmd.x, cmd.y, cmd.w, cmd.h)

          if cmd.has_header?
            draw_rect(cmd.x, cmd.y, cmd.w, Theme::HEADER_H.to_f32, cmd.r2, cmd.g2, cmd.b2, cmd.a2)
            draw_bevel_raised(cmd.x, cmd.y, cmd.w, Theme::HEADER_H.to_f32)
            unless cmd.text.empty?
              draw_text(cmd.text, cmd.x + 6, cmd.y + 4, cmd.scale, cmd.r3, cmd.g3, cmd.b3, cmd.a3, cmd.font_id)
            end
          end
        end

        def draw_button(cmd : Scripting::GUI::DrawCall)
          if cmd.active?
            draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, cmd.r2, cmd.g2, cmd.b2, cmd.a)
            draw_bevel_sunken(cmd.x, cmd.y, cmd.w, cmd.h)
            text_offset = 1.0f32
          elsif cmd.hovered?
            bg = Theme::BG_HOVER
            draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, bg[0], bg[1], bg[2], cmd.a)
            draw_bevel_raised(cmd.x, cmd.y, cmd.w, cmd.h)
            text_offset = 0.0f32
          else
            bg = cmd.disabled? ? Theme::BG_DARK : Theme::BG_LIGHT
            draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, bg[0], bg[1], bg[2], cmd.a)
            draw_bevel_raised(cmd.x, cmd.y, cmd.w, cmd.h)
            text_offset = 0.0f32
          end

          unless cmd.text.empty?
            tc = cmd.active? ? Theme::TEXT_DARK : (cmd.disabled? ? Theme::TEXT_DISABLED : Theme::TEXT_PRIMARY)
            char_w = cmd.scale * 7.5f32
            tx = cmd.x + (cmd.w - cmd.text.size * char_w) / 2 + text_offset
            ty = cmd.y + (cmd.h - cmd.scale * 8) / 2 + text_offset
            draw_text(cmd.text, tx, ty, cmd.scale, tc[0], tc[1], tc[2], cmd.a, cmd.font_id)
          end
        end

        def draw_checkbox(cmd : Scripting::GUI::DrawCall)
          sz = Theme::CHECKBOX_SIZE.to_f32

          draw_rect(cmd.x, cmd.y, sz, sz, Theme::BG_DARKER[0], Theme::BG_DARKER[1], Theme::BG_DARKER[2], cmd.a)
          draw_bevel_sunken(cmd.x, cmd.y, sz, sz)

          if cmd.checked?
            m = 3.0f32
            draw_rect(cmd.x + m, cmd.y + m, sz - m * 2, sz - m * 2, cmd.r2, cmd.g2, cmd.b2, cmd.a)
          end

          unless cmd.text.empty?
            tc = cmd.disabled? ? Theme::TEXT_DISABLED : Theme::TEXT_PRIMARY
            draw_text(cmd.text, cmd.x + sz + 6, cmd.y + (sz - cmd.scale * 8) / 2, cmd.scale, tc[0], tc[1], tc[2], cmd.a, cmd.font_id)
          end
        end

        def draw_combobox(cmd : Scripting::GUI::DrawCall)
          draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, Theme::BG_DARKER[0], Theme::BG_DARKER[1], Theme::BG_DARKER[2], cmd.a)
          draw_bevel_sunken(cmd.x, cmd.y, cmd.w, cmd.h)

          arrow_w = Theme::COMBO_ARROW_W.to_f32
          arrow_x = cmd.x + cmd.w - arrow_w
          bg = cmd.hovered? ? Theme::BG_HOVER : Theme::BG_LIGHT
          draw_rect(arrow_x, cmd.y, arrow_w, cmd.h, bg[0], bg[1], bg[2], cmd.a)
          draw_bevel_raised(arrow_x, cmd.y, arrow_w, cmd.h)

          # Arrow indicator (small downward triangle via rects)
          ax = arrow_x + arrow_w / 2 - 3
          ay = cmd.y + cmd.h / 2 - 1
          draw_rect(ax, ay, 7, 1, Theme::TEXT_PRIMARY[0], Theme::TEXT_PRIMARY[1], Theme::TEXT_PRIMARY[2], cmd.a)
          draw_rect(ax + 1, ay + 1, 5, 1, Theme::TEXT_PRIMARY[0], Theme::TEXT_PRIMARY[1], Theme::TEXT_PRIMARY[2], cmd.a)
          draw_rect(ax + 2, ay + 2, 3, 1, Theme::TEXT_PRIMARY[0], Theme::TEXT_PRIMARY[1], Theme::TEXT_PRIMARY[2], cmd.a)

          unless cmd.text.empty?
            tc = Theme::TEXT_PRIMARY
            draw_text(cmd.text, cmd.x + 4, cmd.y + (cmd.h - cmd.scale * 8) / 2, cmd.scale, tc[0], tc[1], tc[2], cmd.a, cmd.font_id)
          end
        end

        def draw_list_row(cmd : Scripting::GUI::DrawCall)
          if cmd.active?
            draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, Theme::ACCENT[0], Theme::ACCENT[1], Theme::ACCENT[2], cmd.a * 0.8f32)
          elsif cmd.hovered?
            draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, Theme::ACCENT[0], Theme::ACCENT[1], Theme::ACCENT[2], cmd.a * 0.25f32)
          end

          unless cmd.text.empty?
            tc = cmd.active? ? Theme::TEXT_DARK : Theme::TEXT_PRIMARY
            draw_text(cmd.text, cmd.x + 4, cmd.y + (cmd.h - cmd.scale * 8) / 2, cmd.scale, tc[0], tc[1], tc[2], cmd.a, cmd.font_id)
          end

          draw_rect(cmd.x, cmd.y + cmd.h - 1, cmd.w, 1, Theme::DIVIDER[0], Theme::DIVIDER[1], Theme::DIVIDER[2], cmd.a * 0.3f32)
        end

        def draw_progress_bar(cmd : Scripting::GUI::DrawCall)
          draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, Theme::BG_DARKER[0], Theme::BG_DARKER[1], Theme::BG_DARKER[2], cmd.a)
          draw_bevel_sunken(cmd.x, cmd.y, cmd.w, cmd.h)

          fill_w = (cmd.w - 4) * cmd.value.clamp(0.0f32, 1.0f32)
          if fill_w > 0
            draw_rect(cmd.x + 2, cmd.y + 2, fill_w, cmd.h - 4, cmd.r2, cmd.g2, cmd.b2, cmd.a)
          end

          unless cmd.text.empty?
            tc = Theme::TEXT_PRIMARY
            char_w = cmd.scale * 7.5f32
            tx = cmd.x + (cmd.w - cmd.text.size * char_w) / 2
            ty = cmd.y + (cmd.h - cmd.scale * 8) / 2
            draw_text(cmd.text, tx, ty, cmd.scale, tc[0], tc[1], tc[2], cmd.a, cmd.font_id)
          end
        end

        def draw_slider(cmd : Scripting::GUI::DrawCall)
          if cmd.vertical?
            draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, Theme::BG_DARKER[0], Theme::BG_DARKER[1], Theme::BG_DARKER[2], cmd.a)
            draw_bevel_sunken(cmd.x, cmd.y, cmd.w, cmd.h)

            fill_h = cmd.h * cmd.value.clamp(0.0f32, 1.0f32)
            if fill_h > 0
              draw_rect(cmd.x + 2, cmd.y + cmd.h - fill_h, cmd.w - 4, fill_h, cmd.r2, cmd.g2, cmd.b2, cmd.a * 0.5f32)
            end

            thumb_y = cmd.y + cmd.h - fill_h - Theme::SLIDER_THUMB_H / 2
            draw_rect(cmd.x, thumb_y, cmd.w, Theme::SLIDER_THUMB_H.to_f32, Theme::BG_LIGHT[0], Theme::BG_LIGHT[1], Theme::BG_LIGHT[2], cmd.a)
            draw_bevel_raised(cmd.x, thumb_y, cmd.w, Theme::SLIDER_THUMB_H.to_f32)
          else
            draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, Theme::BG_DARKER[0], Theme::BG_DARKER[1], Theme::BG_DARKER[2], cmd.a)
            draw_bevel_sunken(cmd.x, cmd.y, cmd.w, cmd.h)

            fill_w = cmd.w * cmd.value.clamp(0.0f32, 1.0f32)
            if fill_w > 0
              draw_rect(cmd.x + 2, cmd.y + 2, fill_w - 2, cmd.h - 4, cmd.r2, cmd.g2, cmd.b2, cmd.a * 0.5f32)
            end

            thumb_x = cmd.x + fill_w - Theme::SLIDER_THUMB_W / 2
            draw_rect(thumb_x, cmd.y, Theme::SLIDER_THUMB_W.to_f32, cmd.h, Theme::BG_LIGHT[0], Theme::BG_LIGHT[1], Theme::BG_LIGHT[2], cmd.a)
            draw_bevel_raised(thumb_x, cmd.y, Theme::SLIDER_THUMB_W.to_f32, cmd.h)
          end
        end

        def draw_divider(cmd : Scripting::GUI::DrawCall)
          dk = Theme::BEVEL_DARK
          lt = Theme::BEVEL_LIGHT

          if cmd.vertical?
            draw_rect(cmd.x, cmd.y, 1, cmd.h, dk[0], dk[1], dk[2], cmd.a)
            draw_rect(cmd.x + 1, cmd.y, 1, cmd.h, lt[0], lt[1], lt[2], cmd.a * 0.5f32)
          else
            draw_rect(cmd.x, cmd.y, cmd.w, 1, dk[0], dk[1], dk[2], cmd.a)
            draw_rect(cmd.x, cmd.y + 1, cmd.w, 1, lt[0], lt[1], lt[2], cmd.a * 0.5f32)
          end
        end

        def draw_text_entry(cmd : Scripting::GUI::DrawCall)
          draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, Theme::BG_DARKER[0], Theme::BG_DARKER[1], Theme::BG_DARKER[2], cmd.a)
          draw_bevel_sunken(cmd.x, cmd.y, cmd.w, cmd.h)

          unless cmd.text.empty?
            tc = cmd.disabled? ? Theme::TEXT_DISABLED : Theme::TEXT_PRIMARY
            draw_text(cmd.text, cmd.x + 4, cmd.y + (cmd.h - cmd.scale * 8) / 2, cmd.scale, tc[0], tc[1], tc[2], cmd.a, cmd.font_id)
          end

          if cmd.active?
            char_w = cmd.scale * 7.5f32
            cursor_x = cmd.x + 4 + cmd.text.size * char_w
            draw_rect(cursor_x, cmd.y + 3, 1, cmd.h - 6, Theme::TEXT_PRIMARY[0], Theme::TEXT_PRIMARY[1], Theme::TEXT_PRIMARY[2], cmd.a)
          end
        end

        def draw_rich_text(cmd : Scripting::GUI::DrawCall)
          if cmd.a > 0.001f32
            draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, Theme::BG_DARKER[0], Theme::BG_DARKER[1], Theme::BG_DARKER[2], cmd.a)
            draw_bevel_sunken(cmd.x, cmd.y, cmd.w, cmd.h)
          end

          unless cmd.text.empty?
            tr = cmd.r2 > 0.001f32 || cmd.g2 > 0.001f32 || cmd.b2 > 0.001f32 ? {cmd.r2, cmd.g2, cmd.b2} : Theme::TEXT_PRIMARY
            ta = cmd.a2 > 0.001f32 ? cmd.a2 : 1.0f32
            line_h = cmd.scale * 14
            lines = cmd.text.split('\n')
            ty = cmd.y + 4
            lines.each do |line|
              break if ty + line_h > cmd.y + cmd.h - 4
              draw_text(line, cmd.x + 4, ty, cmd.scale, tr[0], tr[1], tr[2], ta, cmd.font_id)
              ty += line_h
            end
          end
        end

        def process_command(cmd : Scripting::GUI::DrawCall)
          case cmd.command
          when .rect?
            draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, cmd.r, cmd.g, cmd.b, cmd.a)
          when .text?
            draw_text(cmd.text, cmd.x, cmd.y, cmd.scale, cmd.r, cmd.g, cmd.b, cmd.a, cmd.font_id)
          when .bevel_raised?
            draw_bevel_raised(cmd.x, cmd.y, cmd.w, cmd.h)
          when .bevel_sunken?
            draw_bevel_sunken(cmd.x, cmd.y, cmd.w, cmd.h)
          when .panel?
            draw_panel(cmd)
          when .button?
            draw_button(cmd)
          when .check_box?
            draw_checkbox(cmd)
          when .combo_box?
            draw_combobox(cmd)
          when .list_row?
            draw_list_row(cmd)
          when .progress_bar?
            draw_progress_bar(cmd)
          when .slider?
            draw_slider(cmd)
          when .divider?
            draw_divider(cmd)
          when .text_entry?
            draw_text_entry(cmd)
          when .rich_text?
            draw_rich_text(cmd)
          end
        end

        def destroy
          @shader.destroy
          @font_manager.destroy
          LibGL.glDeleteVertexArrays(1, pointerof(@quad_vao))
          LibGL.glDeleteBuffers(1, pointerof(@quad_vbo))
        end

        private def draw_text_bitmap(text : String, x : Float32, y : Float32, scale : Float32,
                                     r : Float32, g : Float32, b : Float32, a : Float32)
          font = @font_manager.bitmap_font
          @shader.use
          @shader.set_int("uHasTexture", 1)
          @shader.set_int("uIsText", 1)
          @shader.set_color("uColor", r, g, b, a)

          LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, font.texture_id)
          @shader.set_int("uTexture", 0)

          char_w = font.char_width.to_f32 * scale
          char_h = font.char_height.to_f32 * scale
          cursor_x = x

          text.each_char do |c|
            u0, v0, u1, v1 = font.char_uv(c)

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

        private def draw_text_ttf(text : String, x : Float32, y : Float32, scale : Float32,
                                  r : Float32, g : Float32, b : Float32, a : Float32, font_id : Int32)
          font = @font_manager.get(font_id)
          return draw_text_bitmap(text, x, y, scale, r, g, b, a) unless font

          @shader.use
          @shader.set_int("uHasTexture", 1)
          @shader.set_int("uIsText", 1)
          @shader.set_color("uColor", r, g, b, a)

          LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, font.texture_id)
          @shader.set_int("uTexture", 0)

          cursor_x = x

          text.each_char do |c|
            glyph = font.glyphs[c]?
            next unless glyph

            gx = cursor_x + glyph.offset_x * scale
            gy = y + (font.ascent + glyph.offset_y) * scale
            gw = glyph.w * scale
            gh = glyph.h * scale

            char_verts = StaticArray[
              0.0f32, 0.0f32, glyph.u0, glyph.v0,
              1.0f32, 0.0f32, glyph.u1, glyph.v0,
              1.0f32, 1.0f32, glyph.u1, glyph.v1,
              0.0f32, 0.0f32, glyph.u0, glyph.v0,
              1.0f32, 1.0f32, glyph.u1, glyph.v1,
              0.0f32, 1.0f32, glyph.u0, glyph.v1,
            ]

            LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @quad_vbo)
            LibGL.glBufferData(LibGL::GL_ARRAY_BUFFER,
              char_verts.size.to_i64 * sizeof(Float32),
              char_verts.to_unsafe.as(Pointer(Void)),
              LibGL::GL_DYNAMIC_DRAW)

            @shader.set_vector2("uPosition", gx, gy)
            @shader.set_vector2("uSize", gw, gh)

            LibGL.glBindVertexArray(@quad_vao)
            LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 6)

            cursor_x += glyph.advance * scale
          end

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
end
