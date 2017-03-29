namespace PixelSaver {
public class TitleBarManager : Object {

    private Wnck.Screen screen;
    private Wnck.Window active_window;

    private static TitleBarManager instance;

    public static TitleBarManager INSTANCE {
        get {
            if(instance == null){
                instance = new TitleBarManager();
            }
            return instance;
        }
    }

    public signal void on_title_changed (string title);
    public signal void on_window_state_changed (bool is_maximized);
    public signal void on_active_window_changed (bool is_null);

    private TitleBarManager()
    {
        this.screen = Wnck.Screen.get_default();
        this.active_window = this.screen.get_active_window();

        this.screen.active_window_changed.connect( this.on_wnck_active_window_changed );
        this.screen.window_opened.connect( this.on_window_opened );
        this.screen.force_update();
        unowned List<Wnck.Window> windows = this.screen.get_windows_stacked();
        foreach(Wnck.Window window in windows){
            if(window.get_window_type() != Wnck.WindowType.NORMAL) continue;

            this.toggle_title_bar_for_window(window, false);
        }
        this.on_wnck_active_window_changed(this.screen.get_active_window());

        this.screen.window_closed.connect( (w) => {
            this.screen.force_update();
            this.on_wnck_active_window_changed(w);
        });
    }

    ~TitleBarManager() {
        unowned List<Wnck.Window> windows = this.screen.get_windows_stacked();
        foreach(Wnck.Window window in windows){
            if(window.get_window_type() != Wnck.WindowType.NORMAL) continue;

            this.toggle_title_bar_for_window(window, true);
        }
    }

    public void close_active_window(){
        if(this.active_window == null) return;

        this.active_window.close(this.get_x_server_time());
    }

    public void toggle_maximize_active_window(){
        if(this.active_window == null) return;

        if(this.active_window.is_maximized()){
            this.active_window.unmaximize();
        } else {
            this.active_window.maximize();
        }
    }

    public void minimize_active_window(){
        if(this.active_window == null) return;

        this.active_window.minimize();
    }

    private void toggle_title_bar_for_window(Wnck.Window window, bool is_on){
        try {
            string[] spawn_args = {"xprop", "-id", "%#.8x".printf((uint)window.get_xid()),
                "-f", "_GTK_HIDE_TITLEBAR_WHEN_MAXIMIZED", "32c", "-set",
                "_GTK_HIDE_TITLEBAR_WHEN_MAXIMIZED", is_on ? "0x0" : "0x1"};
            string[] spawn_env = Environ.get ();
            Pid child_pid;

            Process.spawn_async ("/",
                spawn_args,
                spawn_env,
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                null,
                out child_pid);

            ChildWatch.add (child_pid, (pid, status) => {
                if(window.is_maximized()) {
                    window.unmaximize();
                    window.maximize();
                }
                Process.close_pid (pid);
            });
        } catch(SpawnError e){
            error(e.message);
        }
    }

    private void on_wnck_active_window_changed(Wnck.Window previous_window){
        if(previous_window != null){
            previous_window.name_changed.disconnect( this.on_active_window_name_changed );
            previous_window.state_changed.disconnect( this.on_active_window_state_changed );
        }

        this.active_window = this.screen.get_active_window();
        if(this.active_window.get_window_type() != Wnck.WindowType.NORMAL){
            this.active_window = null;
        }

        if(this.active_window != null){
            this.active_window.name_changed.connect( this.on_active_window_name_changed );
            this.active_window.state_changed.connect( this.on_active_window_state_changed );
            this.on_title_changed(this.active_window.get_name());
        } else {
            this.on_title_changed("");
        }
        this.on_active_window_changed(this.active_window == null);
    }

    private void on_window_opened(Wnck.Window window){
        this.toggle_title_bar_for_window(window, false);
    }

    private void on_active_window_name_changed(){
        this.on_title_changed(this.active_window.get_name());
    }

    private void on_active_window_state_changed(Wnck.WindowState changed_mask, Wnck.WindowState new_state){
        this.on_window_state_changed(this.active_window.is_maximized());
    }

    private uint32 get_x_server_time() {
        unowned X.Window xwindow = Gdk.X11.get_default_root_xwindow();
        unowned X.Display xdisplay = Gdk.X11.get_default_xdisplay();
        Gdk.X11.Display display = Gdk.X11.Display.lookup_for_xdisplay(xdisplay);
        Gdk.X11.Window window = new Gdk.X11.Window.foreign_for_display(display, xwindow);
        return Gdk.X11.get_server_time(window);
    }
}
}