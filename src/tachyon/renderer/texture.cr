# stb_image FFI bindings
@[Link(ldflags: "#{__DIR__}/../../../bin/stb_image_impl.o")]
lib LibSTBI
  fun stbi_load(filename : LibC::Char*, x : Int32*, y : Int32*, channels_in_file : Int32*, desired_channels : Int32) : UInt8*
  fun stbi_loadf(filename : LibC::Char*, x : Int32*, y : Int32*, channels_in_file : Int32*, desired_channels : Int32) : Float32*
  fun stbi_load_from_memory(buffer : UInt8*, len : Int32, x : Int32*, y : Int32*, channels_in_file : Int32*, desired_channels : Int32) : UInt8*
  fun stbi_image_free(data : Void*) : Void
  fun stbi_set_flip_vertically_on_load(flag : Int32) : Void
  fun stbi_failure_reason : LibC::Char*
end

module Tachyon
  module Renderer
    class Texture
      Log = ::Log.for(self)

      property id : LibGL::GLuint = 0_u32
      property width : Int32 = 0
      property height : Int32 = 0
      property channels : Int32 = 0

      def initialize
        LibGL.glGenTextures(1, pointerof(@id))
      end

      # Load from file path
      def self.load(path : String, srgb : Bool = true) : Texture
        tex = Texture.new

        LibSTBI.stbi_set_flip_vertically_on_load(1)
        data = LibSTBI.stbi_load(path, pointerof(tex.@width), pointerof(tex.@height), pointerof(tex.@channels), 0)

        unless data
          reason = LibSTBI.stbi_failure_reason
          msg = reason ? String.new(reason) : "unknown error"
          raise "Failed to load texture '#{path}': #{msg}"
        end

        tex.upload(data, tex.width, tex.height, tex.channels, srgb)
        LibSTBI.stbi_image_free(data.as(Pointer(Void)))

        tex
      end

      # Load from memory
      def self.load_from_memory(bytes : Bytes, srgb : Bool = true) : Texture
        tex = Texture.new

        LibSTBI.stbi_set_flip_vertically_on_load(1)
        data = LibSTBI.stbi_load_from_memory(bytes.to_unsafe, bytes.size, pointerof(tex.@width), pointerof(tex.@height), pointerof(tex.@channels), 0)

        unless data
          reason = LibSTBI.stbi_failure_reason
          msg = reason ? String.new(reason) : "unknown error"
          raise "Failed to load texture from memory: #{msg}"
        end

        tex.upload(data, tex.width, tex.height, tex.channels, srgb)
        LibSTBI.stbi_image_free(data.as(Pointer(Void)))

        tex
      end

      # Create a 1x1 solid color texture
      def self.solid_color(r : UInt8, g : UInt8, b : UInt8, a : UInt8 = 255_u8) : Texture
        tex = Texture.new
        tex.width = 1
        tex.height = 1
        tex.channels = 4
        pixel = StaticArray[r, g, b, a]

        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, tex.id)
        LibGL.glTexImage2D(
          LibGL::GL_TEXTURE_2D, 0, LibGL::GL_RGBA8.to_i32,
          1, 1, 0,
          LibGL::GL_RGBA, LibGL::GL_UNSIGNED_BYTE,
          pixel.to_unsafe.as(Pointer(Void))
        )
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_NEAREST.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_NEAREST.to_i32)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, 0)

        tex
      end

      def bind(unit : Int32 = 0)
        LibGL.glActiveTexture(LibGL::GL_TEXTURE0 + unit.to_u32)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @id)
      end

      def unbind
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, 0)
      end

      def destroy
        LibGL.glDeleteTextures(1, pointerof(@id))
      end

      protected def upload(data : UInt8*, w : Int32, h : Int32, ch : Int32, srgb : Bool)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @id)

        format = case ch
                 when 1 then LibGL::GL_RED
                 when 2 then LibGL::GL_RG
                 when 3 then LibGL::GL_RGB
                 when 4 then LibGL::GL_RGBA
                 else        LibGL::GL_RGBA
                 end

        internal_format = if srgb
                            ch >= 4 ? LibGL::GL_SRGB8_ALPHA8 : LibGL::GL_SRGB8
                          else
                            ch >= 4 ? LibGL::GL_RGBA8 : LibGL::GL_RGB8
                          end

        LibGL.glTexImage2D(
          LibGL::GL_TEXTURE_2D, 0, internal_format.to_i32,
          w, h, 0,
          format, LibGL::GL_UNSIGNED_BYTE,
          data.as(Pointer(Void))
        )

        LibGL.glGenerateMipmap(LibGL::GL_TEXTURE_2D)

        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_REPEAT.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_REPEAT.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR_MIPMAP_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)

        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, 0)
      end
    end
  end
end
