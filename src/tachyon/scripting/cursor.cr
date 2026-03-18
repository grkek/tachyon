{% if flag?(:darwin) %}
  @[Link(framework: "CoreGraphics")]
  @[Link(framework: "CoreFoundation")]
  lib LibC
    struct CGPoint
      x : Float64
      y : Float64
    end

    fun CGWarpMouseCursorPosition(point : CGPoint) : Int32
    fun CGAssociateMouseAndMouseCursorPosition(connected : Int32) : Int32
    fun CGMainDisplayID : UInt32
    fun CGDisplayBounds(display : UInt32) : CGRect

    struct CGRect
      origin : CGPoint
      size : CGSize
    end

    struct CGSize
      width : Float64
      height : Float64
    end
  end
{% elsif flag?(:linux) %}
  @[Link("X11")]
  lib LibX11
    type Display = Void*
    type Window = UInt64

    fun XOpenDisplay(name : LibC::Char*) : Display
    fun XCloseDisplay(display : Display) : Int32
    fun XWarpPointer(display : Display, src_w : Window, dest_w : Window,
                     src_x : Int32, src_y : Int32, src_width : UInt32, src_height : UInt32,
                     dest_x : Int32, dest_y : Int32) : Int32
    fun XDefaultRootWindow(display : Display) : Window
    fun XFlush(display : Display) : Int32
  end
{% end %}

module Tachyon
  module Scripting
    class Cursor
      property locked : Bool = false
      @widget : Gtk::GLArea

      def initialize(@widget)
      end

      def lock(input : Scripting::InputState) : Nil
        return if @locked
        @widget.cursor = Gdk::Cursor.new_from_name("none", nil)
        @locked = true

        cx = (@widget.allocated_width // 2).to_f32
        cy = (@widget.allocated_height // 2).to_f32
        input.reset_mouse_position(cx, cy)

        warp(cx.to_i, cy.to_i)
      end

      def unlock : Nil
        return unless @locked
        @widget.cursor = nil
        @locked = false
      end

      def update(input : Scripting::InputState) : Nil
        return unless @locked

        w = @widget.allocated_width
        h = @widget.allocated_height
        cx = w // 2
        cy = h // 2
        margin = 100

        mx, my = input.mouse_position

        return if mx > margin && mx < (w - margin) && my > margin && my < (h - margin)

        input.reset_mouse_position(cx.to_f32, cy.to_f32)
        warp(cx, cy)
      end

      {% if flag?(:darwin) %}
        private def warp(cx : Int32, cy : Int32) : Nil
          if native = @widget.native
            if surface = native.surface
              # Get the window's screen position
              # For fullscreen, we need absolute screen coordinates
              root_x = 0.0
              root_y = 0.0

              # Try to get the surface origin in screen coordinates
              # GDK4 approach - get the toplevel and its position
              if toplevel = @widget.root.as?(Gtk::Window)
                # In fullscreen, the window is at 0,0 of the display
                if toplevel.fullscreened?
                  # Use just the widget-relative coordinates for fullscreen
                  abs_x = cx.to_f64
                  abs_y = cy.to_f64
                else
                  # Get surface transform for windowed mode
                  nx = 0.0
                  ny = 0.0
                  LibGtk.gtk_native_get_surface_transform(native.to_unsafe, pointerof(nx), pointerof(ny))
                  abs_x = nx + cx
                  abs_y = ny + cy
                end
              else
                nx = 0.0
                ny = 0.0
                LibGtk.gtk_native_get_surface_transform(native.to_unsafe, pointerof(nx), pointerof(ny))
                abs_x = nx + cx
                abs_y = ny + cy
              end

              LibC.CGAssociateMouseAndMouseCursorPosition(0)
              LibC.CGWarpMouseCursorPosition(LibC::CGPoint.new(x: abs_x, y: abs_y))
              LibC.CGAssociateMouseAndMouseCursorPosition(1)
            end
          end
        end
      {% elsif flag?(:linux) %}
        private def warp(cx : Int32, cy : Int32) : Nil
          display = Gdk::Display.default
          return unless display

          # Check if we're on Wayland or X11
          if display.is_a?(Gdk::WaylandDisplay) || display.class.name.includes?("Wayland")
            warp_wayland(cx, cy)
          else
            warp_x11(cx, cy)
          end
        end

        private def warp_x11(cx : Int32, cy : Int32) : Nil
          # Get window absolute position
          if native = @widget.native
            if surface = native.surface
              # For X11, we can get the window position and warp
              x_display = LibX11.XOpenDisplay(nil)
              return unless x_display

              begin
                # Get widget's position in root window coordinates
                root_x, root_y = get_widget_root_coords

                root_window = LibX11.XDefaultRootWindow(x_display)
                LibX11.XWarpPointer(x_display, 0_u64, root_window,
                  0, 0, 0_u32, 0_u32,
                  root_x + cx, root_y + cy)
                LibX11.XFlush(x_display)
              ensure
                LibX11.XCloseDisplay(x_display)
              end
            end
          end
        end

        private def warp_wayland(cx : Int32, cy : Int32) : Nil
          # Wayland does not allow arbitrary cursor warping for security reasons.
          # The best approach is to use pointer constraints via the
          # zwp_pointer_constraints_v1 protocol.
          #
          # For GTK4, you can try using the Gdk.Seat's grab functionality
          # or implement the pointer constraints protocol directly.
          #
          # As a workaround, we rely on relative mouse motion and
          # the hidden cursor - no actual warp is possible.

          # Alternative: Use libportal or implement zwp_pointer_constraints_v1
          # For games, consider using zwp_relative_pointer_v1 for delta input

          # If you have access to the wayland display/surface, you could:
          # 1. Get the wl_pointer from the seat
          # 2. Use zwp_pointer_constraints_v1 to lock the pointer to the surface
          # 3. Use zwp_relative_pointer_v1 for relative motion events
        end

        private def get_widget_root_coords : {Int32, Int32}
          # Compute the widget's position in root window coordinates
          x = 0
          y = 0

          widget = @widget.as(Gtk::Widget)

          # Walk up the widget hierarchy to accumulate offsets
          # and get the window's screen position
          if toplevel = widget.root.as?(Gtk::Window)
            if native = toplevel.as(Gtk::Native)
              nx = 0.0
              ny = 0.0
              LibGtk.gtk_native_get_surface_transform(native.to_unsafe, pointerof(nx), pointerof(ny))
              x = nx.to_i
              y = ny.to_i
            end
          end

          {x, y}
        end
      {% else %}
        private def warp(cx : Int32, cy : Int32) : Nil
          # Unsupported platform - no-op
        end
      {% end %}
    end
  end
end
