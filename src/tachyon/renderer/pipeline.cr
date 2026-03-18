module Tachyon
  module Rendering
    # Executes an ordered list of stages, passing a Frame through each one.
    # Provides a full API for runtime insertion, removal, reordering, and toggling.
    class Pipeline
      Log = ::Log.for(self)

      getter stages : Array(Stages::Base)
      getter context : Context

      @realized : Bool = false

      def initialize(@context : Context)
        @stages = [] of Stages::Base
      end

      # Append a stage to the end of the pipeline
      def add(stage : Stages::Base)
        @stages << stage
        stage.setup(@context) if @realized
        Log.info { "Added stage: #{stage.name}" }
      end

      # Insert a stage at a specific index
      def insert(index : Int32, stage : Stages::Base)
        clamped = index.clamp(0, @stages.size)
        @stages.insert(clamped, stage)
        stage.setup(@context) if @realized
        Log.info { "Inserted stage '#{stage.name}' at index #{clamped}" }
      end

      # Insert a stage immediately before another (looked up by name)
      def insert_before(target : String, stage : Stages::Base)
        idx = index_of(target)
        idx ? insert(idx, stage) : add(stage)
      end

      # Insert a stage immediately after another (looked up by name)
      def insert_after(target : String, stage : Stages::Base)
        idx = index_of(target)
        idx ? insert(idx + 1, stage) : add(stage)
      end

      # Remove a stage by name, tearing it down and returning it
      def remove(name : String) : Stages::Base?
        idx = index_of(name)
        return nil unless idx
        stage = @stages.delete_at(idx)
        stage.teardown
        Log.info { "Removed stage: #{name}" }
        stage
      end

      # Replace a stage by name, tearing down the old and setting up the new
      def replace(name : String, new_stage : Stages::Base) : Stages::Base?
        idx = index_of(name)
        return nil unless idx
        old = @stages[idx]
        old.teardown
        @stages[idx] = new_stage
        new_stage.setup(@context) if @realized
        Log.info { "Replaced stage '#{name}' with '#{new_stage.name}'" }
        old
      end

      # Move a stage to a new index
      def move(name : String, new_index : Int32) : Bool
        idx = index_of(name)
        return false unless idx
        stage = @stages.delete_at(idx)
        clamped = new_index.clamp(0, @stages.size)
        @stages.insert(clamped, stage)
        Log.info { "Moved stage '#{name}' from #{idx} to #{clamped}" }
        true
      end

      # Swap two stages by name
      def swap(name_a : String, name_b : String) : Bool
        idx_a = index_of(name_a)
        idx_b = index_of(name_b)
        return false unless idx_a && idx_b
        @stages[idx_a], @stages[idx_b] = @stages[idx_b], @stages[idx_a]
        Log.info { "Swapped stages '#{name_a}' and '#{name_b}'" }
        true
      end

      # Find a stage by name
      def find(name : String) : Stages::Base?
        @stages.find { |s| s.name == name }
      end

      # Find a stage by its concrete type
      def find_by_type(type : T.class) : T? forall T
        @stages.each do |stage|
          return stage.as(T) if stage.is_a?(T)
        end
        nil
      end

      # Enable or disable a stage by name
      def toggle(name : String, enabled : Bool)
        stage = find(name)
        if stage
          stage.enabled = enabled
          Log.info { "Stages::Base '#{name}' #{enabled ? "enabled" : "disabled"}" }
        end
      end

      # Return the index of a stage by name, or nil
      def index_of(name : String) : Int32?
        @stages.index { |s| s.name == name }
      end

      # Check whether a named stage exists
      def has_stage?(name : String) : Bool
        @stages.any? { |s| s.name == name }
      end

      # Return the number of stages
      def size : Int32
        @stages.size
      end

      # Initialize all stages (call once when GL context is ready)
      def setup
        @stages.each { |s| s.setup(@context) }
        @realized = true
        Log.info { "Pipeline realized with #{@stages.size} stages" }
      end

      # Run all enabled stages, passing the Frame through each one
      def execute(frame_buffer : LibGL::GLuint, width : Int32, height : Int32, delta_time : Float32) : Frame
        frame = Frame.new(frame_buffer, width, height, delta_time)

        @stages.each do |stage|
          next unless stage.enabled
          frame = stage.call(@context, frame)
          break if frame.consumed
        end

        frame
      end

      # Tear down all stages and clear the pipeline
      def teardown
        @stages.each(&.teardown)
        @stages.clear
        @realized = false
      end

      # Debug helper: list stage names and their enabled state
      def describe : Array({String, Bool})
        @stages.map { |s| {s.name, s.enabled} }
      end

      # Debug helper: list stage names in order
      def stage_names : Array(String)
        @stages.map(&.name)
      end
    end
  end
end
