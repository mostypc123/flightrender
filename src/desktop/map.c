#include <osm-gps-map.h>
#include <gtk/gtk.h>
#include <cairo.h>
#include <math.h>

static OsmGpsMap* map_view = NULL;
static OsmGpsMapImage* plane_marker = NULL;
static OsmGpsMapTrack* position_track = NULL;
static OsmGpsMapTrack* plan_track = NULL;
static GSList* plan_images = NULL;

static gboolean has_old_position = FALSE;

static void route_track_create(void) {
  position_track = osm_gps_map_track_new();

  GdkRGBA color;
  gdk_rgba_parse(&color, "#00008b");

  osm_gps_map_track_set_color(position_track, &color);
  osm_gps_map_track_add(map_view, position_track);
}

static void plan_track_create(void) {
  plan_track = osm_gps_map_track_new();

  GdkRGBA color;
  gdk_rgba_parse(&color, "#d2691e");

  osm_gps_map_track_set_color(plan_track, &color);
  osm_gps_map_track_add(map_view, plan_track);
}

GtkWidget* map_widget_new(void) {
  GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);

  GtkWidget* map = osm_gps_map_new();
  map_view = OSM_GPS_MAP(map);

  gtk_box_pack_start(GTK_BOX(box), map, TRUE, TRUE, 0);

  route_track_create();
  plan_track_create();

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

static GdkPixbuf* make_square_with_text(int size, const char* text) {
  const int padding = 8;
  const int font_size = 14;

  cairo_surface_t* tmp = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 1, 1);
  cairo_t* cr = cairo_create(tmp);

  cairo_select_font_face(
      cr, "Sans",
      CAIRO_FONT_SLANT_NORMAL,
      CAIRO_FONT_WEIGHT_NORMAL
  );
  cairo_set_font_size(cr, font_size);

  cairo_text_extents_t text_extents;
  cairo_text_extents(cr, text, &text_extents);

  cairo_font_extents_t font_extents;
  cairo_font_extents(cr, &font_extents);

  int width = size + padding + (int)ceil(text_extents.width);
  int height = MAX(size, (int)ceil(font_extents.height));

  cairo_destroy(cr);
  cairo_surface_destroy(tmp);

  cairo_surface_t* s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, width, height);

  cr = cairo_create(s);

  cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR);
  cairo_paint(cr);
  cairo_set_operator(cr, CAIRO_OPERATOR_OVER);

  cairo_set_source_rgb(cr, 0, 0, 0);
  cairo_rectangle(cr, 1, (height - size) / 2, size - 2, size - 2);
  cairo_fill(cr);

  cairo_select_font_face(
    cr, "Sans",
    CAIRO_FONT_SLANT_NORMAL,
    CAIRO_FONT_WEIGHT_NORMAL
  );
  cairo_set_font_size(cr, font_size);

  cairo_set_source_rgb(cr, 0, 0, 0);

  cairo_move_to(
    cr,
    size + padding,
    (height - font_extents.height) / 2 + font_extents.ascent
  );

  cairo_show_text(cr, text);

  cairo_destroy(cr);

  GdkPixbuf* pb = gdk_pixbuf_get_from_surface(s, 0, 0, width, height);

  cairo_surface_destroy(s);

  return pb;
}

static void marker_replace(double lat, double lon, GdkPixbuf* pb) {
  if (plane_marker) {
    osm_gps_map_image_remove(map_view, plane_marker);
    plane_marker = NULL;
  }

  if (pb)
    plane_marker = osm_gps_map_image_add(map_view, lat, lon, pb);
}

static void route_append_point(double lat, double lon) {
  OsmGpsMapPoint* point = osm_gps_map_point_new_degrees(lat, lon);

  if (point) {
    osm_gps_map_track_add_point(position_track, point);
    osm_gps_map_point_free(point);
  }

  has_old_position = TRUE;
}

void map_widget_set_marker(double lat, double lon) {
  if (!map_view) return;

  GdkPixbuf* square = make_square(14);
  marker_replace(lat, lon, square);
  if (square) g_object_unref(square);

  route_append_point(lat, lon);
}

void map_widget_set_marker_with_text(double lat, double lon, const char* text) {
  if (!map_view) return;

  GdkPixbuf* pb = make_square_with_text(14, text ? text : "");
  marker_replace(lat, lon, pb);
  if (pb) g_object_unref(pb);

  route_append_point(lat, lon);
}

void map_widget_clear_route(gboolean also_remove_marker) {
  if (!map_view) return;

  if (position_track) {
    osm_gps_map_track_remove(map_view, position_track);
    g_object_unref(position_track);
    position_track = NULL;
  }

  if (also_remove_marker && plane_marker) {
    osm_gps_map_image_remove(map_view, plane_marker);
    plane_marker = NULL;
  }

  has_old_position = FALSE;

  route_track_create();
}

void map_widget_draw_route(const double* lats, const double* lons, int count) {
  if (!map_view || !lats || !lons || count <= 0) return;

  map_widget_clear_route(FALSE);

  for (int i = 0; i < count; i++)
    route_append_point(lats[i], lons[i]);

  GdkPixbuf* square = make_square(14);
  marker_replace(lats[count - 1], lons[count - 1], square);
  if (square) g_object_unref(square);
}

void map_widget_add_to_route(const char* wpt_name, double lat, double lon) {
  if (!map_view || !plan_track) return;

  OsmGpsMapPoint* point = osm_gps_map_point_new_degrees(lat, lon);

  if (point) {
    osm_gps_map_track_add_point(plan_track, point);
    osm_gps_map_point_free(point);
  }

  GdkPixbuf* pb = make_square_with_text(10, wpt_name ? wpt_name : "");

  if (pb) {
    OsmGpsMapImage* img =
      osm_gps_map_image_add_with_alignment(map_view, lat, lon, pb, 0.0, 0.5);

    if (img)
      plan_images = g_slist_prepend(plan_images, img);

    g_object_unref(pb);
  }
}

void map_widget_clear_planned_route(void) {
  if (!map_view) return;

  for (GSList* l = plan_images; l; l = l->next)
    osm_gps_map_image_remove(map_view, (OsmGpsMapImage*)l->data);

  g_slist_free(plan_images);
  plan_images = NULL;

  if (plan_track) {
    osm_gps_map_track_remove(map_view, plan_track);
    g_object_unref(plan_track);
    plan_track = NULL;
  }

  plan_track_create();
}
