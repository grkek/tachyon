module Tachyon
  module Renderer
    # Compiles, links, and manages a GLSL shader program
    class Shader
      Log = ::Log.for(self)

      # Resolve shaders relative to this source file's directory
      SHADER_DIR = File.join({{__DIR__}}, "..", "..", "shaders")

      getter program : LibGL::GLuint

      @uniform_cache : Hash(String, LibGL::GLint) = {} of String => LibGL::GLint

      # Load a single shader source file by name (e.g. "pbr.vert")
      def self.load_file(name : String) : String
        path = File.join(SHADER_DIR, "#{name}.glsl")
        unless File.exists?(path)
          raise "Shader file not found: #{path}"
        end
        source = File.read(path)
        Log.debug { "Loaded shader: #{path} (#{source.bytesize} bytes)" }
        source
      end

      # Load a shader, returning nil instead of raising on failure
      def self.load_file?(name : String) : String?
        load_file(name)
      rescue
        nil
      end

      # Load a vertex/fragment pair by convention: "name.vert" and "name.frag"
      def self.load_program(name : String) : {String, String}
        vert = load_file("#{name}.vert")
        frag = load_file("#{name}.frag")
        {vert, frag}
      end

      # Create a shader program from a named pair on disk
      def self.from_file(name : String) : Shader
        vert, frag = load_program(name)
        new(vert, frag)
      end

      def initialize(vertex_source : String, fragment_source : String)
        vert = compile(LibGL::GL_VERTEX_SHADER, vertex_source)
        frag = compile(LibGL::GL_FRAGMENT_SHADER, fragment_source)

        @program = LibGL.glCreateProgram
        LibGL.glAttachShader(@program, vert)
        LibGL.glAttachShader(@program, frag)
        LibGL.glLinkProgram(@program)

        status = 0
        LibGL.glGetProgramiv(@program, LibGL::GL_LINK_STATUS, pointerof(status))
        if status == 0
          len = 0
          LibGL.glGetProgramiv(@program, LibGL::GL_INFO_LOG_LENGTH, pointerof(len))
          log = Bytes.new(len)
          LibGL.glGetProgramInfoLog(@program, len, nil, log.to_unsafe)
          raise "Shader link error: #{String.new(log)}"
        end

        LibGL.glDeleteShader(vert)
        LibGL.glDeleteShader(frag)
      end

      # Activate this shader program
      def use
        LibGL.glUseProgram(@program)
      end

      # Cached uniform location lookup
      def location(name : String) : LibGL::GLint
        @uniform_cache[name] ||= LibGL.glGetUniformLocation(@program, name.to_unsafe)
      end

      def set_matrix4(name : String, matrix : Math::Matrix4)
        LibGL.glUniformMatrix4fv(location(name), 1, LibGL::GL_FALSE, matrix.to_unsafe)
      end

      def set_vector3(name : String, vec : Math::Vector3)
        LibGL.glUniform3f(location(name), vec.x, vec.y, vec.z)
      end

      def set_vector2(name : String, x : Float32, y : Float32)
        LibGL.glUniform2f(location(name), x, y)
      end

      def set_color(name : String, r : Float32, g : Float32, b : Float32, a : Float32)
        LibGL.glUniform4f(location(name), r, g, b, a)
      end

      def set_float(name : String, value : Float32)
        LibGL.glUniform1f(location(name), value)
      end

      def set_int(name : String, value : Int32)
        LibGL.glUniform1i(location(name), value)
      end

      # Release the GL program
      def destroy
        LibGL.glDeleteProgram(@program)
      end

      private def compile(type : LibGL::GLenum, source : String) : LibGL::GLuint
        shader = LibGL.glCreateShader(type)
        src_ptr = source.to_unsafe
        src_len = source.bytesize
        LibGL.glShaderSource(shader, 1, pointerof(src_ptr), pointerof(src_len))
        LibGL.glCompileShader(shader)

        status = 0
        LibGL.glGetShaderiv(shader, LibGL::GL_COMPILE_STATUS, pointerof(status))
        if status == 0
          len = 0
          LibGL.glGetShaderiv(shader, LibGL::GL_INFO_LOG_LENGTH, pointerof(len))
          log = Bytes.new(len)
          LibGL.glGetShaderInfoLog(shader, len, nil, log.to_unsafe)
          type_name = type == LibGL::GL_VERTEX_SHADER ? "vertex" : "fragment"
          raise "#{type_name} shader compile error: #{String.new(log)}"
        end

        shader
      end
    end
  end
end
