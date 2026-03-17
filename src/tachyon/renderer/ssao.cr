module Tachyon
  module Renderer
    class SSAO
      Log = ::Log.for(self)

      @fbo : LibGL::GLuint = 0_u32
      @texture : LibGL::GLuint = 0_u32
      @blur_fbo : LibGL::GLuint = 0_u32
      @blur_texture : LibGL::GLuint = 0_u32
      @noise_texture : LibGL::GLuint = 0_u32
      @shader : Shader
      @blur_shader : Shader
      @width : Int32 = 0
      @height : Int32 = 0

      property radius : Float32 = 0.5f32
      property bias : Float32 = 0.025f32
      property enabled : Bool = true

      def initialize
        @shader = Shader.new(PostProcess::QUAD_VERT, SSAO_FRAG)
        @blur_shader = Shader.new(PostProcess::QUAD_VERT, SSAO_BLUR_FRAG)
        generate_noise_texture
        generate_sample_kernel
      end

      def resize(width : Int32, height : Int32)
        return if width == @width && height == @height
        @width = width
        @height = height
        cleanup
        create_single_channel_fbo(pointerof(@fbo), pointerof(@texture), width, height)
        create_single_channel_fbo(pointerof(@blur_fbo), pointerof(@blur_texture), width, height)
      end

      def texture : LibGL::GLuint
        @blur_texture
      end

      def destroy
        @shader.destroy
        @blur_shader.destroy
        cleanup
        LibGL.glDeleteTextures(1, pointerof(@noise_texture))
      end

      private def generate_noise_texture
        noise = Array(Float32).new(16 * 3) do
          rand(-1.0f32..1.0f32)
        end

        LibGL.glGenTextures(1, pointerof(@noise_texture))
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @noise_texture)
        LibGL.glTexImage2D(LibGL::GL_TEXTURE_2D, 0, LibGL::GL_RGB16F.to_i32, 4, 4, 0,
          LibGL::GL_RGB, LibGL::GL_FLOAT, noise.to_unsafe.as(Pointer(Void)))
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_NEAREST.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_NEAREST.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_REPEAT.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_REPEAT.to_i32)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, 0)
      end

      private def generate_sample_kernel
        @kernel = Array(Math::Vector3).new(32) do
          v = Math::Vector3.new(
            rand(-1.0f32..1.0f32),
            rand(-1.0f32..1.0f32),
            rand(0.0f32..1.0f32)
          ).normalize
          scale = rand(0.0f32..1.0f32)
          scale = 0.1f32 + scale * scale * 0.9f32
          v * scale
        end
      end

      private def create_single_channel_fbo(fbo : LibGL::GLuint*, texture : LibGL::GLuint*, w : Int32, h : Int32)
        LibGL.glGenFramebuffers(1, fbo)
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, fbo.value)
        LibGL.glGenTextures(1, texture)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, texture.value)
        LibGL.glTexImage2D(LibGL::GL_TEXTURE_2D, 0, LibGL::GL_R8.to_i32, w, h, 0,
          LibGL::GL_RED, LibGL::GL_FLOAT, Pointer(Void).null)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_NEAREST.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_NEAREST.to_i32)
        LibGL.glFramebufferTexture2D(LibGL::GL_FRAMEBUFFER, LibGL::GL_COLOR_ATTACHMENT0, LibGL::GL_TEXTURE_2D, texture.value, 0)
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, 0)
      end

      private def cleanup
        {pointerof(@fbo), pointerof(@blur_fbo)}.each do |f|
          LibGL.glDeleteFramebuffers(1, f) if f.value != 0
          f.value = 0_u32
        end
        {pointerof(@texture), pointerof(@blur_texture)}.each do |t|
          LibGL.glDeleteTextures(1, t) if t.value != 0
          t.value = 0_u32
        end
      end
    end
  end
end
