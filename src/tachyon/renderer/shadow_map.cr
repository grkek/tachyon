module Tachyon
  module Renderer
    class ShadowMap
      Log = ::Log.for(self)

      getter fbo : LibGL::GLuint = 0_u32
      getter prev_fbo : Int32 = 0
      getter depth_texture : LibGL::GLuint = 0_u32
      getter width : Int32
      getter height : Int32

      @shader : Shader

      def initialize(@width : Int32 = 2048, @height : Int32 = 2048)
        # Create depth texture
        LibGL.glGenTextures(1, pointerof(@depth_texture))
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @depth_texture)
        LibGL.glTexImage2D(
          LibGL::GL_TEXTURE_2D, 0, LibGL::GL_DEPTH_COMPONENT24.to_i32,
          @width, @height, 0,
          LibGL::GL_DEPTH_COMPONENT, LibGL::GL_FLOAT,
          Pointer(Void).null
        )
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_NEAREST.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_NEAREST.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)

        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, 0)

        # Create FBO
        LibGL.glGenFramebuffers(1, pointerof(@fbo))
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @fbo)
        LibGL.glFramebufferTexture2D(LibGL::GL_FRAMEBUFFER, LibGL::GL_DEPTH_ATTACHMENT, LibGL::GL_TEXTURE_2D, @depth_texture, 0)
        LibGL.glDrawBuffer(LibGL::GL_NONE)
        LibGL.glReadBuffer(LibGL::GL_NONE)

        status = LibGL.glCheckFramebufferStatus(LibGL::GL_FRAMEBUFFER)
        unless status == LibGL::GL_FRAMEBUFFER_COMPLETE
          raise "Shadow map framebuffer incomplete: 0x#{status.to_s(16)}"
        end

        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, 0)

        @shader = Shader.new(Constants::SHADOW_DEPTH_VERTEX, Constants::SHADOW_DEPTH_FRAGMENT)
      end

      def begin_pass(light_space_matrix : Math::Matrix4)
        LibGL.glGetIntegerv(LibGL::GL_FRAMEBUFFER_BINDING, pointerof(@prev_fbo))

        LibGL.glViewport(0, 0, @width, @height)
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @fbo)
        LibGL.glClear(LibGL::GL_DEPTH_BUFFER_BIT)

        # Reduce shadow acne
        LibGL.glEnable(LibGL::GL_POLYGON_OFFSET_FILL)
        LibGL.glPolygonOffset(2.0f32, 4.0f32)

        @shader.use
        @shader.set_matrix4("uLightSpaceMatrix", light_space_matrix)
      end

      def render_node(node : Scene::Node)
        @shader.set_matrix4("uModel", node.world_matrix)
        node.mesh.not_nil!.draw
      end

      def end_pass
        LibGL.glDisable(LibGL::GL_POLYGON_OFFSET_FILL)
        # Restore GTK's framebuffer instead of 0
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @prev_fbo.to_u32)
      end

      def bind_texture(unit : Int32 = 5)
        LibGL.glActiveTexture(LibGL::GL_TEXTURE0 + unit.to_u32)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @depth_texture)
      end

      def destroy
        @shader.destroy
        LibGL.glDeleteFramebuffers(1, pointerof(@fbo))
        LibGL.glDeleteTextures(1, pointerof(@depth_texture))
      end
    end
  end
end
