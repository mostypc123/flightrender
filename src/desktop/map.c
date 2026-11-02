#include <osm-gps-map.h>
#include <gtk/gtk.h>

GtkWidget* map_widget_new(void) {
  GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);

  GtkWidget *map = osm_gps_map_new();
  gtk_box_pack_start(GTK_BOX(box), map, TRUE, TRUE, 0);

  GtkWidget *attr = gtk_label_new(NULL);
  gtk_label_set_markup(GTK_LABEL(attr),
    "<small>© <a href=\"https://www.openstreetmap.org/copyright\">"
    "OpenStreetMap</a> contributors</small>");
  gtk_widget_set_halign(attr, GTK_ALIGN_END);
  gtk_box_pack_start(GTK_BOX(box), attr, FALSE, FALSE, 2);

  return box;
}
