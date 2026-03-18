require "../src/tachyon"

Log.setup(:debug)

app = Tachyon::Window::Application.new(script_path: ARGV[0]?)
app.run
