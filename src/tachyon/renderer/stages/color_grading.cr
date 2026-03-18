module Tachyon
  module Rendering
    module Stages
      # Applies exposure, contrast, saturation, and color tint adjustments
      class ColorGrading < Base
        Log = ::Log.for(self)

        @shader : Renderer::Shader? = nil
        @post_process : Renderer::PostProcess? = nil

        def initialize
          super("color_grading")
        end

        def setup(context : Context)
          @post_process = Renderer::PostProcess.new
          @shader = Renderer::Shader.new(
            Renderer::Shader.load_file("quad.vert"),
            COLOR_GRADING_FRAG
          )
          Log.info { "Color grading pass initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          return frame unless Configuration.instance.color_grading.enabled
          shader = @shader
          pp = @post_process
          return frame unless shader && pp

          pp.ensure_initialized(frame.width, frame.height)

          # Copy scene to temp texture
          LibGL.glBindFramebuffer(LibGL::GL_READ_FRAMEBUFFER, frame.buffer)
          LibGL.glBindFramebuffer(LibGL::GL_DRAW_FRAMEBUFFER, pp.@copy_frame_buffer)
          LibGL.glBlitFramebuffer(0, 0, frame.width, frame.height, 0, 0, frame.width, frame.height,
            LibGL::GL_COLOR_BUFFER_BIT, LibGL::GL_LINEAR)

          # Render color grading back to main FBO
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)
          LibGL.glViewport(0, 0, frame.width, frame.height)

          shader.use
          LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, pp.@copy_texture)
          shader.set_int("uScene", 0)
          shader.set_float("uExposure", Configuration.instance.color_grading.exposure)
          shader.set_float("uContrast", Configuration.instance.color_grading.contrast)
          shader.set_float("uSaturation", Configuration.instance.color_grading.saturation)
          shader.set_vector3("uTint", Configuration.instance.color_grading.tint)

          pp.draw_quad
          frame
        end

        def teardown
          @shader.try(&.destroy)
          @shader = nil
          @post_process.try(&.destroy)
          @post_process = nil
        end

        # Inline color grading fragment shader
        COLOR_GRADING_FRAG = <<-GLSL
          #version 410 core
          in vec2 vTexCoord;
          out vec4 fragColor;

          uniform sampler2D uScene;
          uniform float uExposure;
          uniform float uContrast;
          uniform float uSaturation;
          uniform vec3 uTint;

          void main() {
            vec3 color = texture(uScene, vTexCoord).rgb;

            // Exposure
            color *= uExposure;

            // Contrast around mid-grey
            color = (color - 0.5) * uContrast + 0.5;

            // Saturation via luminance
            float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
            color = mix(vec3(lum), color, uSaturation);

            // Color tint
            color *= uTint;

            fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
          }
        GLSL
      end
    end
  end
end
