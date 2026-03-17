module Tachyon
  module Renderer
    class Font
      Log = ::Log.for(self)

      getter texture_id : LibGL::GLuint = 0_u32
      getter char_width : Int32
      getter char_height : Int32
      getter cols : Int32 = 16
      getter rows : Int32 = 8

      def initialize(@char_width : Int32 = 8, @char_height : Int32 = 16)
        generate_default_font
      end

      def char_uv(c : Char) : {Float32, Float32, Float32, Float32}
        code = c.ord.clamp(32, 127) - 32
        col = code % @cols
        row = code // @cols

        u0 = col.to_f32 / @cols.to_f32
        v0 = row.to_f32 / @rows.to_f32
        u1 = (col + 1).to_f32 / @cols.to_f32
        v1 = (row + 1).to_f32 / @rows.to_f32

        {u0, v0, u1, v1}
      end

      def destroy
        LibGL.glDeleteTextures(1, pointerof(@texture_id))
      end

      private def generate_default_font
        # Generate a simple 8x16 bitmap font texture
        # 16 columns x 8 rows = 128 characters (ASCII 32-127)
        tex_w = @char_width * @cols
        tex_h = @char_height * @rows
        pixels = Bytes.new(tex_w * tex_h, 0_u8)

        # Built-in minimal font glyphs for printable ASCII
        # Each character is 8 pixels wide, stored as 16 bytes (one per row)
        glyphs = generate_glyphs

        glyphs.each_with_index do |(code, rows_data), _|
          idx = code - 32
          col = idx % @cols
          row = idx // @cols
          base_x = col * @char_width
          base_y = row * @char_height

          rows_data.each_with_index do |row_bits, y|
            8.times do |x|
              if (row_bits >> (7 - x)) & 1 == 1
                px = base_x + x
                py = base_y + y
                pixels[py * tex_w + px] = 255_u8
              end
            end
          end
        end

        LibGL.glGenTextures(1, pointerof(@texture_id))
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @texture_id)
        LibGL.glTexImage2D(LibGL::GL_TEXTURE_2D, 0, LibGL::GL_R8.to_i32,
          tex_w, tex_h, 0, LibGL::GL_RED, LibGL::GL_UNSIGNED_BYTE,
          pixels.to_unsafe.as(Pointer(Void)))
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_NEAREST.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_NEAREST.to_i32)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, 0)
      end

      private def generate_glyphs : Array({Int32, StaticArray(UInt8, 16)})
        glyphs = [] of {Int32, StaticArray(UInt8, 16)}

        # Space
        glyphs << {32, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        # !
        glyphs << {33, StaticArray[0_u8, 0_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x00_u8, 0x18_u8, 0x18_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        # A-Z
        glyphs << {65, StaticArray[0_u8, 0_u8, 0x18_u8, 0x3C_u8, 0x66_u8, 0x66_u8, 0x7E_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {66, StaticArray[0_u8, 0_u8, 0x7C_u8, 0x66_u8, 0x66_u8, 0x7C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x7C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {67, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0x66_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {68, StaticArray[0_u8, 0_u8, 0x78_u8, 0x6C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x6C_u8, 0x78_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {69, StaticArray[0_u8, 0_u8, 0x7E_u8, 0x60_u8, 0x60_u8, 0x7C_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0x7E_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {70, StaticArray[0_u8, 0_u8, 0x7E_u8, 0x60_u8, 0x60_u8, 0x7C_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {71, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x60_u8, 0x60_u8, 0x6E_u8, 0x66_u8, 0x66_u8, 0x3E_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {72, StaticArray[0_u8, 0_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x7E_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {73, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {74, StaticArray[0_u8, 0_u8, 0x1E_u8, 0x0C_u8, 0x0C_u8, 0x0C_u8, 0x0C_u8, 0x6C_u8, 0x6C_u8, 0x38_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {75, StaticArray[0_u8, 0_u8, 0x66_u8, 0x6C_u8, 0x78_u8, 0x70_u8, 0x78_u8, 0x6C_u8, 0x66_u8, 0x66_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {76, StaticArray[0_u8, 0_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0x7E_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {77, StaticArray[0_u8, 0_u8, 0xC6_u8, 0xEE_u8, 0xFE_u8, 0xD6_u8, 0xC6_u8, 0xC6_u8, 0xC6_u8, 0xC6_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {78, StaticArray[0_u8, 0_u8, 0x66_u8, 0x76_u8, 0x7E_u8, 0x6E_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {79, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {80, StaticArray[0_u8, 0_u8, 0x7C_u8, 0x66_u8, 0x66_u8, 0x7C_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {81, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x6E_u8, 0x3C_u8, 0x0E_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {82, StaticArray[0_u8, 0_u8, 0x7C_u8, 0x66_u8, 0x66_u8, 0x7C_u8, 0x6C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {83, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x60_u8, 0x3C_u8, 0x06_u8, 0x06_u8, 0x66_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {84, StaticArray[0_u8, 0_u8, 0x7E_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {85, StaticArray[0_u8, 0_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {86, StaticArray[0_u8, 0_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x3C_u8, 0x18_u8, 0x18_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {87, StaticArray[0_u8, 0_u8, 0xC6_u8, 0xC6_u8, 0xC6_u8, 0xD6_u8, 0xFE_u8, 0xEE_u8, 0xC6_u8, 0xC6_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {88, StaticArray[0_u8, 0_u8, 0x66_u8, 0x66_u8, 0x3C_u8, 0x18_u8, 0x3C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {89, StaticArray[0_u8, 0_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x3C_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {90, StaticArray[0_u8, 0_u8, 0x7E_u8, 0x06_u8, 0x0C_u8, 0x18_u8, 0x30_u8, 0x60_u8, 0x60_u8, 0x7E_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}

        # 0-9
        glyphs << {48, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x6E_u8, 0x76_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {49, StaticArray[0_u8, 0_u8, 0x18_u8, 0x38_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {50, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x06_u8, 0x0C_u8, 0x18_u8, 0x30_u8, 0x60_u8, 0x7E_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {51, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x06_u8, 0x1C_u8, 0x06_u8, 0x06_u8, 0x66_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {52, StaticArray[0_u8, 0_u8, 0x0C_u8, 0x1C_u8, 0x3C_u8, 0x6C_u8, 0x7E_u8, 0x0C_u8, 0x0C_u8, 0x0C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {53, StaticArray[0_u8, 0_u8, 0x7E_u8, 0x60_u8, 0x7C_u8, 0x06_u8, 0x06_u8, 0x06_u8, 0x66_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {54, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x60_u8, 0x60_u8, 0x7C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {55, StaticArray[0_u8, 0_u8, 0x7E_u8, 0x06_u8, 0x0C_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {56, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x66_u8, 0x3C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {57, StaticArray[0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x66_u8, 0x3E_u8, 0x06_u8, 0x06_u8, 0x06_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}

        # a-z (lowercase)
        glyphs << {97, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x3C_u8, 0x06_u8, 0x3E_u8, 0x66_u8, 0x66_u8, 0x3E_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {98, StaticArray[0_u8, 0_u8, 0x60_u8, 0x60_u8, 0x7C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x7C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {99, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x60_u8, 0x60_u8, 0x66_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {100, StaticArray[0_u8, 0_u8, 0x06_u8, 0x06_u8, 0x3E_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x3E_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {101, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x7E_u8, 0x60_u8, 0x60_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {102, StaticArray[0_u8, 0_u8, 0x1C_u8, 0x30_u8, 0x7C_u8, 0x30_u8, 0x30_u8, 0x30_u8, 0x30_u8, 0x30_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {103, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x3E_u8, 0x66_u8, 0x66_u8, 0x3E_u8, 0x06_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {104, StaticArray[0_u8, 0_u8, 0x60_u8, 0x60_u8, 0x7C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {105, StaticArray[0_u8, 0_u8, 0x18_u8, 0_u8, 0x38_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {106, StaticArray[0_u8, 0_u8, 0x0C_u8, 0_u8, 0x0C_u8, 0x0C_u8, 0x0C_u8, 0x0C_u8, 0x6C_u8, 0x38_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {107, StaticArray[0_u8, 0_u8, 0x60_u8, 0x60_u8, 0x66_u8, 0x6C_u8, 0x78_u8, 0x6C_u8, 0x66_u8, 0x66_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {108, StaticArray[0_u8, 0_u8, 0x38_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x18_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {109, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0xEC_u8, 0xFE_u8, 0xD6_u8, 0xC6_u8, 0xC6_u8, 0xC6_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {110, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x7C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {111, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x3C_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {112, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x7C_u8, 0x66_u8, 0x66_u8, 0x7C_u8, 0x60_u8, 0x60_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {113, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x3E_u8, 0x66_u8, 0x66_u8, 0x3E_u8, 0x06_u8, 0x06_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {114, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x7C_u8, 0x66_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0x60_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {115, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x3E_u8, 0x60_u8, 0x3C_u8, 0x06_u8, 0x06_u8, 0x7C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {116, StaticArray[0_u8, 0_u8, 0x30_u8, 0x30_u8, 0x7C_u8, 0x30_u8, 0x30_u8, 0x30_u8, 0x30_u8, 0x1C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {117, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x3E_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {118, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x66_u8, 0x66_u8, 0x66_u8, 0x3C_u8, 0x18_u8, 0x18_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {119, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0xC6_u8, 0xC6_u8, 0xD6_u8, 0xFE_u8, 0xEE_u8, 0xC6_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {120, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x66_u8, 0x3C_u8, 0x18_u8, 0x3C_u8, 0x66_u8, 0x66_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {121, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x66_u8, 0x66_u8, 0x3E_u8, 0x06_u8, 0x06_u8, 0x3C_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}
        glyphs << {122, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0x7E_u8, 0x0C_u8, 0x18_u8, 0x30_u8, 0x60_u8, 0x7E_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}

        # Common punctuation
        glyphs << {46, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0x18_u8, 0x18_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}                   # .
        glyphs << {44, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0x18_u8, 0x18_u8, 0x08_u8, 0x10_u8, 0_u8, 0_u8, 0_u8, 0_u8]}             # ,
        glyphs << {58, StaticArray[0_u8, 0_u8, 0_u8, 0x18_u8, 0x18_u8, 0_u8, 0_u8, 0x18_u8, 0x18_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}             # :
        glyphs << {45, StaticArray[0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0x7E_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]}                      # -
        glyphs << {47, StaticArray[0_u8, 0_u8, 0x06_u8, 0x0C_u8, 0x0C_u8, 0x18_u8, 0x18_u8, 0x30_u8, 0x30_u8, 0x60_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]} # /

        glyphs
      end
    end
  end
end
