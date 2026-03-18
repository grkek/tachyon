module Tachyon
  module Rendering
    module Stages
      # PBR geometry pass - renders opaque then transparent objects
      class Geometry < Base
        Log = ::Log.for(self)

        @shader : Renderer::Shader? = nil
        @default_texture : Renderer::Texture? = nil
        @dummy_cubemap : LibGL::GLuint = 0_u32

        def initialize
          super("geometry")
        end

        def setup(context : Context)
          # Load PBR shader from disk
          @shader = Renderer::Shader.from_file("pbr")
          @default_texture = Renderer::Texture.solid_color(255_u8, 255_u8, 255_u8, 255_u8)
          create_dummy_cubemap
          Log.info { "Geometry pass initialized (shader: #{@shader.try(&.program)})" }
        end

        def call(context : Context, frame : Frame) : Frame
          shader = @shader
          return frame unless shader

          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)
          LibGL.glViewport(0, 0, frame.width, frame.height)
          LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT | LibGL::GL_DEPTH_BUFFER_BIT)

          shader.use

          set_camera_uniforms(shader, context, frame)
          set_light_uniforms(shader, context)
          set_shadow_uniforms(shader, frame)
          set_ssao_uniforms(shader, frame)
          set_ibl_uniforms(shader, context)
          set_fog_uniforms(shader, context)

          render_opaque(shader, context)
          render_transparent(shader, context)

          frame
        end

        def teardown
          @shader.try(&.destroy)
          @shader = nil
          @default_texture.try(&.destroy)
          @default_texture = nil
          if @dummy_cubemap != 0
            LibGL.glDeleteTextures(1, pointerof(@dummy_cubemap))
            @dummy_cubemap = 0_u32
          end
        end

        # Camera and projection uniforms
        private def set_camera_uniforms(shader : Renderer::Shader, context : Context, frame : Frame)
          shader.set_matrix4("uView", context.camera.view_matrix)
          shader.set_matrix4("uProjection", context.camera.projection_matrix)
          shader.set_vector3("uViewPos", context.camera.position)
          shader.set_vector3("uAmbientColor", Configuration.instance.ambient.color)
          shader.set_matrix4("uLightSpaceMatrix", frame.light_space_matrix)
        end

        # Forward light array to the PBR shader
        private def set_light_uniforms(shader : Renderer::Shader, context : Context)
          context.light_manager.apply(shader)
        end

        # Bind shadow depth texture produced by the shadow stage
        private def set_shadow_uniforms(shader : Renderer::Shader, frame : Frame)
          if frame.shadow_depth_texture != 0
            LibGL.glActiveTexture(LibGL::GL_TEXTURE5)
            LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, frame.shadow_depth_texture)
            shader.set_int("uShadowMap", 5)
            shader.set_int("uHasShadowMap", 1)
          else
            shader.set_int("uHasShadowMap", 0)
          end
        end

        # Bind SSAO texture produced by the SSAO stage
        private def set_ssao_uniforms(shader : Renderer::Shader, frame : Frame)
          if frame.ssao_texture != 0
            LibGL.glActiveTexture(LibGL::GL_TEXTURE6)
            LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, frame.ssao_texture)
            shader.set_int("uSSAOMap", 6)
            shader.set_int("uHasSSAO", 1)
          else
            shader.set_int("uHasSSAO", 0)
          end
        end

        # Bind IBL cubemaps or fall back to dummy black cubemaps
        private def set_ibl_uniforms(shader : Renderer::Shader, context : Context)
          LibGL.glActiveTexture(LibGL::GL_TEXTURE0 + 7_u32)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @dummy_cubemap)
          LibGL.glActiveTexture(LibGL::GL_TEXTURE0 + 8_u32)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @dummy_cubemap)
          shader.set_int("uIrradianceMap", 7)
          shader.set_int("uPrefilterMap", 8)
          shader.set_int("uHasIBL", 0)
        end

        # Set fog uniforms from engine settings
        private def set_fog_uniforms(shader : Renderer::Shader, context : Context)
          c = Configuration.instance

          if c.fog.enabled
            shader.set_int("uFogEnabled", 1)
            shader.set_vector3("uFogColor", c.fog.color)
            shader.set_float("uFogNear", c.fog.near)
            shader.set_float("uFogFar", c.fog.far)
            shader.set_float("uFogDensity", c.fog.density)
            shader.set_int("uFogMode", c.fog.mode)
          else
            shader.set_int("uFogEnabled", 0)
          end
        end

        # Draw all opaque objects (opacity == 1.0)
        private def render_opaque(shader : Renderer::Shader, context : Context)
          context.scene.each_renderable do |node|
            mat = node.material
            next if mat && mat.opacity < 1.0f32
            render_node(shader, node, mat)
          end
          LibGL.glPolygonMode(LibGL::GL_FRONT_AND_BACK, LibGL::GL_FILL)
        end

        # Draw transparent objects sorted back-to-front
        private def render_transparent(shader : Renderer::Shader, context : Context)
          LibGL.glEnable(LibGL::GL_BLEND)
          LibGL.glBlendFunc(LibGL::GL_SRC_ALPHA, LibGL::GL_ONE_MINUS_SRC_ALPHA)
          LibGL.glDepthMask(LibGL::GL_FALSE)

          context.scene.each_renderable do |node|
            mat = node.material
            next unless mat && mat.opacity < 1.0f32
            render_node(shader, node, mat)
          end

          LibGL.glPolygonMode(LibGL::GL_FRONT_AND_BACK, LibGL::GL_FILL)
          LibGL.glDepthMask(LibGL::GL_TRUE)
          LibGL.glDisable(LibGL::GL_BLEND)
        end

        # Render a single node with its material
        private def render_node(shader : Renderer::Shader, node : Scene::Node, mat : Renderer::Material?)
          shader.set_matrix4("uModel", node.world_matrix)
          shader.set_matrix4("uNormalMatrix", node.world_normal_matrix)
          shader.set_vector2("uTextureScale", 1.0f32, 1.0f32)

          if dt = @default_texture
            (0..4).each { |i| dt.bind(i) }
          end

          if mat
            LibGL.glPolygonMode(LibGL::GL_FRONT_AND_BACK, mat.wireframe ? LibGL::GL_LINE : LibGL::GL_FILL)
            mat.apply(shader)
          end

          node.mesh.try(&.draw)
        end

        # 1x1 black cubemap used when IBL is not loaded
        private def create_dummy_cubemap
          LibGL.glGenTextures(1, pointerof(@dummy_cubemap))
          LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @dummy_cubemap)
          black = StaticArray[0_u8, 0_u8, 0_u8, 0_u8]
          6.times do |i|
            LibGL.glTexImage2D(
              LibGL::GL_TEXTURE_CUBE_MAP_POSITIVE_X + i.to_u32, 0,
              LibGL::GL_RGBA.to_i32, 1, 1, 0, LibGL::GL_RGBA,
              LibGL::GL_UNSIGNED_BYTE, black.to_unsafe.as(Pointer(Void))
            )
          end
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
        end
      end
    end
  end
end
