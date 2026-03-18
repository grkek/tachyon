module Tachyon
  module Renderer
    # Screen-space ambient occlusion renderer
    class SSAO
      Log = ::Log.for(self)

      @frame_buffer : LibGL::GLuint = 0_u32
      @texture : LibGL::GLuint = 0_u32
      @blur_frame_buffer : LibGL::GLuint = 0_u32
      @blur_texture : LibGL::GLuint = 0_u32
      @noise_texture : LibGL::GLuint = 0_u32
      @shader : Shader
      @blur_shader : Shader
      @width : Int32 = 0
      @height : Int32 = 0

      property radius : Float32 = 0.3f32
      property bias : Float32 = 0.035f32
      property enabled : Bool = true

      def initialize
        # Load shaders from files instead of embedded constants
        quad_vert = Shader.load_file("quad.vert")
        @shader = Shader.new(quad_vert, Shader.load_file("ssao.frag"))
        @blur_shader = Shader.new(quad_vert, Shader.load_file("ssao_blur.frag"))
        @kernel = [] of Math::Vector3
        generate_noise_texture
        generate_sample_kernel
      end

      # Resize FBOs when viewport changes
      def resize(width : Int32, height : Int32)
        return if width == @width && height == @height
        @width = width
        @height = height
        cleanup
        create_single_channel_frame_buffer(pointerof(@frame_buffer), pointerof(@texture), width, height)
        create_single_channel_frame_buffer(pointerof(@blur_frame_buffer), pointerof(@blur_texture), width, height)
      end

      # Return the blurred SSAO texture
      def texture : LibGL::GLuint
        @blur_texture
      end

      # Run the SSAO pass and blur
      def apply(quad_vao : LibGL::GLuint, depth_texture : LibGL::GLuint,
                projection : Math::Matrix4, view : Math::Matrix4,
                width : Int32, height : Int32)
        return unless @enabled
        resize(width, height)

        prev_frame_buffer = 0_i32
        LibGL.glGetIntegerv(LibGL::GL_FRAMEBUFFER_BINDING, pointerof(prev_frame_buffer))

        # SSAO pass
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @frame_buffer)
        LibGL.glViewport(0, 0, width, height)
        LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)

        @shader.use
        @shader.set_int("uDepth", 0)
        @shader.set_int("uNoise", 1)
        @shader.set_matrix4("uProjection", projection)
        @shader.set_matrix4("uView", view)
        @shader.set_vector2("uNoiseScale", width.to_f32 / 4.0f32, height.to_f32 / 4.0f32)
        @shader.set_float("uRadius", @radius)
        @shader.set_float("uBias", @bias)

        @kernel.each_with_index do |sample, index|
          @shader.set_vector3("uSamples[#{index}]", sample)
        end

        LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, depth_texture)
        LibGL.glActiveTexture(LibGL::GL_TEXTURE1)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @noise_texture)

        LibGL.glBindVertexArray(quad_vao)
        LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 6)
        LibGL.glBindVertexArray(0)

        # Blur pass
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @blur_frame_buffer)
        LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)

        @blur_shader.use
        @blur_shader.set_int("uSSAO", 0)
        LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @texture)

        LibGL.glBindVertexArray(quad_vao)
        LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 6)
        LibGL.glBindVertexArray(0)

        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, prev_frame_buffer.to_u32)
      end

      def destroy
        @shader.destroy
        @blur_shader.destroy
        cleanup
        LibGL.glDeleteTextures(1, pointerof(@noise_texture))
      end

      private def generate_noise_texture
        noise = Array(Float32).new(16 * 3) { rand(-1.0f32..1.0f32) }

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

      private def create_single_channel_frame_buffer(frame_buffer : LibGL::GLuint*, texture : LibGL::GLuint*, w : Int32, h : Int32)
        LibGL.glGenFramebuffers(1, frame_buffer)
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame_buffer.value)
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
        {pointerof(@frame_buffer), pointerof(@blur_frame_buffer)}.each do |f|
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
