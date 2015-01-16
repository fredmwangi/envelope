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

using Envelope.DB;
using Envelope.Dialog;
using Envelope.Widget;
using Envelope.Service;
using Envelope.Service.Settings;

namespace Envelope.View {

    public class Sidebar : Gtk.ScrolledWindow {

        private static Sidebar sidebar_instance = null;

        public static new Sidebar get_default () {
            if (sidebar_instance == null) {
                sidebar_instance = new Sidebar ();
            }

            return sidebar_instance;
        }

        private static const int COLUMN_COUNT = 15;

        private static const string ICON_ACCOUNT    = "text-spreadsheet";
        private static const string ICON_OUTFLOW    = "go-up-symbolic";
        private static const string ICON_INFLOW     = "go-down-symbolic";
        private static const string ICON_REMAINING  = "view-refresh-symbolic";
        private static const string ICON_CATEGORY   = "folder-symbolic";
        private static const string ICON_ACTION_ADD = "tab-new-symbolic";

        private enum Action {
            NONE,
            ADD_ACCOUNT,
            ADD_CATEGORY,
            SHOW_CATEGORY,
            SHOW_OVERVIEW
        }

        private enum Column {
            LABEL,
            ACCOUNT,
            ICON,
            ACTION,
            DESCRIPTION,
            CATEGORY,
            STATE,
            TREE_CATEGORY,
            IS_HEADER,
            COLORIZE,
            TOOLTIP,
            BUDGET_STATE,
            EDITABLE,
            COLOR,
            CIRCLE
        }

        private enum TreeCategory {
            OVERVIEW,
            ACCOUNTS,
            CATEGORIES
        }

        private static const string COLOR_SUBZERO = "#A62626";
        private static const string COLOR_ZERO = "#4e9a06";
        private static const int CELL_FONT_WEIGHT_HEADER = 900;

        private Gtk.TreeView treeview;
        private Gtk.TreeStore store;
        private Gtk.TreeIter account_iter;
        private Gtk.TreeIter category_iter;
        private Gtk.TreeIter overview_iter;
        private Gtk.TreeIter overview_inflow_iter;
        private Gtk.TreeIter overview_outflow_iter;
        private Gtk.TreeIter overview_remaining_iter;
        private Gtk.TreeIter uncategorized_iter;

        private Gtk.TreeIter selected_iter;

        private Gtk.Menu right_click_menu;
        private Gtk.MenuItem right_click_menu_item_remove;

        private Granite.Widgets.CellRendererExpander cre;
        private Gtk.CellRendererText crt_balance_total;

        public Gee.ArrayList<Account> accounts { get; set; }

        public BudgetState budget_state { get; set; }

        public Account selected_account { get; private set; }

        private int current_account_id;

        private bool editing;   // this flag is used to inhibit sidebar actions
                                // while editing is taking place to prevent
                                // segmentation faults

        public signal void overview_selected ();
        public signal void category_selected (Category category);
        public signal void list_account_selected (Account account);
        public signal void list_account_name_updated (Account account, string new_name);
        public signal void list_category_name_updated (Category category, string new_name);

        private Sidebar () {
            store = new Gtk.TreeStore(COLUMN_COUNT,
                typeof (string),
                typeof (Account),
                typeof (string),
                typeof (Action),
                typeof (string),
                typeof (Category),
                typeof (string),
                typeof (TreeCategory),
                typeof (bool),
                typeof (bool),
                typeof (string),
                typeof (BudgetState),
                typeof (bool),
                typeof (string),
                typeof (Gdk.Pixbuf)
            );

            build_ui ();
            connect_signals ();

            sidebar_instance = this;
        }

        private void build_ui () {

            debug ("build ui");

            vexpand = true;
            vexpand_set = true;

            treeview = new Gtk.TreeView ();
            treeview.set_headers_visible (false);
            treeview.show_expanders = false;
            treeview.model = store;
            treeview.level_indentation = 10;
            treeview.activate_on_single_click = true;
            treeview.vexpand = true;
            treeview.vexpand_set = true;
            treeview.fixed_height_mode = true;
            treeview.tooltip_column = Column.TOOLTIP;
            treeview.add_events (Gdk.EventMask.FOCUS_CHANGE_MASK);

            // style
            var style_context = treeview.get_style_context ();
            style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);
            style_context.add_class (Granite.StyleClass.SOURCE_LIST);

            // selection
            var selection = treeview.get_selection ();
            selection.set_mode (Gtk.SelectionMode.SINGLE);
            selection.set_select_function (tree_selection_func);

            var col = new Gtk.TreeViewColumn ();
            col.max_width = -1;
            col.sizing = Gtk.TreeViewColumnSizing.FIXED;
            col.expand = true;
            col.spacing = 3;

            var crs = new Gtk.CellRendererText ();
            col.pack_start (crs, false);

            /*var cri = new Gtk.CellRendererPixbuf ();
            col.pack_start (cri, false);
            col.set_attributes (cri, "icon-name", Column.ICON);
            col.set_cell_data_func (cri, treeview_icon_renderer_function);
            */

            var crb = new Gtk.CellRendererPixbuf ();
            col.pack_start (crb, false);
            col.add_attribute (crb, "pixbuf", Column.CIRCLE);
            crb.visible = true;
            col.set_cell_data_func (crb, treeview_circle_renderer_function);

            var crt = new Gtk.CellRendererText ();
            col.pack_start (crt, true);
            crt.editable = true;
            crt.editable_set = true;
            crt.ellipsize = Pango.EllipsizeMode.END;
            crt.ellipsize_set = true;
            crt.edited.connect (item_renamed);
            crt.editing_started.connect (cr_start_editing);
            crt.editing_canceled.connect (cr_cancel_editing);

            col.set_attributes (crt, "markup", Column.LABEL);
            col.set_cell_data_func (crt, treeview_text_renderer_function);

            cre = new Granite.Widgets.CellRendererExpander ();
            cre.is_category_expander = true;
            cre.xalign = (float) 1.0;
            col.pack_end (cre, false);
            col.set_cell_data_func (cre, treeview_expander_renderer_function);

            crt_balance_total = new Gtk.CellRendererText ();
            crt_balance_total.editable = false;
            crt_balance_total.editable_set = true;
            crt_balance_total.xalign = (float) 1.0;
            crt_balance_total.size_points = 8;
            crt_balance_total.size_set = true;
            crt_balance_total.ellipsize = Pango.EllipsizeMode.NONE;
            crt_balance_total.ellipsize_set = true;
            crt_balance_total.edited.connect (balance_edited);
            crt_balance_total.editing_started.connect (cr_start_editing);
            crt_balance_total.editing_canceled.connect (cr_cancel_editing);
            col.pack_end (crt_balance_total, true);
            col.set_cell_data_func (crt_balance_total, treeview_text_renderer_balance_total_function);

            var crp = new Gtk.CellRendererProgress ();
            crp.value = 0;
            col.pack_end (crp, true);
            col.set_cell_data_func (crp, treeview_progress_renderer_function);

            add (treeview);

            treeview.append_column (col);

            treeview.row_activated.connect (treeview_row_activated);

            // right-click menu
            right_click_menu = new Gtk.Menu ();

            right_click_menu_item_remove = new Gtk.MenuItem.with_label (_("Remove"));
            right_click_menu.append (right_click_menu_item_remove);

            right_click_menu.show_all ();
        }

        private void connect_signals () {

            var budget_manager = BudgetManager.get_default ();
            budget_manager.budget_changed.connect (update_budget_section);
            budget_manager.budget_changed.connect (update_categories_section);
            budget_manager.category_added.connect (update_categories_section);
            budget_manager.category_deleted.connect (update_categories_section);
            budget_manager.category_renamed.connect (update_categories_section);

            var account_manager = AccountManager.get_default ();
            account_manager.account_created.connect (add_new_account);
            account_manager.account_updated.connect (update_account_item);

            treeview.button_press_event.connect (tree_button_press_event_func);

            right_click_menu_item_remove.activate.connect (popup_menu_remove_activated);
        }

        public void update_view () {

            store.clear ();

            var budget_manager = BudgetManager.get_default ();
            var budget_state = budget_manager.state;
            var remaining = Math.fabs (budget_state.inflow) - Math.fabs (budget_state.outflow);
            var month_label = new DateTime.now_local ().format ("%B %Y");

            overview_iter = add_item (null,
                month_label,
                TreeCategory.OVERVIEW,
                null,
                null,
                Action.SHOW_OVERVIEW,
                null,
                null,
                true,
                false,
                _("Budget overview for %s").printf (month_label),
                budget_state);

            overview_outflow_iter = add_item (null,
                _("Spending this month"),
                TreeCategory.OVERVIEW,
                null,
                null,
                Action.SHOW_OVERVIEW,
                budget_state.outflow,
                ICON_OUTFLOW,
                false,
                false,
                _("Money spent in %s").printf (month_label));

            overview_inflow_iter = add_item (null,
                _("Income this month"),
                TreeCategory.OVERVIEW,
                null,
                null,
                Action.SHOW_OVERVIEW,
                budget_state.inflow,
                ICON_INFLOW,
                false,
                false,
                _("Money earned in %s").printf (month_label));

            overview_remaining_iter = add_item (null,
                _("Remaining"),
                TreeCategory.OVERVIEW,
                null,
                null,
                Action.SHOW_OVERVIEW,
                remaining,
                ICON_REMAINING,
                false,
                true,
                _("Remaining balance for %s").printf (month_label));

            // Add "Accounts" category header
            account_iter = add_item (null,
                _("Accounts"),
                TreeCategory.ACCOUNTS,
                null,
                null,
                Action.NONE,
                null,
                null,
                true);

            foreach (Account account in accounts) {

                var color = get_color (account);

                var rgba = Gdk.RGBA ();
                rgba.parse (color);

                debug ("RGBA FOR ACCOUNT IS %s", rgba.to_string ());

                var pixbuf = get_circle (rgba);

                add_item (account_iter,
                    account.number,
                    TreeCategory.ACCOUNTS,
                    account,
                    null,
                    Action.NONE,
                    null,
                    ICON_ACCOUNT,
                    false,
                    true,
                    account.description != null ? "%s - %s".printf (account.number, account.description) : account.number,
                    null,
                    true,
                    color,
                    pixbuf);
            }

            // Add "Add account..."
            add_item (account_iter,
                _("Add account\u2026"),
                TreeCategory.ACCOUNTS,
                null,
                null,
                Action.ADD_ACCOUNT,
                null,
                ICON_ACTION_ADD,
                false,
                false,
                _("Add a new account"));

            // Add "Categories" category header
            category_iter = add_item (null,
                _("Spending categories"),
                TreeCategory.CATEGORIES,
                null,
                null,
                Action.NONE,
                null,
                null,
                true);

            // Add categories
            update_categories_section ();

            foreach (string path_str in new string[] {"0", "1", "2", "3", "4", "5"}) {
                treeview.expand_row (new Gtk.TreePath.from_string (path_str), false);
            }
        }

        public void s_account_created (Account account) {
            add_new_account (account);
        }

        public void add_account (Account account) {
            accounts.add (account);
            update_view ();
        }

        public void add_new_account (Account account) {
            add_account (account);
            select_account (account);
        }

        public void select_account (Account account) {

            Gtk.TreeIter? iter;

            if (get_account_iter (account, out iter)) {
                treeview.get_selection ().select_iter (iter);
                account_selected (account);
            }
        }

        public bool select_account_by_id (int account_id) {
            Gtk.TreeIter? iter;
            var account = get_account_iter_by_id (account_id, out iter);

            debug ("account by id %d: %s", account_id, account != null ? account.number : "null");

            if (account != null) {

                debug ("selecting account %d", account.@id);

                treeview.get_selection ().select_iter (iter);
                account_selected (account);

                return true;
            }

            return false;
        }

        public bool select_category_by_id (int category_id) {
            Gtk.TreeIter? iter;
            var category = get_category_iter_by_id (category_id, out iter);

            debug ("category by id %d: %s", category_id, category != null ? category.name : "null");

            if (category != null) {

                debug ("selecting category %d", category.@id);

                treeview.get_selection ().select_iter (iter);
                category_selected (category);

                return true;
            }

            return false;
        }

        // update budget balances
        private void update_budget_section () {

            debug ("update budget section");

            var budget_state = BudgetManager.get_default ().state;

            store.@set (overview_inflow_iter, Column.STATE, Envelope.Util.String.format_currency (budget_state.inflow), -1);
            store.@set (overview_outflow_iter, Column.STATE, Envelope.Util.String.format_currency (budget_state.outflow), -1);
            store.@set (overview_remaining_iter, Column.STATE, Envelope.Util.String.format_currency (budget_state.remaining), -1);
            store.@set (overview_iter, Column.BUDGET_STATE, budget_state, -1);
        }

        // Find the item in the tree which corresponds to account and update the account instance in the store
        private void update_account_item (Account account) {
            Gtk.TreeIter iter;
            if (get_account_iter (account, out iter)) {
                store.@set (iter, Column.ACCOUNT, account, -1);
            }
        }

        // recalculate category remaining balance for each category listed in the sidebar
        private void update_categories_section () {

            var budget_manager = BudgetManager.get_default ();

            try {

                Gtk.TreeIter first_child;
                if (store.iter_children (out first_child, category_iter)) {
                    bool valid = true;

                    while (valid) {
                        valid = store.remove (ref first_child);
                    }
                }

                // Add "Uncategorized"
                uncategorized_iter = add_item (category_iter, _("Uncategorized"), TreeCategory.CATEGORIES,
                    null, null, Action.NONE, (double) budget_manager.state.uncategorized.size, ICON_CATEGORY,
                    false, false, "", null, false);

                foreach (MonthlyCategory category in budget_manager.get_categories ()) {

                    double cat_inflow;
                    double cat_outflow;
                    BudgetManager.get_default ().compute_current_category_operations (category, out cat_inflow, out cat_outflow);

                    var current_category_iter = add_item (category_iter, category.name, TreeCategory.CATEGORIES, null, category, Action.SHOW_CATEGORY, cat_inflow - cat_outflow, ICON_CATEGORY);

                    // add subitems
                    if (cat_outflow != 0) {

                        add_item (current_category_iter, _("Budgeted amount"),
                            TreeCategory.CATEGORIES,
                            null,
                            category,
                            Action.NONE,
                            category.amount_budgeted, null,
                            false, true, "", null, true);

                        add_item (current_category_iter, _("Spending"),
                            TreeCategory.CATEGORIES,
                            null,
                            category,
                            Action.NONE,
                            cat_outflow, null,
                            false, true, "", null, false);

                        if (cat_outflow > category.amount_budgeted) {
                            add_item (current_category_iter, _("Over"),
                                TreeCategory.CATEGORIES,
                                null,
                                category,
                                Action.NONE,
                                cat_outflow - category.amount_budgeted, null,
                                false, true, "", null, false);
                        }
                        else {
                            add_item (current_category_iter, _("Remaining"),
                                TreeCategory.CATEGORIES,
                                null,
                                category,
                                Action.NONE,
                                category.amount_budgeted - cat_outflow, null,
                                false, true, "", null, false);
                        }
                    }

                    if (cat_inflow != 0) {
                        add_item (current_category_iter, _("Earnings"),
                            TreeCategory.CATEGORIES,
                            null,
                            category,
                            Action.NONE,
                            cat_inflow, null,
                            false, true, "", null, false);
                    }
                }
            }
            catch (ServiceError err) {
                error (err.message);
            }

            // Add category...
            add_item (category_iter, _("Add category\u2026"), TreeCategory.CATEGORIES, null, null, Action.ADD_CATEGORY, null, ICON_ACTION_ADD, false, false,
                _("Add a new spending category"));

            // expand all
            Gtk.TreePath? path = store.get_path (category_iter);
            if (path != null) {
                treeview.expand_row (path, false);
            }
        }

        /**
         * Add a sidebar item
         *
         * @param parent the parent element to insert under
         * @param tree_category the category of the item added
         * @param account the account to associate with the item
         * @param category the category to associate with the item
         * @param action the type of action to do when the item is selected
         * @param state_amount the amount to show at the right side of the item
         * @param icon the icon name to use for the item
         * @param is_header true if this is a category header, false otherwise
         * @param colorize true to colorize the amount shown at the right, false otherwise
         * @param tooltip the tooltip for the item
         * @param budget_state the budget state to use, or null
         * @return the Gtk.TreeIter for the new item
         */
        private Gtk.TreeIter add_item (Gtk.TreeIter? parent,
                                       string label,
                                       TreeCategory tree_category,
                                       Account? account,
                                       Category? category,
                                       Action action = Action.NONE,
                                       double? state_amount = null,
                                       string? icon = null,
                                       bool is_header = false,
                                       bool colorize = false,
                                       string tooltip = "",
                                       BudgetState? budget_state = null,
                                       bool is_editable = false,
                                       string? color = null,
                                       Gdk.Pixbuf? pixbuf = null) {

            debug ("add item '%s'", label);

            Gtk.TreeIter iter;

            store.append(out iter, parent);

            var state_currency = "";
            if (state_amount != null) {
                state_currency = Envelope.Util.String.format_currency (state_amount);
            }

            if (pixbuf != null) {
                debug ("PIXBUF IS THERE FOR %s", label);
            }

            store.@set (iter, Column.LABEL, label,
                Column.ACCOUNT, account,
                Column.ICON, icon,
                Column.ACTION, action,
                Column.DESCRIPTION, account != null ? account.description : null,
                Column.CATEGORY, category,
                Column.STATE, state_currency,
                Column.TREE_CATEGORY, tree_category,
                Column.IS_HEADER, is_header,
                Column.COLORIZE, colorize,
                Column.TOOLTIP, tooltip != "" ? tooltip : label,
                Column.BUDGET_STATE, budget_state,
                Column.EDITABLE, is_editable,
                Column.COLOR, color,
                Column.CIRCLE, pixbuf, -1);

            return iter;
        }

        private void treeview_circle_renderer_function ( Gtk.CellLayout layout,
                                                         Gtk.CellRenderer renderer,
                                                         Gtk.TreeModel model,
                                                         Gtk.TreeIter iter) {

            Gtk.CellRendererPixbuf crp = renderer as Gtk.CellRendererPixbuf;

            string? color;
            string label;
            Gdk.Pixbuf? pixbuf;
            model.@get (iter,
                Column.COLOR, out color,
                Column.CIRCLE, out pixbuf,
                Column.LABEL, out label, -1);

            crp.visible = true;

            if (color != null && pixbuf != null) {
                debug ("showing circle renderer for item %s", label);

            }
            /*else {
                debug ("hiding for item %s", label);
                renderer.visible = false;
            }
            */
        }

        private Gdk.Pixbuf get_circle (Gdk.RGBA color) {
            var surface = new Granite.Drawing.BufferSurface (16, 16);
            var context = surface.context;

            context.set_source_rgba (color.red, color.green, color.blue, 0.5);
            context.translate (16 / 2, 16 / 2);
            context.arc (0, 0, (16 / 2) - 2, 0, 2 * Math.PI);
            context.fill_preserve ();
            context.set_line_width (1);
            context.set_source_rgb (color.red, color.green, color.blue);
            context.stroke ();

            return surface.load_to_pixbuf ();
        }

        /**
         * cell renderer function for the budget overview progress bar
         */
        private void treeview_progress_renderer_function (  Gtk.CellLayout layout,
                                                            Gtk.CellRenderer renderer,
                                                            Gtk.TreeModel model,
                                                            Gtk.TreeIter iter) {

            Gtk.CellRendererProgress crp = renderer as Gtk.CellRendererProgress;

            crp.visible = false; // hidden by default

            TreeCategory tree_category;
            BudgetState? budget_state = null;

            model.@get (iter,
                Column.TREE_CATEGORY, out tree_category,
                Column.BUDGET_STATE, out budget_state, -1);

            switch (tree_category) {

                case TreeCategory.OVERVIEW:

                    if (budget_state != null) {
                        var percentage = percent ((int) budget_state.outflow, (int) budget_state.inflow);

                        crp.value = (int) Math.fmin (percentage, 100);
                        crp.visible = true;
                    }

                    break;
            }
        }

        /**
         * cell renderer function for item labels
         */
        private void treeview_text_renderer_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Gtk.CellRendererText crt = renderer as Gtk.CellRendererText;

            TreeCategory tree_category;
            model.@get (iter, Column.TREE_CATEGORY, out tree_category, -1);

            switch (tree_category) {
                case TreeCategory.OVERVIEW:
                    treeview_text_renderer_function_overview (crt, iter, model);
                    break;

                case TreeCategory.ACCOUNTS:
                    treeview_text_renderer_function_accounts (crt, iter, model);
                    break;

                case TreeCategory.CATEGORIES:
                    treeview_text_renderer_function_categories (crt, iter, model);
                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void treeview_text_renderer_balance_total_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Gtk.CellRendererText crt = renderer as Gtk.CellRendererText;

            TreeCategory tree_category;
            model.@get (iter, Column.TREE_CATEGORY, out tree_category, -1);

            switch (tree_category) {
                case TreeCategory.OVERVIEW:
                    treeview_text_renderer_amount_suffix_function_overview (crt, model, iter);
                    break;

                case TreeCategory.ACCOUNTS:
                    treeview_text_renderer_amount_suffix_function_accounts (crt, model, iter);
                    break;

                case TreeCategory.CATEGORIES:
                    treeview_text_renderer_amount_suffix_function_categories (crt, model, iter);
                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void treeview_icon_renderer_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Gtk.CellRendererPixbuf crp = renderer as Gtk.CellRendererPixbuf;

            string? icon_name = null;
            model.@get (iter, Column.ICON, out icon_name, -1);

            crp.visible = icon_name != null;
        }

        private void treeview_expander_renderer_function (Gtk.CellLayout layout, Gtk.CellRenderer renderer, Gtk.TreeModel model, Gtk.TreeIter iter) {

            bool is_header;
            TreeCategory tree_category;
            Category category;

            model.@get (iter,
                Column.IS_HEADER, out is_header,
                Column.TREE_CATEGORY, out tree_category,
                Column.CATEGORY, out category, -1);

            renderer.visible = (is_header && tree_category != TreeCategory.OVERVIEW) || (category != null && store.iter_has_child (iter));
        }

        private void treeview_text_renderer_function_overview (Gtk.CellRendererText crt, Gtk.TreeIter iter, Gtk.TreeModel model) {

            bool is_header;
            model.@get (iter, Column.IS_HEADER, out is_header, -1);

            crt.editable = false;
            crt.editable_set = true;

            if (is_header) {
                crt.weight = CELL_FONT_WEIGHT_HEADER;
                crt.weight_set = true;
                crt.height = 20;
            }
            else {
                crt.weight_set = false;
            }
        }

        private void treeview_text_renderer_function_accounts (Gtk.CellRendererText crt, Gtk.TreeIter iter, Gtk.TreeModel model) {

            bool is_header;
            model.@get (iter, Column.IS_HEADER, out is_header, -1);

            crt.editable = false;
            crt.editable_set = true;

            if (is_header) {
                crt.weight = CELL_FONT_WEIGHT_HEADER;
                crt.weight_set = true;
            }
            else {
                crt.weight_set = false;
                crt.editable = true;
                crt.editable_set = true;
            }
        }

        private void treeview_text_renderer_function_categories (Gtk.CellRendererText crt, Gtk.TreeIter iter, Gtk.TreeModel model) {

            bool is_header;
            model.@get (iter, Column.IS_HEADER, out is_header, -1);

            crt.editable = false;
            crt.editable_set = true;

            if (is_header) {
                crt.weight = CELL_FONT_WEIGHT_HEADER;
                crt.weight_set = true;
            }
            else {
                crt.weight_set = false;
                crt.editable = true;
                crt.editable_set = true;
            }
        }

        private void treeview_text_renderer_amount_suffix_function_overview (Gtk.CellRendererText crt, Gtk.TreeModel model, Gtk.TreeIter iter) {

            bool is_header;
            bool colorize;
            string state;
            model.@get (iter,
                Column.IS_HEADER, out is_header,
                Column.COLORIZE, out colorize,
                Column.STATE, out state, -1);

            crt.visible = true;
            crt.weight_set = false;

            if (is_header) {
                crt.visible = false;
            }
            else {

                crt.text = state;

                try {

                    double parsed_state = Envelope.Util.String.parse_currency (state);

                    if (parsed_state == 0) {
                        crt.text = _("None yet");
                    }
                    else {
                        if (colorize && parsed_state < 0) {
                            crt.foreground = COLOR_SUBZERO;
                            crt.foreground_set = true;
                        }
                        else {
                            crt.foreground_set = false;
                        }
                    }
                }
                catch (Envelope.Util.String.ParseError err) {
                    assert_not_reached ();
                }
            }
        }

        private void treeview_text_renderer_amount_suffix_function_accounts (Gtk.CellRendererText crt, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Account account;
            Action action;
            bool is_header;
            model.@get (iter,
                Column.ACCOUNT, out account,
                Column.ACTION, out action,
                Column.IS_HEADER, out is_header, -1);

            crt.foreground_set = false;

            if (is_header) {

                crt.visible = accounts != null && !accounts.is_empty;

                if (crt.visible) {

                    var balance = 0d;

                    foreach (Account a in accounts) {
                        balance += a.balance;
                    }

                    crt.text = Envelope.Util.String.format_currency (balance);
                    crt.foreground = color_for_amount (balance);
                    crt.foreground_set = true;
                }
            }
            else if (account != null && action == Action.NONE) {
                crt.visible = true;
                crt.text = Envelope.Util.String.format_currency (account.balance);
                crt.editable = true;
                crt.editable_set = true;
                crt.foreground = color_for_amount (account.balance);
                crt.foreground_set = true;
            }
            else {
                crt.visible = false;
                crt.foreground_set = false;
            }
        }

        private void treeview_text_renderer_amount_suffix_function_categories (Gtk.CellRendererText crt, Gtk.TreeModel model, Gtk.TreeIter iter) {

            Action action;
            bool is_header;
            string state;
            string label;
            Category category;
            bool is_editable;

            model.@get (iter,
                Column.ACTION, out action,
                Column.IS_HEADER, out is_header,
                Column.STATE, out state,
                Column.CATEGORY, out category,
                Column.LABEL, out label,
                Column.EDITABLE, out is_editable, -1);

            crt.foreground_set = false;
            crt.editable = is_editable;
            crt.visible = true;

            try {

                double parsed_state = Envelope.Util.String.parse_currency (state);

                if (category == null) { // "uncategorized"
                    crt.text = ((int) parsed_state).to_string ();
                }
                else {

                    // check if we're a category name or a subitem
                    if (store.iter_has_child (iter)) {
                        // category name
                        if (parsed_state == 0) {
                            crt.visible = false;
                            return;
                        }
                        else {
                            crt.visible = true;
                            crt.text = state;
                            crt.foreground = color_for_amount (parsed_state);
                            crt.foreground_set = true;
                        }
                    }
                    else {
                        crt.text = state;
                        crt.visible = true;

                        // subitem
                        if (parsed_state == 0) {
                            crt.visible = is_editable;
                        }
                        else {
                            crt.text = state;
                            crt.foreground = color_for_amount (parsed_state);
                            crt.foreground_set = true;
                        }
                    }
                }
            }
            catch (Envelope.Util.String.ParseError err) {
                error ("error occured while displaying amount in sidebar (%s)", err.message);

            }
        }

        private void cr_start_editing (Gtk.CellEditable editable, string path) {
            editing = true;
        }

        private void cr_cancel_editing () {
            editing = false;
        }

        private void balance_edited (string path, string new_text) {

            try {

                // parse first; if it fails, nothing expensive below will be executed
                double amount = Envelope.Util.String.parse_currency (new_text);

                Gtk.TreeIter iter;
                if (store.get_iter_from_string (out iter, path)) {

                    TreeCategory tree_category;
                    store.@get(iter, Column.TREE_CATEGORY, out tree_category, -1);

                    switch (tree_category) {
                        case TreeCategory.ACCOUNTS:
                            Account account;
                            store.@get (iter, Column.ACCOUNT, out account, -1);

                            account.balance = amount;

                            AccountManager.get_default ().update_account_balance (ref account);

                            break;

                        case TreeCategory.CATEGORIES:

                            debug ("BALANCE EDITED FOR CATEGORY");

                            MonthlyCategory category;
                            store.@get (iter, Column.CATEGORY, out category, -1);

                            category.amount_budgeted = amount;
                            store.@set (iter, Column.STATE, Envelope.Util.String.format_currency (amount), -1);

                            //BudgetManager.get_default ().update_category (category);

                            break;

                        default:
                            break;
                    }

                    treeview.get_selection ().select_iter (iter);
                }
                else {
                    assert_not_reached (); // should never land here!
                }

            }
            catch (Envelope.Util.String.ParseError err) {
                warning ("could not update account balance (%s)".printf (err.message));
            }
            catch (ServiceError err) {
                warning ("could not update account balance (%s)".printf (err.message));
            }

            editing = false;
        }

        private void treeview_row_activated (Gtk.TreePath path, Gtk.TreeViewColumn column) {

            debug ("row activated");

            Gtk.TreeIter iter;
            Gtk.TreeModel model;
            if (store.get_iter (out iter, path)) {

                selected_iter = iter;

                Account account;
                Action action;
                Category category;
                TreeCategory tree_category;
                bool is_header;

                store.@get (iter,
                    Column.ACCOUNT, out account,
                    Column.CATEGORY, out category,
                    Column.ACTION, out action,
                    Column.TREE_CATEGORY, out tree_category,
                    Column.IS_HEADER, out is_header, -1);

                if (account != null) {
                    account_selected (account);
                }

                switch (action) {

                    case Action.ADD_ACCOUNT:
                        var dialog = new AddAccountDialog ();
                        dialog.account_created.connect (s_account_created);
                        dialog.show_all ();
                        break;

                    case Action.SHOW_OVERVIEW:
                        overview_selected ();
                        break;

                    case Action.SHOW_CATEGORY:
                        category_selected (category);
                        break;

                    case Action.ADD_CATEGORY:
                        // TODO add new category
                        var dialog = new AddCategoryDialog ();
                        dialog.show_all ();
                        break;

                    case Action.NONE:
                        break;

                    default:
                        assert_not_reached ();
                }
            }
        }

        private void account_selected (Account account) {
            current_account_id = account.@id;
            selected_account = account;
            list_account_selected (account);
        }

        private bool get_account_iter (Account account, out Gtk.TreeIter iter) {

            Gtk.TreeIter? found_iter = null;
            int id = account.@id;

            store.@foreach ((model, path, fe_iter) => {

                Account val;
                model.@get (fe_iter, Column.ACCOUNT, out val, -1);

                if (val != null && val.@id == id) {
                    found_iter = fe_iter;
                    return true;
                }

                return false;
            });

            iter = found_iter;

            return found_iter != null;
        }

        private Account? get_account_iter_by_id (int account_id, out Gtk.TreeIter? iter) {
            Gtk.TreeIter? found_iter = null;
            Account? account = null;

            store.@foreach ((model, path, fe_iter) => {

                Account val;
                model.@get (fe_iter, Column.ACCOUNT, out val, -1);

                if (val != null && val.@id == account_id) {
                    found_iter = fe_iter;
                    account = val;
                    return true;
                }

                return false;
            });

            iter = found_iter;

            return account;
        }

        private Category? get_category_iter_by_id (int category_id, out Gtk.TreeIter? iter) {
            Gtk.TreeIter? found_iter = null;
            Category? category = null;

            store.@foreach ((model, path, fe_iter) => {

                Category val;
                model.@get (fe_iter, Column.CATEGORY, out val, -1);

                if (val != null && val.@id == category_id) {
                    found_iter = fe_iter;
                    category = val;
                    return true;
                }

                return false;
            });

            iter = found_iter;

            return category;
        }

        private void item_renamed (string path, string text) {

            Gtk.TreeIter iter;
            if (store.get_iter_from_string (out iter, path)) {

                Account account;
                Category category;
                TreeCategory tree_category;

                store.@get (iter,
                    Column.TREE_CATEGORY, out tree_category,
                    Column.ACCOUNT, out account,
                    Column.CATEGORY, out category, -1);

                switch (tree_category) {
                    case TreeCategory.ACCOUNTS:

                        store.@set (iter,
                            Column.LABEL, text,
                            Column.TOOLTIP, account.description != null ? "%s - %s".printf (text, account.description) : text, -1);

                        list_account_name_updated (account, text);
                        break;

                    case TreeCategory.CATEGORIES:

                        store.@set (iter,
                            Column.LABEL, text,
                            Column.TOOLTIP, text, -1);

                        list_category_name_updated (category, text);
                        break;

                    default:
                        assert_not_reached ();
                }

                treeview.get_selection ().select_iter (iter);
            }

            editing = false;
        }

        private void popup_menu_remove_activated () {

            Gtk.TreeIter iter;
            if (!treeview.get_selection ().get_selected (null, out iter)) {
                return;
            }

            TreeCategory tree_category;
            Category category;
            Account account;
            bool is_header;

            store.@get (iter,
                    Column.TREE_CATEGORY, out tree_category,
                    Column.CATEGORY, out category,
                    Column.ACCOUNT, out account,
                    Column.IS_HEADER, out is_header, -1);

            switch (tree_category) {
                case TreeCategory.OVERVIEW:
                    break;

                case TreeCategory.ACCOUNTS:
                    if (!is_header && account != null) {
                        remove_account (iter, account);
                    }

                    break;

                case TreeCategory.CATEGORIES:
                    if (!is_header && category != null) {
                        remove_category (iter, category);
                    }

                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void remove_category (Gtk.TreeIter iter, Category category) {

            try {
                BudgetManager.get_default ().delete_category (category);
                store.remove (ref iter);

                Envelope.App.toast (_("Category %s removed".printf (category.name)));
            }
            catch (ServiceError err) {
                error ("could not remove category (%s)", err.message);
            }
        }

        private void remove_account (Gtk.TreeIter iter, Account account) {
            try {
                AccountManager.get_default ().delete_account (account);
                store.remove (ref iter);

                Envelope.App.toast (_("Account %s removed".printf (account.number)));
            }
            catch (ServiceError err) {
                error ("could not remove account (%s)", err.message);
            }
        }

        private bool tree_button_press_event_func (Gtk.Widget widget, Gdk.EventButton event) {
            if (event.type != Gdk.EventType.BUTTON_PRESS) {
                return true;
            }

            if (editing) {
                return true;
            }

            var tree_view = widget as Gtk.TreeView;
            if (event.window != tree_view.get_bin_window ()) {
                return true;
            }

            Gtk.TreePath? path = null;
            tree_view.get_path_at_pos ((int) event.x, (int) event.y, out path, null, null, null);

            if (path == null) {
                return false;
            }

            switch (event.button) {
                case Gdk.BUTTON_PRIMARY:
                    return tree_button_primary_pressed (path, tree_view);

                case Gdk.BUTTON_SECONDARY:
                    return tree_button_secondary_pressed (path, tree_view, event);
            }

            return false;
        }

        private bool tree_button_primary_pressed (Gtk.TreePath path, Gtk.TreeView tree_view) {

            debug ("BUTTON PRIMARY PRESSED");

            bool toggle = false;

            if (is_header_at_path (path)) {
                toggle = true;
            }

            if (is_category_at_path (path)) {
                toggle = true;
                //tree_view.get_selection ().select_path (path);
            }

            if (toggle) {
                if (tree_view.is_row_expanded (path)) {
                    tree_view.collapse_row (path);
                }
                else {
                    tree_view.expand_row (path, false);
                }
            }

            return false;
        }

        private bool tree_button_secondary_pressed (Gtk.TreePath path, Gtk.TreeView tree_view, Gdk.EventButton event) {
            if (!is_header_at_path (path)) {

                var selection = tree_view.get_selection ();

                selection.unselect_all ();
                selection.select_path (path);

                right_click_menu.popup (null, null, null, event.button, event.get_time ());

                return true;
            }

            return false;
        }

        // determine if selection is allowed on a tree row
        private bool tree_selection_func (Gtk.TreeSelection selection, Gtk.TreeModel model, Gtk.TreePath path, bool currently_selected) {

            if (editing) {
                return false;
            }

            if (is_header_at_path (path) || is_overview_at_path (path)) {
                return false;
            }

            if (is_balance_editable_at_path (path)) {
                return true;
            }

            // we don't want to allow selection on category subitems (like budgeted amount, spending, income, etc)
            if (is_category_at_path (path)) {
                return path.get_depth () < 3;
            }

            return true;
        }

        // check if path points to an overview item row
        private bool is_overview_at_path (Gtk.TreePath path) {
            Gtk.TreeIter iter;

            if (store.get_iter (out iter, path)) {
                TreeCategory tree_category;
                store.@get (iter, Column.TREE_CATEGORY, out tree_category, -1);

                return tree_category == TreeCategory.OVERVIEW;
            }

            return false;
        }

        // check if path points to a category header row
        private bool is_header_at_path (Gtk.TreePath path) {
            Gtk.TreeIter iter;

            if (store.get_iter (out iter, path)) {
                bool is_header;
                store.@get (iter, Column.IS_HEADER, out is_header, -1);

                return is_header;
            }

            return false;
        }

        // check if path points to a category item
        private bool is_category_at_path (Gtk.TreePath path) {
            Gtk.TreeIter iter;

            if (store.get_iter (out iter, path)) {

                Category category;
                TreeCategory tree_category;

                store.@get (iter,
                    Column.TREE_CATEGORY, out tree_category,
                    Column.CATEGORY, out category, -1);

                return tree_category == TreeCategory.CATEGORIES && category != null;
            }

            return false;
        }

        private bool is_balance_editable_at_path (Gtk.TreePath path) {
            Gtk.TreeIter iter;

            if (store.get_iter (out iter, path)) {

                bool is_editable;
                store.@get (iter,
                    Column.EDITABLE, out is_editable, -1);

                return is_editable;
            }

            return false;
        }

        /**
         * Determine foreground color for amount
         */
        private string color_for_amount (double amount) {
            return amount < 0 ? COLOR_SUBZERO : COLOR_ZERO;
        }

        /**
         * Calculate the percentage of number from out_of
         */
        private int percent (int number, int out_of) {
            if (out_of == 0) {
                return 0;
            }

            return number * 100 / out_of;
        }

        private string get_color (Account account) {
            //Random.set_seed ((int32) new DateTime.now_local ().to_unix ());
            //return "rgba(0,0,0,%f)".printf(Random.double_range (0.5, 1.0));
            //return "rgba(0,0,0,1.0)";
            return "rgba(126,213,129,1.0)";
        }
    }
}
