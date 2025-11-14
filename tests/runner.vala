void main (string[] args) {

    Test.init (ref args);
    Gtk.init ();

    test_cpu ();
    test_statusbar ();

    Test.run ();
}
