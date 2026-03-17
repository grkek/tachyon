module Tachyon
  module Renderer
    class PostProcess
      Log = ::Log.for(self)

      @copy_fbo : LibGL::GLuint = 0_u32
      @copy_texture : LibGL::GLuint = 0_u32
      @bright_fbo : LibGL::GLuint = 0_u32
      @bright_texture : LibGL::GLuint = 0_u32
      @ping_fbo : LibGL::GLuint = 0_u32
      @ping_texture : LibGL::GLuint = 0_u32
      @pong_fbo : LibGL::GLuint = 0_u32
      @pong_texture : LibGL::GLuint = 0_u32
      @quad_vao : LibGL::GLuint = 0_u32
      @quad_vbo : LibGL::GLuint = 0_u32
      @bright_shader : Shader
      @blur_shader : Shader
      @composite_shader : Shader
      @width : Int32 = 0
      @height : Int32 = 0
      @initialized : Bool = false

      property bloom_threshold : Float32 = 0.8f32
      property bloom_intensity : Float32 = 0.35f32
      property bloom_enabled : Bool = true

      def initialize
        @bright_shader = Shader.new(Constants::QUAD_VERT, Constants::BRIGHT_FRAG)
        @blur_shader = Shader.new(Constants::QUAD_VERT, Constants::BLUR_FRAG)
        @composite_shader = Shader.new(Constants::QUAD_VERT, Constants::COMPOSITE_FRAG)
        setup_quad
      end

      def ensure_initialized(width : Int32, height : Int32)
        return if @initialized && width == @width && height == @height
        cleanup_fbos if @initialized
        @initialized = true
        @width = width
        @height = height

        # FBO to hold a copy of GTK's framebuffer
        create_color_fbo(pointerof(@copy_fbo), pointerof(@copy_texture), width, height)

        # Half-res FBOs for bloom
        hw = width // 2
        hh = height // 2
        create_color_fbo(pointerof(@bright_fbo), pointerof(@bright_texture), hw, hh)
        create_color_fbo(pointerof(@ping_fbo), pointerof(@ping_texture), hw, hh)
        create_color_fbo(pointerof(@pong_fbo), pointerof(@pong_texture), hw, hh)
      end

      # Call AFTER the scene has been rendered into GTK's FBO
      def apply(gtk_fbo : Int32, width : Int32, height : Int32)
        ensure_initialized(width, height)
        return unless @bloom_enabled

        hw = width // 2
        hh = height // 2

        # Copy GTK's FBO content into our texture via blit
        LibGL.glBindFramebuffer(LibGL::GL_READ_FRAMEBUFFER, gtk_fbo.to_u32)
        LibGL.glBindFramebuffer(LibGL::GL_DRAW_FRAMEBUFFER, @copy_fbo)
        LibGL.glBlitFramebuffer(0, 0, width, height, 0, 0, width, height,
          LibGL::GL_COLOR_BUFFER_BIT, LibGL::GL_LINEAR)

        # Extract bright pixels
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @bright_fbo)
        LibGL.glViewport(0, 0, hw, hh)
        LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT)
        @bright_shader.use
        LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @copy_texture)
        @bright_shader.set_int("uScene", 0)
        @bright_shader.set_float("uThreshold", @bloom_threshold)
        draw_quad

        # Blur ping-pong
        horizontal = true
        first = true
        10.times do
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, horizontal ? @ping_fbo : @pong_fbo)
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

        # Composite: draw scene + bloom back into GTK's FBO
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, gtk_fbo.to_u32)
        LibGL.glViewport(0, 0, width, height)
        @composite_shader.use
        LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @copy_texture)
        @composite_shader.set_int("uScene", 0)
        LibGL.glActiveTexture(LibGL::GL_TEXTURE1)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @ping_texture)
        @composite_shader.set_int("uBloom", 1)
        @composite_shader.set_float("uBloomIntensity", @bloom_intensity)
        draw_quad
      end

      def destroy
        @bright_shader.destroy
        @blur_shader.destroy
        @composite_shader.destroy
        cleanup_fbos
        LibGL.glDeleteVertexArrays(1, pointerof(@quad_vao))
        LibGL.glDeleteBuffers(1, pointerof(@quad_vbo))
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

      private def draw_quad
        LibGL.glBindVertexArray(@quad_vao)
        LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 6)
        LibGL.glBindVertexArray(0)
      end

      private def create_color_fbo(fbo : LibGL::GLuint*, texture : LibGL::GLuint*, w : Int32, h : Int32)
        prev = 0_i32
        LibGL.glGetIntegerv(LibGL::GL_FRAMEBUFFER_BINDING, pointerof(prev))

        LibGL.glGenFramebuffers(1, fbo)
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, fbo.value)

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

      private def cleanup_fbos
        {pointerof(@copy_fbo), pointerof(@bright_fbo), pointerof(@ping_fbo), pointerof(@pong_fbo)}.each do |fbo|
          LibGL.glDeleteFramebuffers(1, fbo) if fbo.value != 0
          fbo.value = 0_u32
        end
        {pointerof(@copy_texture), pointerof(@bright_texture), pointerof(@ping_texture), pointerof(@pong_texture)}.each do |tex|
          LibGL.glDeleteTextures(1, tex) if tex.value != 0
          tex.value = 0_u32
        end
      end
    end
  end
end
