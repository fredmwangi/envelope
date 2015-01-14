/* Copyright 2014 Nicolas Laplante
*
* This file is part of envelope.
*
* envelope is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* envelope is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with envelope. If not, see http://www.gnu.org/licenses/.
*/

namespace Envelope.Widget {

    public class CellRendererColoredCircle : Gtk.CellRenderer {

        public Gdk.RGBA color { get; set; }

        public CellRendererColoredCircle () {
            Object ();
        }

        public override void get_size (Gtk.Widget widget, Gdk.Rectangle? cell_area, out int x_offset, out int y_offset,
                out int width, out int height) {

            x_offset = 0;
            y_offset = 0;
            width = 16;
            height = 16;
        }

        public override void render (Cairo.Context ctx, Gtk.Widget treeview, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {

            var width = cell_area.width;
            var height = cell_area.height;

            double xc = width / 2.0;
            double yc = height / 2.0;
            double radius = int.min (width, height) / 2.0;
            double angle1 = 0;
            double angle2 = 2 * Math.PI;

            debug ("width %f, height %f, xc: %f, yc: %f, radius: %f, angle1: %f, angle2: %f, visible: %s",
                width, height, xc, yc, radius, angle1, angle2, visible ? "true" : "false");

            //Cairo.Context ctx2 = new Cairo.Context (ctx.get_target ());

            Gdk.cairo_set_source_rgba (ctx, color);
            ctx.set_line_width (10.0);
            ctx.arc (xc, yc, radius, angle1, angle2);
            ctx.stroke ();
            ctx.fill ();
        }

    }
}
