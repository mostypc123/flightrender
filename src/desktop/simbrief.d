struct Waypoint {
  string name;
  double lat;
  double lon;
}

struct Route {
  Waypoint[] waypoints;
  string briefing;
}

class Simbrief {
  import std.json;
  import std.conv : to;
  import std.net.curl : get, HTTP;
  import std.file : mkdirRecurse, write;
  import std.array : join, split;
  import std.string : splitLines;
  import core.exception : ArrayIndexError;

  import settings;

  public {
    this(string userid) {
      this.userid = userid;
    }


    JSONValue lastGeneratedFlight() @trusted {
      return parseJSON(
        cast(string) get(
          "https://www.simbrief.com/api/xml.fetcher.php?userid=" ~ userid ~ "&json=1"
        )
      );
    }

    string downloadAllUsableFPlanFormats(Settings opts, JSONValue genFlight) {
      string[] done;

      string origin = genFlight["origin"]["icao_code"].str;
      string destination = genFlight["destination"]["icao_code"].str;
      auto downloads = genFlight["fms_downloads"];
      string baseUrl = downloads["directory"].str;

      if ("Xplane11InstallDir" in opts.data) {
        // xpe (X-Plane 11/12)
        string xplaneDir = opts.data["Xplane11InstallDir"].str;

        mkdirRecurse(xplaneDir ~ "/Output/FMS plans/");
        write(xplaneDir ~ "/Output/FMS plans/" ~ origin ~ destination ~ ".fms", downloadFms(genFlight));

        done ~= "X-Plane 11/12";
      }

      if ("JARDesignAirbusDirs" in opts.data) {
        // jar (JARDesign Airbus)
        string instDirs = opts.data["JARDesignAirbusDirs"].str;
        foreach (dir; instDirs.split(";")) {
          auto relativeUrl = downloads["jar"]["link"].str;
          auto downloadUrl = baseUrl ~ relativeUrl;

          mkdirRecurse(dir ~ "/FlightPlans/");
          write(dir ~ "/FlightPlans/" ~ origin ~ destination ~ ".txt", cast(string) get(downloadUrl));
        }

        done ~= "JARDesign Airbus(es)";
      }

      return done.length == 0 ? (
        "No flight plan was downloaded because none of the supported options are configured."
      ) : (
        "Downloaded: " ~ done.join(", ")
      );
    }

    string downloadFms(JSONValue genFlight) {
      auto downloads = genFlight["fms_downloads"];
      string baseUrl = downloads["directory"].str;
      auto relativeUrl = downloads["xpe"]["link"].str;
      auto downloadUrl = baseUrl ~ relativeUrl;
      return cast(string) get(downloadUrl);
    }

    Route readLatestGeneratedFlight(JSONValue genFlight) {
      return readLatestGeneratedFlightOwnFms(genFlight, downloadFms(genFlight));
    }

    Route readLatestGeneratedFlightOwnFms(JSONValue genFlight, string fmsPlan) {
      string origin = genFlight["origin"]["icao_code"].str;
      string originRunway;
      string destination = genFlight["destination"]["icao_code"].str;
      string destRunway;
      string wpts;
      Route result;

      foreach (line; fmsPlan.splitLines()) {
        try {
          Waypoint wpt;
          auto parts = line.split(" ");
          if (parts[0] == "DEPRWY") {
            originRunway = parts[1];
          } else if (parts[0] == "DESRWY") {
            destRunway = parts[1];
          } else if (
            parts[0] == "2" || parts[0] == "3" || parts[0] == "11" || parts[0] == "28"
          ) {
            wpts ~= (parts[2] == "DRCT" ? "Direct" : "Via " ~ parts[2]) ~ " to " ~ parts[1] ~ ";\n";
            wpt.name = parts[1];
            wpt.lat = to!double(parts[4]);
            wpt.lon = to!double(parts[5]);
            result.waypoints ~= wpt;
          } else if (parts[0] == "1") {
            wpt.name = parts[1];
            wpt.lat = to!double(parts[4]);
            wpt.lon = to!double(parts[5]);
            result.waypoints ~= wpt;
          }
        } catch (ArrayIndexError e) {}
      }

      result.briefing = (
        "Departure - " ~ origin ~ " runway " ~ originRunway ~ "\n" ~ wpts ~
        "Arrival - " ~ destination ~ " runway " ~ destRunway
      );
      return result;
    }
  }

  private {
    string userid;
  }
}
