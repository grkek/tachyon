module Tachyon
  module Renderer
    class Camera
      Log = ::Log.for(self)

      property position : Math::Vector3
      property target : Math::Vector3
      property up : Math::Vector3
      property field_of_view : Float32 # Degrees
      property near_plane : Float32
      property far_plane : Float32
      property aspect : Float32
      property scale_factor : Int32 = 1
      property viewport_width : Int32 = 1280
      property viewport_height : Int32 = 720

      def initialize(
        @field_of_view : Float32 = 75.0f32,
        @near_plane : Float32 = 0.1f32,
        @far_plane : Float32 = 1000.0f32,
        @aspect : Float32 = 16.0f32 / 9.0f32,
      )
        @position = Math::Vector3.new(0.0f32, 0.0f32, 3.0f32)
        @target = Math::Vector3.zero
        @up = Math::Vector3.up
      end

      def look_at(@target : Math::Vector3)
      end

      def view_matrix : Math::Matrix4
        Math::Matrix4.look_at(@position, @target, @up)
      end

      def projection_matrix : Math::Matrix4
        fov_rad = Math.to_radians(@field_of_view)
        Math::Matrix4.perspective(fov_rad, @aspect, @near_plane, @far_plane)
      end

      def update_aspect(width : Int32, height : Int32)
        @viewport_width = width
        @viewport_height = height
        @aspect = width.to_f32 / height.to_f32 if height > 0
      end

      # Unproject screen coordinates to a world-space ray
      def screen_to_ray(screen_x : Float32, screen_y : Float32, vp_width : Int32, vp_height : Int32) : Math::Ray
        ndc_x = (2.0f32 * screen_x / vp_width.to_f32) - 1.0f32
        ndc_y = 1.0f32 - (2.0f32 * screen_y / vp_height.to_f32)

        inv_proj = projection_matrix.inverse
        inv_view = view_matrix.inverse

        # Unproject near and far clip points
        near_point = inv_proj.transform_point(Math::Vector3.new(ndc_x, ndc_y, -1.0f32))
        far_point = inv_proj.transform_point(Math::Vector3.new(ndc_x, ndc_y, 1.0f32))

        world_near = inv_view.transform_point(near_point)
        world_far = inv_view.transform_point(far_point)

        direction = (world_far - world_near).normalize
        Math::Ray.new(@position, direction)
      end
    end
  end
end
