module Tachyon
  module Rendering
    module Stages
      # Renders the skybox behind all geometry
      class Skybox < Base
        Log = ::Log.for(self)

        @skybox : Renderer::Skybox? = nil

        def initialize
          super("skybox")
        end

        def setup(context : Context)
          skybox = Renderer::Skybox.new
          skybox.generate_gradient(
            Configuration.instance.skybox.top_color,
            Configuration.instance.skybox.bottom_color
          )
          @skybox = skybox
          Log.info { "Skybox pass initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          return frame unless Configuration.instance.skybox.enabled
          if skybox = @skybox
            LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)
            skybox.render(context.camera.view_matrix, context.camera.projection_matrix)
          end
          frame
        end

        # Swap in a new skybox at runtime
        def skybox=(value : Renderer::Skybox?)
          @skybox = value
        end

        def skybox : Renderer::Skybox?
          @skybox
        end

        def teardown
          @skybox.try(&.destroy)
          @skybox = nil
        end
      end
    end
  end
end
