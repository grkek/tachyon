module Tachyon
  module Renderer
    class Sprite
      Log = ::Log.for(self)

      property x : Float32 = 0.0f32
      property y : Float32 = 0.0f32
      property width : Float32 = 32.0f32
      property height : Float32 = 32.0f32
      property rotation : Float32 = 0.0f32
      property scale_x : Float32 = 1.0f32
      property scale_y : Float32 = 1.0f32
      property r : Float32 = 1.0f32
      property g : Float32 = 1.0f32
      property b : Float32 = 1.0f32
      property a : Float32 = 1.0f32
      property visible : Bool = true
      property layer : Int32 = 0
      property texture : Texture? = nil

      # Sprite sheet atlas
      property atlas_columns : Int32 = 1
      property atlas_rows : Int32 = 1
      property frame_index : Int32 = 0

      # Animation
      property animation_playing : Bool = false
      property animation_frames : Array(Int32) = [] of Int32
      property animation_fps : Float32 = 12.0f32
      property animation_loop : Bool = true
      @animation_timer : Float32 = 0.0f32
      @animation_position : Int32 = 0

      def initialize(@width : Float32 = 32.0f32, @height : Float32 = 32.0f32)
      end

      def self.from_texture(path : String) : Sprite
        tex = Texture.load(path, srgb: true)
        sprite = Sprite.new(tex.width.to_f32, tex.height.to_f32)
        sprite.texture = tex
        sprite
      end

      def setup_atlas(columns : Int32, rows : Int32)
        @atlas_columns = columns
        @atlas_rows = rows
      end

      def play_animation(frames : Array(Int32), fps : Float32, loop : Bool)
        @animation_frames = frames
        @animation_fps = fps
        @animation_loop = loop
        @animation_playing = true
        @animation_timer = 0.0f32
        @animation_position = 0
        @frame_index = frames[0] if frames.size > 0
      end

      def stop_animation
        @animation_playing = false
      end

      def update(delta_time : Float32)
        return unless @animation_playing
        return if @animation_frames.empty?

        @animation_timer += delta_time
        frame_duration = 1.0f32 / @animation_fps

        while @animation_timer >= frame_duration
          @animation_timer -= frame_duration
          @animation_position += 1

          if @animation_position >= @animation_frames.size
            if @animation_loop
              @animation_position = 0
            else
              @animation_position = @animation_frames.size - 1
              @animation_playing = false
              break
            end
          end
        end

        @frame_index = @animation_frames[@animation_position]
      end

      # Returns UV rect {u0, v0, u1, v1} for the current frame
      def frame_uv : {Float32, Float32, Float32, Float32}
        column = @frame_index % @atlas_columns
        row = @frame_index // @atlas_columns

        cell_width = 1.0f32 / @atlas_columns.to_f32
        cell_height = 1.0f32 / @atlas_rows.to_f32

        u0 = column.to_f32 * cell_width
        v0 = row.to_f32 * cell_height
        u1 = u0 + cell_width
        v1 = v0 + cell_height

        {u0, v0, u1, v1}
      end
    end
  end
end
