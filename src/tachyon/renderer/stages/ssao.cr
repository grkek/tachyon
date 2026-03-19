module Tachyon
  module Rendering
    module Stages
      # Screen-space ambient occlusion pass
      class SSAO < Base
        Log = ::Log.for(self)

        @ssao : Renderer::SSAO? = nil
        @quad_vao : LibGL::GLuint = 0_u32
        @quad_vbo : LibGL::GLuint = 0_u32
        @depth_copy_frame_buffer : LibGL::GLuint = 0_u32
        @depth_copy_texture : LibGL::GLuint = 0_u32
        @depth_copy_width : Int32 = 0
        @depth_copy_height : Int32 = 0

        def initialize
          super("ssao")
        end

        def setup(context : Context)
          @ssao = Renderer::SSAO.new
          setup_quad
          Log.info { "SSAO pass initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          ssao = @ssao
          return frame unless ssao
          return frame unless Configuration.instance.ssao.enabled

          ssao.radius = Configuration.instance.ssao.radius
          ssao.bias = Configuration.instance.ssao.bias

          w = frame.width
          h = frame.height

          ensure_depth_copy(w, h)

          # Depth blit is still required — can't sample a depth renderbuffer as texture
          LibGL.glBindFramebuffer(LibGL::GL_READ_FRAMEBUFFER, frame.buffer)
          LibGL.glBindFramebuffer(LibGL::GL_DRAW_FRAMEBUFFER, @depth_copy_frame_buffer)
          LibGL.glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, LibGL::GL_DEPTH_BUFFER_BIT, LibGL::GL_NEAREST)

          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)

          ssao.apply(
            @quad_vao, @depth_copy_texture,
            context.camera.projection_matrix, context.camera.view_matrix,
            w, h
          )

          frame.ssao_texture = ssao.texture
          frame.depth_texture = @depth_copy_texture
          frame
        end

        def teardown
          @ssao.try(&.destroy)
          @ssao = nil
          if @depth_copy_texture != 0
            LibGL.glDeleteTextures(1, pointerof(@depth_copy_texture))
            LibGL.glDeleteFramebuffers(1, pointerof(@depth_copy_frame_buffer))
            @depth_copy_texture = 0_u32
            @depth_copy_frame_buffer = 0_u32
          end
          LibGL.glDeleteVertexArrays(1, pointerof(@quad_vao)) if @quad_vao != 0
          LibGL.glDeleteBuffers(1, pointerof(@quad_vbo)) if @quad_vbo != 0
          @quad_vao = 0_u32
          @quad_vbo = 0_u32
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
