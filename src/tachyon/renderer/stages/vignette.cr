module Tachyon
  module Rendering
    module Stages
      # Darkens the edges of the screen for a cinematic look
      class Vignette < Base
        Log = ::Log.for(self)

        @shader : Renderer::Shader? = nil
        @quad_vao : LibGL::GLuint = 0_u32
        @quad_vbo : LibGL::GLuint = 0_u32

        def initialize
          super("vignette")
        end

        def setup(context : Context)
          @shader = Renderer::Shader.new(
            Renderer::Shader.load_file("quad.vert"),
            VIGNETTE_FRAG
          )
          setup_quad
          Log.info { "Vignette pass initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          return frame unless Configuration.instance.vignette.enabled
          shader = @shader
          return frame unless shader

          frame.swap!

          LibGL.glDisable(LibGL::GL_DEPTH_TEST)
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)
          LibGL.glViewport(0, 0, frame.width, frame.height)

          shader.use
          LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, frame.alt_texture)
          shader.set_int("uScene", 0)
          shader.set_float("uIntensity", Configuration.instance.vignette.intensity)
          shader.set_float("uSmoothness", Configuration.instance.vignette.smoothness)

          LibGL.glBindVertexArray(@quad_vao)
          LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 6)
          LibGL.glBindVertexArray(0)

          LibGL.glEnable(LibGL::GL_DEPTH_TEST)

          frame
        end

        def teardown
          @shader.try(&.destroy)
          @shader = nil
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
