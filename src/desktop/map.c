#include <osm-gps-map.h>
#include <gtk/gtk.h>
#include <cairo.h>

static OsmGpsMap* map_view = NULL;
static OsmGpsMapImage* plane_marker = NULL;
static OsmGpsMapTrack* position_track = NULL;

static gboolean has_old_position = FALSE;

GtkWidget* map_widget_new(void) {
  GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);

  GtkWidget* map = osm_gps_map_new();
  map_view = OSM_GPS_MAP(map);

  gtk_box_pack_start(GTK_BOX(box), map, TRUE, TRUE, 0);

  position_track = osm_gps_map_track_new();

  GdkRGBA color;
  gdk_rgba_parse(&color, "#00008b");

  osm_gps_map_track_set_color(position_track, &color);
  osm_gps_map_track_add(map_view, position_track);

  GtkWidget* attr = gtk_label_new(NULL);
  gtk_label_set_markup(GTK_LABEL(attr),
    "<small>© <a href=\"https://www.openstreetmap.org/copyright\">"
    "OpenStreetMap</a> contributors</small>");

  gtk_widget_set_halign(attr, GTK_ALIGN_END);
  gtk_box_pack_start(GTK_BOX(box), attr, FALSE, FALSE, 2);

  return box;
}

static GdkPixbuf* make_square(int size) {
  cairo_surface_t* s =
    cairo_image_surface_create(CAIRO_FORMAT_ARGB32, size, size);

  cairo_t* cr = cairo_create(s);

  cairo_set_source_rgb(cr, 0, 0, 0);
  cairo_rectangle(cr, 1, 1, size - 2, size - 2);
  cairo_fill(cr);

  cairo_destroy(cr);

  GdkPixbuf* pb =
    gdk_pixbuf_get_from_surface(s, 0, 0, size, size);

  cairo_surface_destroy(s);
  return pb;
}

void map_widget_set_marker(double lat, double lon) {
  if (!map_view) return;

  if (plane_marker) {
    osm_gps_map_image_remove(map_view, plane_marker);
    plane_marker = NULL;
  }

  GdkPixbuf* square = make_square(14);

  if (square) {
    plane_marker = osm_gps_map_image_add(map_view, lat, lon, square);
    g_object_unref(square);
  }

  OsmGpsMapPoint* point = osm_gps_map_point_new_degrees(lat, lon);

  if (point) {
    osm_gps_map_track_add_point(position_track, point);
    osm_gps_map_point_free(point);
  }

  has_old_position = TRUE;
}
