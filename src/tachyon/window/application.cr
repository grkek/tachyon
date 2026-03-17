module Tachyon
  module Window
    class Application
      @app : Gtk::Application
      @viewport : Viewport? = nil
      @engine : Scripting::Engine? = nil
      @runtime : Medusa::Runtime? = nil
      @context : Medusa::Context? = nil
      @script_path : String?
      @fixed_timestep : Float64 = 1.0 / 60.0
      @physics_accumulator : Float64 = 0.0

      def initialize(@script_path : String? = nil)
        @app = Gtk::Application.new("com.tachyon.engine", Gio::ApplicationFlags::None)
        @app.activate_signal.connect { on_activate }
      end

      def run
        @app.run(ARGV)
      end

      private def on_activate
        window = Gtk::ApplicationWindow.new(@app)
        window.title = "Tachyon Engine"
        window.set_default_size(1280, 720)

        viewport = Viewport.new(id: "main")
        @viewport = viewport

        viewport.gl_area.realize_signal.connect { on_viewport_ready(viewport) }

        window.child = viewport.gl_area
        window.present
      end

      private def on_viewport_ready(viewport : Viewport)
        setup_input(viewport)
        setup_scripting(viewport)
      end

      private def setup_input(viewport : Viewport)
        key_controller = Gtk::EventControllerKey.new

        key_controller.key_pressed_signal.connect do |keyval, keycode, state|
          if engine = @engine
            key_name = Gdk.keyval_name(keyval)
            engine.input.on_key_press(key_name) if key_name
          end
          false
        end

        key_controller.key_released_signal.connect do |keyval, keycode, state|
          if engine = @engine
            key_name = Gdk.keyval_name(keyval)
            engine.input.on_key_release(key_name) if key_name
          end
        end

        viewport.gl_area.add_controller(key_controller)

        motion_controller = Gtk::EventControllerMotion.new

        motion_controller.motion_signal.connect do |x, y|
          if engine = @engine
            engine.input.on_mouse_move(x.to_f32, y.to_f32)
          end
        end

        viewport.gl_area.add_controller(motion_controller)

        click_controller = Gtk::GestureClick.new

        click_controller.pressed_signal.connect do |n_press, x, y|
          if engine = @engine
            engine.input.on_mouse_button_press(0)
          end
          viewport.gl_area.grab_focus
        end

        click_controller.released_signal.connect do |n_press, x, y|
          if engine = @engine
            engine.input.on_mouse_button_release(0)
          end
        end

        viewport.gl_area.add_controller(click_controller)
      end

      private def setup_scripting(viewport : Viewport)
        engine = Scripting::Engine.new(viewport.scene, viewport.camera, viewport.light_manager)
        engine.canvas = viewport.canvas_2d
        engine.audio = viewport.audio
        @engine = engine

        runtime = Medusa::Runtime.new
        context = Medusa::Context.new(runtime.to_unsafe)

        engine.register(context)

        if script_path = @script_path
          if File.exists?(script_path)
            source = File.read(script_path)
            engine.load_script(context, source, script_path)
            engine.call_on_start
          end
        end

        viewport.on_before_render do |dt|
          engine.commands.clear

          engine.call_on_update(dt)

          @physics_accumulator += dt

          while @physics_accumulator >= @fixed_timestep
            engine.call_on_fixed_update(@fixed_timestep)
            @physics_accumulator -= @fixed_timestep
          end

          viewport.submit_commands(engine.commands)
        end
      end
    end
  end
end
