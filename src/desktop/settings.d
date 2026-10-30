module settings;

import std.stdio : writeln;
import std.path : expandTilde;
import std.file : readText, write;
import std.json;

class Settings {
  public {
    this(string file = expandTilde("~/.config/flightrender.json")) {
      string fileContent;
      try {
        fileContent = readText(file);
      } catch (Exception e) {
        write(file, "{}");
        fileContent = readText(file);
      }

      this.file = file;
      data = parseJSON(fileContent);
    }

    JSONValue data;

    void save() {
      string json = data.toJSON();
      write(file, json);
      writeln("INFO: Saving config:\n  " ~ json);
    }
  }

  public {
    string file;
  }
}
