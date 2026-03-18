module Tachyon
  module Rendering
    module Stages
      # Darkens the edges of the screen for a cinematic look
      class Vignette < Base
        Log = ::Log.for(self)

        @shader : Renderer::Shader? = nil
        @post_process : Renderer::PostProcess? = nil

        def initialize
          super("vignette")
        end

        def setup(context : Context)
          # Reuse quad from a PostProcess instance
          @post_process = Renderer::PostProcess.new
          @shader = Renderer::Shader.new(
            Renderer::Shader.load_file("quad.vert"),
            VIGNETTE_FRAG
          )
          Log.info { "Vignette pass initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          return frame unless Configuration.instance.vignette.enabled
          shader = @shader
          post_process = @post_process
          return frame unless shader && post_process

          post_process.ensure_initialized(frame.width, frame.height)

          # Copy current scene to temp texture
          LibGL.glBindFramebuffer(LibGL::GL_READ_FRAMEBUFFER, frame.buffer)
          LibGL.glBindFramebuffer(LibGL::GL_DRAW_FRAMEBUFFER, post_process.@copy_frame_buffer)
          LibGL.glBlitFramebuffer(0, 0, frame.width, frame.height, 0, 0, frame.width, frame.height,
            LibGL::GL_COLOR_BUFFER_BIT, LibGL::GL_LINEAR)

          # Render vignette back to main FBO
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)
          LibGL.glViewport(0, 0, frame.width, frame.height)

          shader.use
          LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, post_process.@copy_texture)
          shader.set_int("uScene", 0)
          shader.set_float("uIntensity", Configuration.instance.vignette.intensity)
          shader.set_float("uSmoothness", Configuration.instance.vignette.smoothness)

          post_process.draw_quad
          frame
        end

        def teardown
          @shader.try(&.destroy)
          @shader = nil
          @post_process.try(&.destroy)
          @post_process = nil
        end

        # Inline vignette fragment shader
        VIGNETTE_FRAG = <<-GLSL
          #version 410 core
          in vec2 vTexCoord;
          out vec4 fragColor;
          uniform sampler2D uScene;
          uniform float uIntensity;
          uniform float uSmoothness;
          void main() {
            vec4 color = texture(uScene, vTexCoord);
            vec2 uv = vTexCoord * 2.0 - 1.0;
            float dist = length(uv);
            float vignette = smoothstep(1.0, 1.0 - uSmoothness, dist * (1.0 + uIntensity));
            fragColor = vec4(color.rgb * vignette, color.a);
          }
        GLSL
      end
    end
  end
end
