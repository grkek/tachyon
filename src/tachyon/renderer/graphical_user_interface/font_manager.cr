module Tachyon
  module Renderer
    module GraphicalUserInterface
      class FontManager
        Log = ::Log.for(self)

        struct LoadedFont
          property texture_id : LibGL::GLuint = 0_u32
          property atlas_w : Int32 = 0
          property atlas_h : Int32 = 0
          property char_w : Float32 = 0.0f32
          property char_h : Float32 = 0.0f32
          property line_height : Float32 = 0.0f32
          property ascent : Float32 = 0.0f32
          property glyphs : Hash(Char, GlyphInfo) = {} of Char => GlyphInfo

          struct GlyphInfo
            property u0 : Float32 = 0.0f32
            property v0 : Float32 = 0.0f32
            property u1 : Float32 = 0.0f32
            property v1 : Float32 = 0.0f32
            property w : Float32 = 0.0f32
            property h : Float32 = 0.0f32
            property offset_x : Float32 = 0.0f32
            property offset_y : Float32 = 0.0f32
            property advance : Float32 = 0.0f32
          end
        end

        @fonts : Hash(Int32, LoadedFont) = {} of Int32 => LoadedFont
        @bitmap_font : Font
        @next_id : Int32 = 1

        def initialize
          @bitmap_font = Font.new
        end

        def bitmap_font : Font
          @bitmap_font
        end

        # Load a TTF/OTF file and rasterize it into a glyph atlas at the given pixel size.
        # Returns a font ID (>0) that can be referenced in draw calls.
        def load(path : String, size : Float32 = 16.0f32) : Int32
          data = File.read(path).to_slice

          atlas_w = 512
          atlas_h = 512
          pixels = Bytes.new(atlas_w * atlas_h, 0_u8)

          info = uninitialized LibSTBTT::FontInfo
          unless LibSTBTT.stbtt_InitFont(pointerof(info), data, 0) != 0
            Log.error { "Failed to parse font: #{path}" }
            return 0
          end

          scale = LibSTBTT.stbtt_ScaleForPixelHeight(pointerof(info), size)

          ascent_raw = 0
          descent_raw = 0
          line_gap_raw = 0
          LibSTBTT.stbtt_GetFontVMetrics(pointerof(info), pointerof(ascent_raw), pointerof(descent_raw), pointerof(line_gap_raw))

          ascent = ascent_raw.to_f32 * scale
          descent = descent_raw.to_f32 * scale
          line_height = (ascent_raw - descent_raw + line_gap_raw).to_f32 * scale

          font = LoadedFont.new
          font.atlas_w = atlas_w
          font.atlas_h = atlas_h
          font.line_height = line_height
          font.ascent = ascent

          pen_x = 2
          pen_y = 2
          row_h = 0

          (32..126).each do |code|
            c = code.chr

            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            LibSTBTT.stbtt_GetCodepointBitmapBox(
              pointerof(info), code, scale, scale,
              pointerof(x0), pointerof(y0), pointerof(x1), pointerof(y1)
            )

            gw = x1 - x0
            gh = y1 - y0

            if pen_x + gw + 2 > atlas_w
              pen_x = 2
              pen_y += row_h + 2
              row_h = 0
            end

            if pen_y + gh + 2 > atlas_h
              Log.warn { "Font atlas overflow at char #{code}, stopping" }
              break
            end

            LibSTBTT.stbtt_MakeCodepointBitmap(
              pointerof(info),
              pixels.to_unsafe + pen_y * atlas_w + pen_x,
              gw, gh, atlas_w, scale, scale, code
            )

            advance_raw = 0
            lsb_raw = 0
            LibSTBTT.stbtt_GetCodepointHMetrics(pointerof(info), code, pointerof(advance_raw), pointerof(lsb_raw))

            glyph = LoadedFont::GlyphInfo.new
            glyph.u0 = pen_x.to_f32 / atlas_w
            glyph.v0 = pen_y.to_f32 / atlas_h
            glyph.u1 = (pen_x + gw).to_f32 / atlas_w
            glyph.v1 = (pen_y + gh).to_f32 / atlas_h
            glyph.w = gw.to_f32
            glyph.h = gh.to_f32
            glyph.offset_x = x0.to_f32
            glyph.offset_y = y0.to_f32
            glyph.advance = advance_raw.to_f32 * scale

            font.glyphs[c] = glyph

            pen_x += gw + 2
            row_h = ::Math.max(row_h, gh)
          end

          font.char_w = font.glyphs.values.first?.try(&.advance) || size * 0.6f32
          font.char_h = line_height

          tex_id = 0_u32
          LibGL.glGenTextures(1, pointerof(tex_id))
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, tex_id)
          LibGL.glTexImage2D(
            LibGL::GL_TEXTURE_2D, 0, LibGL::GL_R8.to_i32,
            atlas_w, atlas_h, 0, LibGL::GL_RED, LibGL::GL_UNSIGNED_BYTE,
            pixels.to_unsafe.as(Pointer(Void))
          )
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, 0)

          font.texture_id = tex_id

          id = @next_id
          @next_id += 1
          @fonts[id] = font

          Log.info { "Loaded font '#{path}' as id=#{id}, #{font.glyphs.size} glyphs, #{atlas_w}x#{atlas_h} atlas" }
          id
        end

        def get(id : Int32) : LoadedFont?
          @fonts[id]?
        end

        def destroy
          @bitmap_font.destroy
          @fonts.each_value do |f|
            tex = f.texture_id
            LibGL.glDeleteTextures(1, pointerof(tex))
          end
          @fonts.clear
        end
      end
    end
  end
end

@[Link(ldflags: "#{__DIR__}/../../../../bin/stb_truetype_impl.o")]
lib LibSTBTT
  struct FontInfo
    data : Pointer(UInt8)
    fontstart : Int32
    num_glyphs : Int32
    loca : Int32
    head : Int32
    glyf : Int32
    hhea : Int32
    hmtx : Int32
    kern : Int32
    gpos : Int32
    svg : Int32
    index_map : Int32
    index_to_loc_format : Int32
    cff : UInt8[32]
    char_strings : UInt8[32]
    gsubrs : UInt8[32]
    subrs : UInt8[32]
    fontdicts : UInt8[32]
    fdselect : UInt8[32]
  end

  fun stbtt_InitFont(info : FontInfo*, data : UInt8*, offset : Int32) : Int32
  fun stbtt_ScaleForPixelHeight(info : FontInfo*, pixels : Float32) : Float32
  fun stbtt_GetFontVMetrics(info : FontInfo*, ascent : Int32*, descent : Int32*, line_gap : Int32*)
  fun stbtt_GetCodepointHMetrics(info : FontInfo*, codepoint : Int32, advance : Int32*, lsb : Int32*)
  fun stbtt_GetCodepointBitmapBox(info : FontInfo*, codepoint : Int32, scale_x : Float32, scale_y : Float32, x0 : Int32*, y0 : Int32*, x1 : Int32*, y1 : Int32*)
  fun stbtt_MakeCodepointBitmap(info : FontInfo*, output : UInt8*, out_w : Int32, out_h : Int32, out_stride : Int32, scale_x : Float32, scale_y : Float32, codepoint : Int32)
end
