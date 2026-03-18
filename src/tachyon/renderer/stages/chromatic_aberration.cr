module Tachyon
  module Rendering
    module Stages
      # Splits RGB channels at screen edges for a lens distortion effect
      class ChromaticAberration < Base
        Log = ::Log.for(self)

        @shader : Renderer::Shader? = nil
        @post_process : Renderer::PostProcess? = nil

        def initialize
          super("chromatic_aberration")
        end

        def setup(context : Context)
          @post_process = Renderer::PostProcess.new
          @shader = Renderer::Shader.new(
            Renderer::Shader.load_file("quad.vert"),
            CHROMATIC_FRAG
          )
          Log.info { "Chromatic aberration pass initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          return frame unless Configuration.instance.chromatic_aberration.enabled
          shader = @shader
          post_process = @post_process
          return frame unless shader && post_process

          post_process.ensure_initialized(frame.width, frame.height)

          # Copy scene to temp texture
          LibGL.glBindFramebuffer(LibGL::GL_READ_FRAMEBUFFER, frame.buffer)
          LibGL.glBindFramebuffer(LibGL::GL_DRAW_FRAMEBUFFER, post_process.@copy_frame_buffer)
          LibGL.glBlitFramebuffer(0, 0, frame.width, frame.height, 0, 0, frame.width, frame.height,
            LibGL::GL_COLOR_BUFFER_BIT, LibGL::GL_LINEAR)

          # Render chromatic aberration back
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)
          LibGL.glViewport(0, 0, frame.width, frame.height)

          shader.use
          LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, post_process.@copy_texture)
          shader.set_int("uScene", 0)
          shader.set_float("uStrength", Configuration.instance.chromatic_aberration.strength)

          post_process.draw_quad
          frame
        end

        def teardown
          @shader.try(&.destroy)
          @shader = nil
          @post_process.try(&.destroy)
          @post_process = nil
        end

        # Inline chromatic aberration fragment shader
        CHROMATIC_FRAG = <<-GLSL
          #version 410 core
          in vec2 vTexCoord;
          out vec4 fragColor;
          uniform sampler2D uScene;
          uniform float uStrength;
          void main() {
            vec2 dir = vTexCoord - vec2(0.5);
            float dist = length(dir);
            vec2 offset = dir * dist * uStrength;
            float r = texture(uScene, vTexCoord + offset).r;
            float g = texture(uScene, vTexCoord).g;
            float b = texture(uScene, vTexCoord - offset).b;
            float a = texture(uScene, vTexCoord).a;
            fragColor = vec4(r, g, b, a);
          }
        GLSL
      end
    end
  end
end
