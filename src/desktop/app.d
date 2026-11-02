import core.thread;
import server;
import ui;
import std.stdio : writeln;
import core.stdc.stdlib : exit;
import tracker;

void main() {
  writeln("Initializing tracked planes");
  tracker.trackedPlane = new TrackedPlane;

  writeln("Starting server in another thread");

  auto t = new Thread({
    server.start();
  });

  t.isDaemon = true;
  t.start();

  writeln("Starting UI");
  ui.start();

  server.stop();
  exit(0);
}
