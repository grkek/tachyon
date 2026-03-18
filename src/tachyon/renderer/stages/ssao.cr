module Tachyon
  module Rendering
    module Stages
      # Screen-space ambient occlusion pass
      class SSAO < Base
        Log = ::Log.for(self)

        @ssao : Renderer::SSAO? = nil
        @post_process : Renderer::PostProcess? = nil
        @depth_copy_frame_buffer : LibGL::GLuint = 0_u32
        @depth_copy_texture : LibGL::GLuint = 0_u32
        @depth_copy_width : Int32 = 0
        @depth_copy_height : Int32 = 0

        def initialize
          super("ssao")
        end

        def setup(context : Context)
          @ssao = Renderer::SSAO.new
          # Need a quad VAO for the fullscreen pass
          @post_process = Renderer::PostProcess.new
          Log.info { "SSAO pass initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          ssao = @ssao
          post_process = @post_process
          return frame unless ssao && post_process
          return frame unless Configuration.instance.ssao.enabled

          # Sync radius/bias from live settings
          ssao.radius = Configuration.instance.ssao.radius
          ssao.bias = Configuration.instance.ssao.bias

          w = frame.width
          h = frame.height

          ensure_depth_copy(w, h)

          # Blit depth from current framebuffer into our copy
          LibGL.glBindFramebuffer(LibGL::GL_READ_FRAMEBUFFER, frame.buffer)
          LibGL.glBindFramebuffer(LibGL::GL_DRAW_FRAMEBUFFER, @depth_copy_frame_buffer)
          LibGL.glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, LibGL::GL_DEPTH_BUFFER_BIT, LibGL::GL_NEAREST)

          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)

          # Run the SSAO shader
          ssao.apply(
            post_process.quad_vao, @depth_copy_texture,
            context.camera.projection_matrix, context.camera.view_matrix,
            w, h
          )

          # Write SSAO texture for downstream geometry pass
          frame.ssao_texture = ssao.texture
          frame.depth_texture = @depth_copy_texture
          frame
        end

        def teardown
          @ssao.try(&.destroy)
          @ssao = nil
          @post_process.try(&.destroy)
          @post_process = nil
          if @depth_copy_texture != 0
            LibGL.glDeleteTextures(1, pointerof(@depth_copy_texture))
            LibGL.glDeleteFramebuffers(1, pointerof(@depth_copy_frame_buffer))
            @depth_copy_texture = 0_u32
            @depth_copy_frame_buffer = 0_u32
          end
        end

        private def ensure_depth_copy(width : Int32, height : Int32)
          return if @depth_copy_texture != 0 && width == @depth_copy_width && height == @depth_copy_height

          if @depth_copy_texture == 0
            LibGL.glGenTextures(1, pointerof(@depth_copy_texture))
            LibGL.glGenFramebuffers(1, pointerof(@depth_copy_frame_buffer))
          end

          @depth_copy_width = width
          @depth_copy_height = height

          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @depth_copy_texture)
          LibGL.glTexImage2D(
            LibGL::GL_TEXTURE_2D, 0, LibGL::GL_DEPTH_COMPONENT24.to_i32,
            width, height, 0, LibGL::GL_DEPTH_COMPONENT, LibGL::GL_FLOAT, Pointer(Void).null
          )
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_NEAREST.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_NEAREST.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)

          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @depth_copy_frame_buffer)
          LibGL.glFramebufferTexture2D(
            LibGL::GL_FRAMEBUFFER, LibGL::GL_DEPTH_ATTACHMENT,
            LibGL::GL_TEXTURE_2D, @depth_copy_texture, 0
          )
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, 0)
        end
      end
    end
  end
end
