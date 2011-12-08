// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011 Adrien Plazas <kekun.plazas@laposte.net>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

/* TODO
 * For 0.2
 * Notify with system bubbles if the window is not focused (tag FIXME)
 * Use stepped window resize ? (usefull if using another terminal background color than the one from the window)
 * Start the port to the terminal background service
 */

using Gtk;
using Gdk;
using Vte;
using Pango;
using Granite;
//using Notify;

namespace PantheonTerminal {

    public class PantheonTerminalWindow : Gtk.Window {

        public signal void theme_changed();

        public Granite.Application app;
        Notebook notebook;
        public Toolbar toolbar;
        FontDescription font;
        Gdk.Color bgcolor;
        Gdk.Color fgcolor;
        private Button add_button;
        //Notify.Notification notification;

        public Gtk.ActionGroup main_actions;

        string[] args;

        // Control and Shift keys
        bool ctrlL = false;
        bool ctrlR = false;
        bool shiftL = false;
        bool shiftR = false;
        bool arrow = false;
        bool tab = false;

        bool window_focus = false;

        public PantheonTerminalWindow (Granite.Application app = null) {

            this.app = app;
            set_application (app);

            //Gtk.Settings.get_default().gtk_application_prefer_dark_theme = true;
            title = _("Terminal");
            set_default_size (640, 400);
            icon_name = "utilities-terminal";

            setup_ui ();
            set_theme ();
            show_all ();
            connect_signals ();

            new_tab (true);
        }

        private void setup_ui () {

            /* Set up the Notebook */
            notebook = new Notebook ();
            var right_box = new HBox (false, 0);
            right_box.show ();
            notebook.set_action_widget (right_box, PackType.END);
            notebook.set_scrollable (true);
            notebook.can_focus = false;
            add (notebook);

            /* Set up the Add button */
            add_button = new Button();
            add_button.can_focus = false;

            Image add_image = null;
            try {
                add_image = new Image.from_icon_name ("list-add-symbolic", IconSize.MENU);
            } catch (Error err1) {
                try {
                    add_image = new Image.from_icon_name ("list-add", IconSize.MENU);
                } catch (Error err2) {
                    stderr.printf ("Unable to load list-add icon: %s", err2.message);
                }
            }

            add_button.set_image (add_image);
            add_button.show();
            add_button.set_relief(ReliefStyle.NONE);
            add_button.set_tooltip_text("Open a new tab");
            right_box.pack_start (add_button, false, false, 0);
        }

        private void connect_signals () {

            destroy.connect (close);

            add_button.clicked.connect(() => { new_tab(false); } );

            key_press_event.connect (on_key_press_event);
            key_release_event.connect (on_key_release_event);
        }

        public void remove_page (int page) {

            notebook.remove_page (page);

            if (notebook.get_n_pages () == 0)
                new_tab (false);
        }

        public override bool scroll_event (EventScroll event) {

            switch (event.direction.to_string ()) {
                case "GDK_SCROLL_UP":
                case "GDK_SCROLL_RIGHT":
                    notebook.page++;
                    break;
                case "GDK_SCROLL_DOWN":
                case "GDK_SCROLL_LEFT":
                    notebook.page--;
                    break;
            }
            return false;
        }

        public bool on_key_press_event (EventKey event) {

            string key = Gdk.keyval_name (event.keyval);

            if (key == "Control_L")
                ctrlL = true;
            else if (key == "Control_R")
                ctrlR = true;
            else if (key == "Shift_L")
                shiftL = true;
            else if (key == "Shift_R")
                shiftR = true;

            /*
            else if (key == "Tab")
            {
                notebook.get_nth_page(notebook.get_current_page()).grab_focus();
                stdout.printf("tab %i\n", notebook.get_current_page());
            }
            */

            else if ((ctrlL || ctrlR) && (shiftL || shiftR)) {
                if (key == "t" || key == "T")
                    new_tab(false);
                else if (key == "w" || key == "W")
                    remove_page(notebook.get_current_page());
                else if (key == "Tab" || key == "ISO_Left_Tab")
                {
                    if (notebook.get_current_page() < notebook.get_n_pages() - 1)
                        notebook.next_page();
                    else
                        notebook.set_current_page(0);
                }
                else if (key == "q" || key == "Q")
                    close();
                else
                    return false;
            }
            else if (key == "Up" || key == "Down" || key == "Left" || key == "Right")
                arrow = true;
            else if (key == "Tab")
                tab = true;
            // stdout.printf("%s\n", key);
            return false;
        }

        public bool on_key_release_event(EventKey event) {

            string key = Gdk.keyval_name(event.keyval);

            if (key == "Control_L")
                ctrlL = false;
            else if (key == "Control_R")
                ctrlR = false;
            else if (key == "Shift_L")
                shiftL = false;
            else if (key == "Shift_R")
                shiftR = false;
            else if (key == "Up" || key == "Down" || key == "Left" || key == "Right")
                arrow = false;
            else if (key == "Tab")
                tab = false;

            return false;
        }

        private void new_tab (bool first) {

            // Set up terminal
            var t = new TerminalWithNotification (this);
            var s = new ScrolledWindow (null, null);
            s.add (t);

            /* To avoid a gtk/vte bug (needs more investigating) */
            var box = new Gtk.Grid ();
            box.add (s);
            t.vexpand = true;
            t.hexpand = true;

            // Set up style
            set_terminal_theme(t);
            if (first && args.length != 0) {
                t.fork_command_full (Vte.PtyFlags.DEFAULT, "~/", args, null, SpawnFlags.SEARCH_PATH, null, null);
                //t.fork_command_full(PtyFlags.DEFAULT, null, null, null, SpawnFlags.FILE_AND_ARGV_ZERO, null, 0);
                //t.fork_command(args[0], args, null, null, true, true, true);
            } else {
                t.fork_command_full (Vte.PtyFlags.DEFAULT, "~/",  { Vte.get_user_shell() }, null, SpawnFlags.SEARCH_PATH, null, null);
                //t.fork_command_full(PtyFlags.DEFAULT, null, null, null, SpawnFlags.LEAVE_DESCRIPTORS_OPEN, null, t.get_pty());
                //t.fork_command(null, null, null, null, true, true, true);
                //t.forkpty(null, null, true, true, true);
            }

            // Set up style
            set_terminal_theme (t);
            t.show ();

            // Set up style
            set_terminal_theme (t);

            // Create a new tab with the terminal
            var tab = new TabWithCloseButton ("Terminal");
            int new_page = notebook.get_current_page () + 1;
            notebook.insert_page (box, tab, new_page);
            notebook.next_page ();
            notebook.set_tab_reorderable (tab, true);
            notebook.set_tab_detachable (tab, true);

            // Set connections
            tab.clicked.connect (() => { remove_page (notebook.page_num (t)); });

            t.window_title_changed.connect (() => {
                string new_text = t.get_window_title ();
                int i;

                for (i = 0; i < new_text.length; i++) {
                    if (new_text[i] == ':') {
                        new_text = new_text[i + 2:new_text.length];
                        break;
                    }
                }

                tab.set_text (new_text);
            });

            notebook.switch_page.connect ((page, page_num) => { if (notebook.page_num (t) == (int) page_num) tab.set_notification (false); });
            focus_in_event.connect (() => { if (notebook.page_num (t) == notebook.get_current_page ()) tab.set_notification (false); return false; });
            t.preferences.connect (preferences);

            theme_changed.connect (() => { set_terminal_theme (t); });

            // If a task is over
            t.task_over.connect (() => {

                if (notebook.page_num (t) != notebook.get_current_page () || !window_focus)
                    tab.set_notification (true);

                if (this.is_focus) {
                    print ("Hey focus...\n");
                } else { print ("No focus...\n"); }

                if (!this.is_focus)
                {
                    try {
                        //if (this.is_focus) {
                            GLib.Process.spawn_command_line_async ("notify-send --icon=\"utilities-terminal\" \"" + t.get_window_title () + "\" \"Task finished.\"");
                        //}
                    }
                    catch {  }
                }
                /*
                notification = (Notify.Notification)GLib.Object.new (
                    typeof (Notify.Notification),
                    "summary", "sum",
                    "body", "message",
                    "icon-name", "");
                // Notify OSD
                notification = new Notification("test", "test", "test");
                try { notification.show(); } catch {}
                */
            });

            t.child_exited.connect (() => {remove_page (notebook.page);});

            if (first)
                t.grab_focus ();
            set_terminal_theme (t);
            box.show_all ();
            notebook.page = new_page;
        }

        public void set_terminal_theme (TerminalWithNotification t) {

            t.set_font (font);
            t.set_color_background (bgcolor);
            t.set_color_foreground (fgcolor);
        }

        public void set_theme () {

            string theme = "dark";

            if (theme == "normal") {
                Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = false;

                // Get the system's style
                realize ();
                font = FontDescription.from_string (system_font ());
                bgcolor = get_style ().bg[StateType.NORMAL];
                fgcolor = get_style ().fg[StateType.NORMAL];
            }
            else {
                Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;

                // Get the system's style
                realize ();
                font = FontDescription.from_string (system_font ());
                bgcolor = get_style ().bg[StateType.NORMAL];
                fgcolor = get_style ().fg[StateType.NORMAL];
            }

            theme_changed ();
        }

        static string system_font () {

            string font_name = null;

            /* Wait for GNOME 3 FIXME */
            //var settings = new GLib.Settings("org.gnome.desktop.interface");
            //font_name = settings.get_string("monospace-font-name");

            font_name = "Droid Sans Mono 10";
            return font_name;
        }

        public void preferences () {

            var dialog = new Preferences (_("Preferences"), this);
            dialog.show_all ();
            dialog.run ();
            dialog.destroy ();
        }


        private void close() {

            Gtk.main_quit ();
        }

    }

    public class TabWithCloseButton : HBox {

        public signal void clicked ();

        private Button button;
        public Label label;

        private string text;
        bool notification = false;
        public bool reorderable = true;
        public bool detachable = true;

        public TabWithCloseButton (string text) {

            this.text = text;

            // Button
            button = new Button ();
            button.set_image (new Image.from_stock (Stock.CLOSE, IconSize.MENU));
            button.show ();
            button.set_relief (ReliefStyle.NONE);
            button.clicked.connect (() => { clicked(); });

            // Label
            label = new Label (text);
            label.show ();

            // Pack the elements
            pack_start (button, false, true, 0);
            pack_end (label, true, true, 0);

            show ();
        }

        public void set_notification (bool notification) {

            this.notification = notification;

            if (notification)
                label.set_markup ("<span color=\"#18a0c0\">" + text + "</span>");
            else
                label.set_markup (text);
        }

        public void set_text (string text) {

            this.text = text;
            set_notification (notification);
        }
    }
}