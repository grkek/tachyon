module Tachyon
  module Renderer
    # Bloom, tone mapping, and FXAA full-screen post-processing
    class PostProcess
      Log = ::Log.for(self)

      @copy_frame_buffer : LibGL::GLuint = 0_u32
      @copy_texture : LibGL::GLuint = 0_u32
      @bright_frame_buffer : LibGL::GLuint = 0_u32
      @bright_texture : LibGL::GLuint = 0_u32
      @ping_frame_buffer : LibGL::GLuint = 0_u32
      @ping_texture : LibGL::GLuint = 0_u32
      @pong_frame_buffer : LibGL::GLuint = 0_u32
      @pong_texture : LibGL::GLuint = 0_u32
      @bright_shader : Shader
      @blur_shader : Shader
      @composite_shader : Shader
      @fxaa_shader : Shader
      @width : Int32 = 0
      @height : Int32 = 0
      @initialized : Bool = false

      getter quad_vao : LibGL::GLuint = 0_u32
      getter quad_vbo : LibGL::GLuint = 0_u32

      def initialize
        # Load all shaders from disk via load_file
        quad_vert = Shader.load_file("quad.vert")

        @bright_shader = Shader.new(quad_vert, Shader.load_file("bright_pass.frag"))
        @blur_shader = Shader.new(quad_vert, Shader.load_file("blur.frag"))
        @composite_shader = Shader.new(quad_vert, Shader.load_file("composite.frag"))
        @fxaa_shader = Shader.new(quad_vert, Shader.load_file("fxaa.frag"))

        setup_quad
      end

      # Allocate half-res FBOs when viewport size changes
      def ensure_initialized(width : Int32, height : Int32)
        return if @initialized && width == @width && height == @height
        cleanup_frame_buffers if @initialized
        @initialized = true
        @width = width
        @height = height

        create_color_frame_buffer(pointerof(@copy_frame_buffer), pointerof(@copy_texture), width, height)

        hw = width // 2
        hh = height // 2
        create_color_frame_buffer(pointerof(@bright_frame_buffer), pointerof(@bright_texture), hw, hh)
        create_color_frame_buffer(pointerof(@ping_frame_buffer), pointerof(@ping_texture), hw, hh)
        create_color_frame_buffer(pointerof(@pong_frame_buffer), pointerof(@pong_texture), hw, hh)
      end

      # Run bloom + FXAA after the scene has been rendered into the given FBO
      def apply(frame_buffer : Int32, width : Int32, height : Int32)
        ensure_initialized(width, height)

        bloom = Configuration.instance.bloom
        fxaa = Configuration.instance.fxaa

        # Clear all work textures to prevent ghosting
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @copy_frame_buffer)
        LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @bright_frame_buffer)
        LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @ping_frame_buffer)
        LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @pong_frame_buffer)
        LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)

        # Always copy the scene
        LibGL.glBindFramebuffer(LibGL::GL_READ_FRAMEBUFFER, frame_buffer.to_u32)
        LibGL.glBindFramebuffer(LibGL::GL_DRAW_FRAMEBUFFER, @copy_frame_buffer)
        LibGL.glBlitFramebuffer(0, 0, width, height, 0, 0, width, height,
          LibGL::GL_COLOR_BUFFER_BIT, LibGL::GL_LINEAR)

        if bloom.enabled
          hw = width // 2
          hh = height // 2

          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @ping_frame_buffer)
          LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @pong_frame_buffer)
          LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @bright_frame_buffer)
          LibGL.glViewport(0, 0, hw, hh)
          LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)
          @bright_shader.use
          LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @copy_texture)
          @bright_shader.set_int("uScene", 0)
          @bright_shader.set_float("uThreshold", bloom.threshold)
          draw_quad

          horizontal = true
          first = true

          10.times do
            LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, horizontal ? @ping_frame_buffer : @pong_frame_buffer)
            LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)
            @blur_shader.use
            LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
            src = first ? @bright_texture : (horizontal ? @pong_texture : @ping_texture)
            LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, src)
            @blur_shader.set_int("uImage", 0)
            @blur_shader.set_int("uHorizontal", horizontal ? 1 : 0)
            draw_quad
            horizontal = !horizontal
            first = false
          end
        end

        # Always composite
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame_buffer.to_u32)
        LibGL.glViewport(0, 0, width, height)
        @composite_shader.use
        LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @copy_texture)
        @composite_shader.set_int("uScene", 0)
        LibGL.glActiveTexture(LibGL::GL_TEXTURE1)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, bloom.enabled ? @ping_texture : @copy_texture)
        @composite_shader.set_int("uBloom", 1)
        @composite_shader.set_float("uBloomIntensity", bloom.enabled ? bloom.intensity : 0.0f32)

        draw_quad

        if fxaa.enabled
          LibGL.glBindFramebuffer(LibGL::GL_READ_FRAMEBUFFER, frame_buffer.to_u32)
          LibGL.glBindFramebuffer(LibGL::GL_DRAW_FRAMEBUFFER, @copy_frame_buffer)
          LibGL.glBlitFramebuffer(0, 0, width, height, 0, 0, width, height,
            LibGL::GL_COLOR_BUFFER_BIT, LibGL::GL_LINEAR)

          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame_buffer.to_u32)
          LibGL.glViewport(0, 0, width, height)
          @fxaa_shader.use
          LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @copy_texture)
          @fxaa_shader.set_int("uScene", 0)
          @fxaa_shader.set_vector2("uInverseScreenSize", 1.0f32 / width.to_f32, 1.0f32 / height.to_f32)
          draw_quad
        end
      end

      def destroy
        @bright_shader.destroy
        @blur_shader.destroy
        @composite_shader.destroy
        @fxaa_shader.destroy
        cleanup_frame_buffers
        LibGL.glDeleteVertexArrays(1, pointerof(@quad_vao))
        LibGL.glDeleteBuffers(1, pointerof(@quad_vbo))
      end

      # Draw a full-screen quad
      def draw_quad
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
          Constants::QUAD_VERTICES.size.to_i64 * sizeof(Float32),
          Constants::QUAD_VERTICES.to_unsafe.as(Pointer(Void)),
          LibGL::GL_STATIC_DRAW)
        LibGL.glEnableVertexAttribArray(0)
        LibGL.glVertexAttribPointer(0, 2, LibGL::GL_FLOAT, LibGL::GL_FALSE, 4 * sizeof(Float32), Pointer(Void).null)
        LibGL.glEnableVertexAttribArray(1)
        LibGL.glVertexAttribPointer(1, 2, LibGL::GL_FLOAT, LibGL::GL_FALSE, 4 * sizeof(Float32), Pointer(Void).new(2_u64 * sizeof(Float32)))
        LibGL.glBindVertexArray(0)
      end

      private def create_color_frame_buffer(frame_buffer : LibGL::GLuint*, texture : LibGL::GLuint*, w : Int32, h : Int32)
        prev = 0_i32
        LibGL.glGetIntegerv(LibGL::GL_FRAMEBUFFER_BINDING, pointerof(prev))

        LibGL.glGenFramebuffers(1, frame_buffer)
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame_buffer.value)

        LibGL.glGenTextures(1, texture)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, texture.value)
        LibGL.glTexImage2D(LibGL::GL_TEXTURE_2D, 0, LibGL::GL_RGBA16F.to_i32, w, h, 0,
          LibGL::GL_RGBA, LibGL::GL_FLOAT, Pointer(Void).null)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glFramebufferTexture2D(LibGL::GL_FRAMEBUFFER, LibGL::GL_COLOR_ATTACHMENT0, LibGL::GL_TEXTURE_2D, texture.value, 0)

        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, prev.to_u32)
      end

      private def cleanup_frame_buffers
        {pointerof(@copy_frame_buffer), pointerof(@bright_frame_buffer), pointerof(@ping_frame_buffer), pointerof(@pong_frame_buffer)}.each do |frame_buffer|
          LibGL.glDeleteFramebuffers(1, frame_buffer) if frame_buffer.value != 0
          frame_buffer.value = 0_u32
        end
        {pointerof(@copy_texture), pointerof(@bright_texture), pointerof(@ping_texture), pointerof(@pong_texture)}.each do |tex|
          LibGL.glDeleteTextures(1, tex) if tex.value != 0
          tex.value = 0_u32
        end
      end
    end
  end
end
