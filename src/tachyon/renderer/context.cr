module Tachyon
  module Rendering
    # Long-lived shared state available to all pipeline stages
    class Context
      property scene : Scene::Graph
      property camera : Renderer::Camera
      property light_manager : Renderer::LightManager

      # Scripting overlay commands set before each frame
      property commands : Array(Scripting::GUI::DrawCall) = [] of Scripting::GUI::DrawCall

      def initialize(@scene, @camera, @light_manager)
      end
    end
  end
end
