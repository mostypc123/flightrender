import gtk.Main;
import gtk.MainWindow;
import gtk.Box;
import gtk.Toolbar;
import gtk.ToolItem;
import gtk.Entry;
import gtk.SeparatorToolItem;
import gtk.Label;
import gtk.Stack;
import gtk.StackSwitcher;
import gtk.Widget;
import gtk.Button;
import gtk.MessageDialog;

import gdk.Event;

import gtkc.gtktypes;

import glib.Timeout;
import glib.Idle;

import gobject.ObjectG;

import core.thread : Thread;
import core.time : seconds;
import std.json : parseJSON;
import std.stdio : writeln;
import std.net.curl : HTTP, get;
import core.stdc.stdlib : _Exit;
import std.string : toStringz;

import settings;
import simbrief;
import tracker;

extern (C) { // map.c
  GtkWidget* map_widget_new();
  void map_widget_set_marker(double lat, double lon);
  void map_widget_set_marker_with_text(double lat, double lon, const(char)* text);
  void map_widget_clear_route(int also_remove_marker);
  void map_widget_draw_route(const(double)* lats, const(double)* lons, int count);
  void map_widget_add_to_route(const(char)* wpt_name, double lat, double lon);
  void map_widget_clear_planned_route();
}

enum url = "http://127.0.0.1:20757/test";

Settings opts;
Simbrief sbrief;

Label statusLabel;
Timeout mapTimer;

bool checkStatus() {
  try {
    auto http = HTTP();
    http.connectTimeout = 2.seconds;
    http.dataTimeout = 2.seconds;
    auto body = get(url, http);
    return parseJSON(body)["status"].str == "ok";
  } catch (Exception e) {
    return false;
  }
}

void setStatus(bool ok) {
  if (ok) {
    statusLabel.setMarkup("<span foreground='green'>✔</span>");
  } else {
    statusLabel.setMarkup("<span foreground='red'>✘</span>");
  }
}

void poll() {
  new Thread({
    bool ok = checkStatus();
    new Idle(delegate bool() {
      setStatus(ok);
      return false;
    });
  }).start();
}

Widget homeTab() {
  import std.random : choice;
  import std.string : wrap;

  const string[] didYouKnow = [
    "Pressure altitude is what your altimeter reads with 1013 hPa (29.92 inHg) set, and it's the reference for flight levels above the transition altitude.",
    "Density altitude can be thousands of feet higher than field elevation on a hot day, which hurts takeoff roll, climb rate, and engine performance.",
    "A good rule of thumb for descent planning: distance to start down = altitude to lose (in thousands of feet) x 3 NM.",
    "True airspeed is roughly 2% higher than indicated airspeed for every 1,000 ft of altitude.",
    "Headwinds help on the ground but cost you fuel range: a 50 kt headwind on a 450 kt TAS cruise cuts your ground speed by over 10%.",
    "Many airliners use a 'Mach number' for cruise, because the speed of sound drops with temperature and the critical Mach number is the real structural limit.",
    "ILS Category III approaches can allow landings with a decision height below 100 ft, or even no decision height at all, with the autoland system flying the whole approach.",
    "The 'Coffin Corner' is the altitude where stall speed and critical Mach converge, leaving a very narrow margin of safe airspeed.",
    "In the real world, a cost index in the FMC trades off fuel burn against time, and changing it can shift your cruise speed noticeably.",
    "METARs report wind direction in degrees true, but runway numbers and ATIS winds at many airports are given in magnetic.",
    "A STAR (standard terminal arrival route) often has speed and altitude restrictions, and flying them correctly is the secret to a smooth, realistic arrival.",
    "A step climb during cruise saves fuel because lighter aircraft fly more efficiently at higher altitudes as fuel burns off.",
    "Crosswind component = wind speed x sin(angle between wind and runway), so a 20 kt wind at 30 degrees off is only a 10 kt crosswind.",
    "Flying the localizer course accurately before intercepting the glideslope from below makes for a much more stable approach than capturing from above."
  ];

  auto box = new Box(GtkOrientation.VERTICAL, 8);
  box.setHalign(GtkAlign.CENTER);
  box.setValign(GtkAlign.CENTER);
  auto heading = new Label("");
  heading.setMarkup("<span size='32000'>Hello!</span>");
  box.packStart(heading, true, true, 0);
  auto label = new Label("");
  label.setMarkup("<b>Did you know?</b> " ~ didYouKnow.choice.wrap(70));
  box.packStart(label, true, true, 0);
  return box;
}

Widget settingsTab() {
  Box createConfigEntry(Box box, string labelText, string key, ref Settings opts) {
    auto label = new Label(labelText);
    auto entry = new Entry;

    if (key in opts.data)
      entry.setText(opts.data[key].str);

    entry.addOnChanged((e) {
      opts.data[key] = e.getChars(0, -1);
      opts.save();
    });

    box.packStart(label, false, false, 0);
    box.packStart(entry, false, false, 0);

    return box;
  }

  auto box = new Box(GtkOrientation.VERTICAL, 8);
  auto heading = new Label("");
  heading.setMarkup("<span size='32000'>Settings</span>");
  box.packStart(heading, true, true, 0);

  createConfigEntry(box, "SimBrief User ID:", "SimbriefUserId", opts);
  createConfigEntry(box, "X-Plane 11 installation directory:", "Xplane11InstallDir", opts);
  createConfigEntry(
    box, "JARDesign Airbus installation directories, separated by a semicolon (;):", "JARDesignAirbusDirs", opts
  );

  return box;
}

Widget mapTab() {
  auto box = new Box(GtkOrientation.VERTICAL, 8);

  auto raw = map_widget_new();
  auto map = ObjectG.getDObject!(Widget)(raw);
  box.packStart(map, true, true, 0);

  void reload() {
    import std.conv : to, ConvException;

    try {
      writeln("updating position on map");

      auto lat = to!double(tracker.trackedPlane.lat);
      auto lon = to!double(tracker.trackedPlane.log);

      map_widget_set_marker(lat, lon);
    } catch (ConvException e) {
      writeln(e.msg ~ " -- This error is probably harmless and just mean you didnt start the sim or plugin yet.");
    }
  }

  reload();

  mapTimer = new Timeout(5000, {
    reload();
    return true;
  });

  return box;
}

void addTab(Stack stack, string id, string title, Widget content) {
  stack.addTitled(content, id, title);
}

void start() {
  opts = new Settings;
  sbrief = new Simbrief("SimbriefUserId" in opts.data ? opts.data["SimbriefUserId"].str : "");

  string[] args;
  Main.init(args);

  auto win = new MainWindow("Flightrender");
  win.setDefaultSize(1000, 600);

  win.addOnDelete((Event e, Widget w) {
    _Exit(0);
    return false;
  });

  auto box = new Box(GtkOrientation.VERTICAL, 0);

  auto stack = new Stack();
  addTab(stack, "home", "Home", homeTab());
  addTab(stack, "settings", "Settings", settingsTab());
  addTab(stack, "map", "Map", mapTab());

  auto switcher = new StackSwitcher();
  switcher.setStack(stack);

  auto toolbar = new Toolbar();

  auto switcherItem = new ToolItem();
  switcherItem.add(switcher);
  toolbar.insert(switcherItem, -1);

  auto statusItem = new ToolItem();
  statusLabel = new Label("");
  statusItem.add(statusLabel);
  statusItem.setTooltipText("Server status. If the server is not running, check for anything blocking port 20757.");
  toolbar.insert(statusItem, -1);
  setStatus(false);

  auto spacer = new SeparatorToolItem();
  spacer.setDraw(false);
  spacer.setExpand(true);
  toolbar.insert(spacer, -1);

  auto flight = new Label("");
  auto flightButtonToolItem = new ToolItem();
  auto flightButton = new Button("Fly");
  string userid = ""; // will not work, therefore simbrief returns error and we dont show
  try {
    userid = opts.data["SimbriefUserId"].str;
  } catch (Exception e) {}
  bool show = false;
  auto flightItem = new ToolItem();
  flightItem.add(flight);
  flightButtonToolItem.add(flightButton);
  try {
    auto jsonResponse = sbrief.lastGeneratedFlight();
    if (jsonResponse["fetch"]["status"].str != "Success") {} else {
      show = true;

      string origin = jsonResponse["origin"]["icao_code"].str;
      string destination = jsonResponse["destination"]["icao_code"].str;

      flight.setMarkup("<span size='13000'>" ~ origin ~ " to " ~ destination ~ "</span>");

      void downloadGenerated() {
        string message = sbrief.downloadAllUsableFPlanFormats(opts, jsonResponse);
        auto dlg = new MessageDialog(
          win,
          GtkDialogFlags.MODAL,
          GtkMessageType.INFO,
          GtkButtonsType.OK,
          message
        );
        dlg.run();
        dlg.destroy();
      }

      void latestGenerated(string message) {
        auto dlg = new MessageDialog(
          win,
          GtkDialogFlags.MODAL,
          GtkMessageType.INFO,
          GtkButtonsType.OK,
          message
        );
        dlg.run();
        dlg.destroy();
      }

      flightButton.addOnClicked((Button b) {
        auto plan = sbrief.readLatestGeneratedFlight(jsonResponse);

        {
          auto dialog = new MessageDialog(
            win,
            GtkDialogFlags.MODAL,
            GtkMessageType.QUESTION,
            GtkButtonsType.NONE,
            "Which flight plan format do you want?"
          );
          dialog.addButton("Download", 1);
          dialog.addButton("Manual entry", 2);
          dialog.addButton("Cancel", ResponseType.CANCEL);

          int response = dialog.run();
          dialog.destroy();

          if (response == 1) {
            downloadGenerated();
          } else if (response == 2) {
            latestGenerated(plan.briefing);
          }
        }

        {
          auto dialog = new MessageDialog(
            win,
            GtkDialogFlags.MODAL,
            GtkMessageType.QUESTION,
            GtkButtonsType.YES_NO,
            "Write the plan to the map?"
          );

          int response = dialog.run();
          dialog.destroy();

          if (response == ResponseType.YES) {
            foreach (wpt; plan.waypoints) {
              map_widget_add_to_route(wpt.name.toStringz(), wpt.lat, wpt.lon);
            }
          }
        }
      });
    }
  } catch (Exception e) {
    writeln(e.msg);
  }

  if (show) {
    toolbar.insert(flightItem, -1);
    toolbar.insert(flightButtonToolItem, -1);
  }

  box.packStart(toolbar, false, false, 0);
  box.packStart(stack, true, true, 0);
  win.add(box);
  win.showAll();

  poll();
  new Timeout(2000, delegate bool() {
    poll();
    return true;
  });

  Main.run();
}
