module Tachyon
  module Scene
    class Transform
      Log = ::Log.for(self)

      property position : Math::Vector3
      property rotation : Math::Quaternion
      property scale : Math::Vector3

      def initialize(
        @position : Math::Vector3 = Math::Vector3.zero,
        @rotation : Math::Quaternion = Math::Quaternion.identity,
        @scale : Math::Vector3 = Math::Vector3.one,
      )
      end

      def model_matrix : Math::Matrix4
        t = Math::Matrix4.translation(@position)
        r = @rotation.to_matrix4
        s = Math::Matrix4.scale(@scale)
        t * r * s
      end

      # Normal matrix: transpose of inverse of upper-left 3x3 of model matrix.
      # For uniform scale, this simplifies to just the rotation matrix.
      def normal_matrix : Math::Matrix4
        @rotation.to_matrix4
      end

      def translate(x : Float32, y : Float32, z : Float32)
        @position = @position + Math::Vector3.new(x, y, z)
      end

      def rotate(x_deg : Float32, y_deg : Float32, z_deg : Float32)
        euler = Math::Quaternion.from_euler(
          Math.to_radians(x_deg),
          Math.to_radians(y_deg),
          Math.to_radians(z_deg)
        )
        @rotation = @rotation * euler
      end

      def look_at(target : Math::Vector3)
        direction = (target - @position).normalize
        return if direction.magnitude_squared < 0.0001f32

        # Calculate rotation from forward (-Z) to desired direction
        forward = Math::Vector3.forward
        dot = forward.dot(direction)

        if dot < -0.9999f32
          # Opposite direction — rotate 180 around up
          @rotation = Math::Quaternion.from_axis_angle(Math::Vector3.up, ::Math::PI.to_f32)
        elsif dot > 0.9999f32
          @rotation = Math::Quaternion.identity
        else
          axis = forward.cross(direction).normalize
          angle = ::Math.acos(dot.clamp(-1.0f32, 1.0f32)).to_f32
          @rotation = Math::Quaternion.from_axis_angle(axis, angle)
        end
      end
    end
  end
end
