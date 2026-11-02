import vibe.vibe;
import tracker;

void stop() {
  exitEventLoop();
}

void start() {
  auto router = new URLRouter;

  // i fucking hate all thsi fucking fullstack app dev fuckery
  router.any("*", (HTTPServerRequest req, HTTPServerResponse res) {
    res.headers["Access-Control-Allow-Origin"] = "*";
    res.headers["Access-Control-Allow-Headers"] = "Content-Type";
    res.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS";
    if (req.method == HTTPMethod.OPTIONS) res.writeBody("", 204);
  });

  router.post("/tracker/update", (HTTPServerRequest req, HTTPServerResponse res) @trusted {
    auto json = req.json;
    try {
      auto pln = json["pln"].get!string;
      auto lat = json["lat"].get!string;
      auto log = json["log"].get!string;
      auto spd = json["spd"].get!int;

      tracker.trackedPlane.update(lat, log, pln, spd);

      logInfo("update: pln='%s' lat='%s' log='%s' spd=%s", pln, lat, log, spd);
    } catch (Exception e) {
      res.writeJsonBody(["status": "fail", "msg": e.msg]);
      return;
    }

    res.writeJsonBody(["status": "ok", "msg": "updated tracking data"]);
  });

  router.post("/tracker/get", (HTTPServerRequest req, HTTPServerResponse res) @trusted {
    auto json = req.json;

    try {
      res.writeJsonBody([
        "status": Json("ok"),
        "pln": Json(tracker.trackedPlane.name),
        "lat": Json(tracker.trackedPlane.lat),
        "log": Json(tracker.trackedPlane.log),
        "spd": Json(tracker.trackedPlane.spd)
      ]);
    } catch (Exception e) {
      res.writeJsonBody(["status": "fail", "msg": e.msg]);
    }
  });

  router.get("/test", (req, res) {
    res.writeJsonBody(["status": "ok"]);
  });

  auto settings = new HTTPServerSettings;
  settings.bindAddresses = ["127.0.0.1"];
  settings.port = 20_757;
  listenHTTP(settings, router);
  runEventLoop();
}
