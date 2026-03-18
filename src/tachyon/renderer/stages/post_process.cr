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
          if post_process = @post_process
            post_process.apply(frame.buffer.to_i32, frame.width, frame.height)
          end

          frame
        end

        # Expose for stages that need the quad VAO (e.g. SSAO)
        def post_process : Renderer::PostProcess?
          @post_process
        end

        def teardown
          @post_process.try(&.destroy)
          @post_process = nil
        end
      end
    end
  end
end
