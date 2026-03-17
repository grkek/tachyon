module Tachyon
  module Renderer
    class Shader
      Log = ::Log.for(self)

      getter program : LibGL::GLuint

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

      def use
        LibGL.glUseProgram(@program)
      end

      def set_matrix4(name : String, matrix : Math::Matrix4)
        loc = LibGL.glGetUniformLocation(@program, name.to_unsafe)
        LibGL.glUniformMatrix4fv(loc, 1, LibGL::GL_FALSE, matrix.to_unsafe)
      end

      def set_vector3(name : String, vec : Math::Vector3)
        loc = LibGL.glGetUniformLocation(@program, name.to_unsafe)
        LibGL.glUniform3f(loc, vec.x, vec.y, vec.z)
      end

      def set_vector2(name : String, x : Float32, y : Float32)
        loc = LibGL.glGetUniformLocation(@program, name.to_unsafe)
        LibGL.glUniform2f(loc, x, y)
      end

      def set_color(name : String, r : Float32, g : Float32, b : Float32, a : Float32)
        loc = LibGL.glGetUniformLocation(@program, name.to_unsafe)
        LibGL.glUniform4f(loc, r, g, b, a)
      end

      def set_float(name : String, value : Float32)
        loc = LibGL.glGetUniformLocation(@program, name.to_unsafe)
        LibGL.glUniform1f(loc, value)
      end

      def set_int(name : String, value : Int32)
        loc = LibGL.glGetUniformLocation(@program, name.to_unsafe)
        LibGL.glUniform1i(loc, value)
      end

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
