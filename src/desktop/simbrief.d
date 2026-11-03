class Simbrief {
  import std.json;
  import std.net.curl : get, HTTP;
  import std.file : mkdirRecurse, write;
  import std.array : join, split;
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
        auto relativeUrl = downloads["xpe"]["link"].str;
        auto downloadUrl = baseUrl ~ relativeUrl;

        mkdirRecurse(xplaneDir ~ "/Output/FMS plans/");
        write(xplaneDir ~ "/Output/FMS plans/" ~ origin ~ destination ~ ".fms", cast(string) get(downloadUrl));

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

    string readLatestGeneratedFlight(JSONValue genFlight) {
      string origin = genFlight["origin"]["icao_code"].str;
      string originRunway;
      string destination = genFlight["destination"]["icao_code"].str;
      string destRunway;
      string wpts;
      auto downloads = genFlight["fms_downloads"];
      string baseUrl = downloads["directory"].str;
      auto relativeUrl = downloads["xpe"]["link"].str;
      auto downloadUrl = baseUrl ~ relativeUrl;
      auto fmsPlan = cast(string) get(downloadUrl);

      foreach (line; fmsPlan.split("\n")) {
        try {
          auto parts = line.split(" ");
          if (parts[0] == "DEPRWY") {
            originRunway = parts[1];
          } else if (parts[0] == "DESRWY") {
            destRunway = parts[1];
          } else if (
            parts[0] == "2" || parts[0] == "3" || parts[0] == "11"
          ) {
            wpts ~= (parts[2] == "DRCT" ? "Direct" : "Via " ~ parts[2]) ~ " to " ~ parts[1] ~ ";\n";
          }
        } catch (ArrayIndexError e) {}
      }

      return (
        "Departure - " ~ origin ~ " runway " ~ originRunway ~ "\n" ~
        wpts ~
        "Arrival - " ~ destination ~ " runway " ~ destRunway ~ ""
      );
    }
  }

  private {
    string userid;
  }
}
