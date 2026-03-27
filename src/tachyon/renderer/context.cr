module Tachyon
  module Renderer
    # Long-lived shared state available to all pipeline stages
    class Context
      property scene : Scene::Graph
      property camera : Renderer::Camera
      property light_manager : Renderer::LightManager
      property ibl : Renderer::IBL? = nil

      # Scripting overlay commands set before each frame
      property commands : Array(Scripting::GraphicalUserInterface::DrawCall) = [] of Scripting::GraphicalUserInterface::DrawCall

      def initialize(@scene, @camera, @light_manager)
      end
    end
  end
end
