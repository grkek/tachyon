module Tachyon
  module Rendering
    module Stages
      # Draws 2D GUI elements (rects, text) on top of the 3D scene
      class Overlay < Base
        Log = ::Log.for(self)

        @gui : Renderer::GraphicalUserInterface? = nil

        def initialize
          super("overlay")
        end

        def setup(context : Context)
          @gui = Renderer::GraphicalUserInterface.new
          Log.info { "GUI overlay pass initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          gui = @gui
          commands = context.commands
          return frame unless gui
          return frame if commands.empty?

          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)
          gui.begin_frame(frame.width, frame.height)

          commands.each do |cmd|
            case cmd.command
            when Scripting::GUI::Command::Rect
              gui.draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, cmd.r, cmd.g, cmd.b, cmd.a)
            when Scripting::GUI::Command::Text
              gui.draw_text(cmd.text, cmd.x, cmd.y, cmd.scale, cmd.r, cmd.g, cmd.b, cmd.a)
            end
          end

          gui.end_frame
          frame
        end

        # Expose for scripting
        def gui : Renderer::GraphicalUserInterface?
          @gui
        end

        def teardown
          @gui.try(&.destroy)
          @gui = nil
        end
      end
    end
  end
end
