module Tachyon
  module Renderer
    module Stages
      class Overlay < Base
        Log = ::Log.for(self)

        @gui : GraphicalUserInterface::Base? = nil

        def initialize
          super("overlay")
        end

        def setup(context : Context)
          @gui = GraphicalUserInterface::Base.new
          Log.info { "GUI overlay initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          gui = @gui
          commands = context.commands
          return frame unless gui
          return frame if commands.empty?

          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)
          gui.begin_frame(frame.width, frame.height)

          commands.each do |cmd|
            gui.process_command(cmd)
          end

          gui.end_frame
          frame
        end

        def gui : GraphicalUserInterface::Base?
          @gui
        end

        def font_manager : GraphicalUserInterface::FontManager?
          @gui.try(&.font_manager)
        end

        def teardown
          @gui.try(&.destroy)
          @gui = nil
        end
      end
    end
  end
end
