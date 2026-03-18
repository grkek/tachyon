module Tachyon
  module Rendering
    module Stages
      # Renders the shadow depth map and writes results into the Frame
      class Shadow < Base
        Log = ::Log.for(self)

        @frame_buffer : LibGL::GLuint = 0_u32
        @depth_texture : LibGL::GLuint = 0_u32
        @shader : Renderer::Shader? = nil
        @width : Int32 = 0
        @height : Int32 = 0

        def initialize
          super("shadow")
        end

        def setup(context : Context)
          @width = Configuration.instance.shadow.resolution
          @height = Configuration.instance.shadow.resolution

          create_depth_texture
          create_framebuffer

          # Load shadow shader from disk
          @shader = Renderer::Shader.from_file("shadow_depth")
          Log.info { "Shadow pass initialized (#{@width}x#{@height})" }
        end

        def call(context : Context, frame : Frame) : Frame
          shader = @shader
          return frame unless shader
          return frame unless Configuration.instance.shadow.enabled

          # Only directional lights cast shadows
          dir = context.light_manager.directional
          return frame unless dir

          # Compute shadow frustum centered on camera target
          focus = context.camera.target
          distance = (context.camera.position - focus).magnitude
          radius = ::Math.max(distance * 2.0f32, 50.0f32)
          light_space_matrix = dir.shadow_view_projection(focus, radius)

          # Render into shadow framebuffer
          LibGL.glViewport(0, 0, @width, @height)
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @frame_buffer)
          LibGL.glClear(LibGL::GL_DEPTH_BUFFER_BIT)

          # Reduce shadow acne
          LibGL.glEnable(LibGL::GL_POLYGON_OFFSET_FILL)
          LibGL.glPolygonOffset(2.0f32, 4.0f32)

          shader.use
          shader.set_matrix4("uLightSpaceMatrix", light_space_matrix)

          context.scene.each_renderable do |node|
            shader.set_matrix4("uModel", node.world_matrix)
            node.mesh.try(&.draw)
          end

          LibGL.glDisable(LibGL::GL_POLYGON_OFFSET_FILL)

          # Restore the incoming framebuffer
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)

          # Write outputs for downstream stages
          frame.light_space_matrix = light_space_matrix
          frame.shadow_depth_texture = @depth_texture
          frame
        end

        def teardown
          @shader.try(&.destroy)
          @shader = nil
          if @frame_buffer != 0
            LibGL.glDeleteFramebuffers(1, pointerof(@frame_buffer))
            @frame_buffer = 0_u32
          end
          if @depth_texture != 0
            LibGL.glDeleteTextures(1, pointerof(@depth_texture))
            @depth_texture = 0_u32
          end
        end

        private def create_depth_texture
          LibGL.glGenTextures(1, pointerof(@depth_texture))
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @depth_texture)
          LibGL.glTexImage2D(
            LibGL::GL_TEXTURE_2D, 0, LibGL::GL_DEPTH_COMPONENT24.to_i32,
            @width, @height, 0,
            LibGL::GL_DEPTH_COMPONENT, LibGL::GL_FLOAT, Pointer(Void).null
          )
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_NEAREST.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_NEAREST.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, 0)
        end

        private def create_framebuffer
          LibGL.glGenFramebuffers(1, pointerof(@frame_buffer))
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @frame_buffer)
          LibGL.glFramebufferTexture2D(LibGL::GL_FRAMEBUFFER, LibGL::GL_DEPTH_ATTACHMENT, LibGL::GL_TEXTURE_2D, @depth_texture, 0)
          LibGL.glDrawBuffer(LibGL::GL_NONE)
          LibGL.glReadBuffer(LibGL::GL_NONE)

          status = LibGL.glCheckFramebufferStatus(LibGL::GL_FRAMEBUFFER)
          unless status == LibGL::GL_FRAMEBUFFER_COMPLETE
            raise "Shadow framebuffer incomplete: 0x#{status.to_s(16)}"
          end

          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, 0)
        end
      end
    end
  end
end
