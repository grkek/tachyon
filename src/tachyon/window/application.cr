module Tachyon
  module Window
    # Top-level GTK application that wires viewport, scripting, and input together
    class Application
      Log = ::Log.for(self)

      @app : Gtk::Application
      @viewport : Viewport? = nil
      @scripting_engine : Scripting::Engine? = nil
      @runtime : Medusa::Runtime? = nil
      @context : Medusa::Context? = nil
      @script_path : String?
      @physics_accumulator : Float64 = 0.0

      def initialize(@script_path : String? = nil)
        @app = Gtk::Application.new("com.tachyon.engine", Gio::ApplicationFlags::None)
        @app.activate_signal.connect { on_activate }
      end

      def run
        @app.run(ARGV)
      end

      # Expose the pipeline for runtime stage manipulation from outside
      def pipeline : Rendering::Pipeline?
        @viewport.try(&.pipeline)
      end

      private def on_activate
        window = Gtk::ApplicationWindow.new(@app)
        window.title = "Tachyon Engine"
        window.set_default_size(1280, 720)

        viewport = Viewport.new(id: "main")
        @viewport = viewport

        viewport.area.realize_signal.connect { on_viewport_ready(viewport) }

        window.child = viewport.area
        window.present
      end

      private def on_viewport_ready(viewport : Viewport)
        setup_input(viewport)
        setup_scripting(viewport)
        Log.info { "Application ready" }
      end

      private def setup_input(viewport : Viewport)
        setup_keyboard_input(viewport)
        setup_mouse_input(viewport)
        setup_click_input(viewport)
      end

      private def setup_keyboard_input(viewport : Viewport)
        key_controller = Gtk::EventControllerKey.new

        key_controller.key_pressed_signal.connect do |keyval, keycode, state|
          if engine = @scripting_engine
            key_name = Gdk.keyval_name(keyval)
            engine.input_state.on_key_press(key_name) if key_name
          end
          false
        end

        key_controller.key_released_signal.connect do |keyval, keycode, state|
          if engine = @scripting_engine
            key_name = Gdk.keyval_name(keyval)
            engine.input_state.on_key_release(key_name) if key_name
          end
        end

        viewport.area.add_controller(key_controller)
      end

      private def setup_mouse_input(viewport : Viewport)
        motion_controller = Gtk::EventControllerMotion.new

        motion_controller.motion_signal.connect do |x, y|
          if engine = @scripting_engine
            engine.input_state.on_mouse_move(x.to_f32, y.to_f32)
          end
        end

        viewport.area.add_controller(motion_controller)
      end

      private def setup_click_input(viewport : Viewport)
        click_controller = Gtk::GestureClick.new

        click_controller.pressed_signal.connect do |n_press, x, y|
          if engine = @scripting_engine
            engine.input_state.on_mouse_button_press(0)
          end
          viewport.area.grab_focus
        end

        click_controller.released_signal.connect do |n_press, x, y|
          if engine = @scripting_engine
            engine.input_state.on_mouse_button_release(0)
          end
        end

        viewport.area.add_controller(click_controller)
      end

      private def setup_scripting(viewport : Viewport)
        engine = Scripting::Engine.new(viewport.scene, viewport.camera, viewport.light_manager)

        # Wire subsystems from stages into the scripting engine
        engine.canvas = viewport.canvas_2d
        engine.audio_engine = viewport.audio_engine
        engine.viewport = viewport

        @scripting_engine = engine

        # Initialize the JS runtime
        runtime = Medusa::Runtime.new
        context = Medusa::Context.new(runtime.to_unsafe)
        @runtime = runtime
        @context = context

        engine.register(context)
        load_and_start_script(engine, context)
        setup_frame_loop(engine, viewport)
      end

      private def load_and_start_script(engine : Scripting::Engine, context : Medusa::Context)
        script_path = @script_path
        return unless script_path
        return unless File.exists?(script_path)

        source = File.read(script_path)
        engine.load_script(context, source, script_path)
        engine.call_on_start
        Log.info { "Script loaded: #{script_path}" }
      end

      private def setup_frame_loop(engine : Scripting::Engine, viewport : Viewport)
        # Fixed: was Configuration.instance.timestamp.fixed (typo)
        fixed_timestep = Configuration.instance.timing.fixed

        viewport.on_before_render do |dt|
          # Clear previous frame's draw calls
          engine.commands.clear
          engine.call_on_update(dt)

          # Fixed-rate physics updates
          @physics_accumulator += dt
          while @physics_accumulator >= fixed_timestep
            engine.call_on_fixed_update(fixed_timestep)
            @physics_accumulator -= fixed_timestep
          end

          # Submit draw calls for the overlay stage
          viewport.submit_commands(engine.commands)
        end
      end
    end
  end
end
