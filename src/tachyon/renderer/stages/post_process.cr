module Tachyon
  module Rendering
    module Stages
      # Bloom, tone mapping, and FXAA post-processing stage
      class PostProcess < Base
        Log = ::Log.for(self)

        @post_process : Renderer::PostProcess? = nil

        def initialize
          super("post_process")
        end

        def setup(context : Context)
          @post_process = Renderer::PostProcess.new
          Log.info { "Post-process pass initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          post_process = @post_process
          return frame unless post_process

          post_process.apply(frame)
          frame
        end

        def teardown
          @post_process.try(&.destroy)
          @post_process = nil
        end
      end
    end
  end
end
