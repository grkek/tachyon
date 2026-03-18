module Tachyon
  module Rendering
    module Stages
      # Abstract base class for a pipeline stage
      abstract class Base
        getter name : String
        property enabled : Bool = true

        def initialize(@name : String)
        end

        # Called once when the GL context is ready
        def setup(context : Context)
        end

        # Process the frame and return it for the next stage
        abstract def call(context : Context, frame : Frame) : Frame

        # Release GL resources
        def teardown
        end
      end
    end
  end
end
