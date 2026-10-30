import core.thread;
import server;
import ui;
import std.stdio : writeln;
import core.sys.posix.unistd : _exit;

void main() {
  writeln("Starting server in another thread");
  auto t = new Thread({ server.start(); });
  t.isDaemon = true;
  t.start();

  writeln("Starting UI");
  ui.start();
  _exit(0); // you know its serious when the fix is switching
            // from exit to some random func in the core posix module
}
