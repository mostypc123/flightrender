module tracker;

__gshared TrackedPlane trackedPlane;

class TrackedPlane {
  import vibe.vibe;

  public {
    void update(string lat, string log, string name, int spd) {
      this.lat = lat; this.log = log; this.name = name; this.spd = spd;
    }

    string lat;
    string log;
    string fid;
    string name;
    int spd;
  }
}
