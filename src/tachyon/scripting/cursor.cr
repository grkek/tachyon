{% if flag?(:darwin) %}
  @[Link(framework: "CoreGraphics")]
  lib LibC
    struct CGPoint
      x : Float64
      y : Float64
    end

    fun CGWarpMouseCursorPosition(point : CGPoint) : Int32
    fun CGAssociateMouseAndMouseCursorPosition(connected : Int32) : Int32
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

        {% if flag?(:darwin) %}
          warp(cx.to_i, cy.to_i)
        {% end %}
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

        {% if flag?(:darwin) %}
          warp(cx, cy)
        {% end %}
      end

      {% if flag?(:darwin) %}
        private def warp(cx : Int32, cy : Int32) : Nil
          if native = @widget.native
            nx = 0.0
            ny = 0.0
            LibGtk.gtk_native_get_surface_transform(native.to_unsafe, pointerof(nx), pointerof(ny))
            LibC.CGWarpMouseCursorPosition(
              LibC::CGPoint.new(x: nx + cx, y: ny + cy)
            )
            LibC.CGAssociateMouseAndMouseCursorPosition(0)
            LibC.CGAssociateMouseAndMouseCursorPosition(1)
          end
        end
      {% end %}
    end
  end
end
