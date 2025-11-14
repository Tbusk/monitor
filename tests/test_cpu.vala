private GTop.SysInfo? system_info;
private GLib.HashTable<string, string> values;
private Monitor.CPU cpu;
string[] flags;
Gee.HashSet<string> flag_set;

private void test_cpu () {

    setup ();

    // must run first due to comparing fresh core usage
    Test.add_func ("/Monitor/Resources/CPU/get-core-list", test_get_core_list);

    Test.add_func ("/Monitor/Resources/CPU/get-load", test_get_load);
    Test.add_func ("/Monitor/Resources/CPU/get-model", test_get_model);
    Test.add_func ("/Monitor/Resources/CPU/get-family", test_get_family);
    Test.add_func ("/Monitor/Resources/CPU/get-microcode", test_get_microcode);
    Test.add_func ("/Monitor/Resources/CPU/get-cache-size", test_get_cache_size);
    Test.add_func ("/Monitor/Resources/CPU/get-bogomips", test_get_bogomips);
    Test.add_func ("/Monitor/Resources/CPU/get-model-name", test_get_model_name);
    Test.add_func ("/Monitor/Resources/CPU/get-address-sizes", test_get_address_sizes);
    Test.add_func ("/Monitor/Resources/CPU/get-bugs", test_get_bugs);

    // failing tests
    Test.add_func ("/monitor/CPU/get-features", test_get_features);

    Test.add_func ("/Monitor/Resources/CPU/get-frequency", test_get_harmonic_mean_frequency);
}

private void setup () {
    system_info = GTop.glibtop_get_sysinfo ();

    assert (system_info != null);

    values = system_info.cpuinfo[0].values;

    cpu = new Monitor.CPU ();

    // assuming 200 tokens is enough
    flags = values.get ("flags").split (" ", 200);

    flag_set = new Gee.HashSet<string>();
    foreach (string flag in flags) {
        flag_set.add (flag);
    }
}

private void test_get_model () {
    assert (cpu.model == values.get ("model"));
}

private void test_get_family () {
    assert (cpu.family == values.get ("cpu family"));
}

private void test_get_microcode () {
    assert (cpu.microcode == values.get ("microcode"));
}

private void test_get_cache_size () {
    assert (cpu.cache_size == values.get ("cache size"));
}

private void test_get_bogomips () {
    assert (cpu.bogomips == values.get ("bogomips"));
}

private void test_get_address_sizes () {
    assert (cpu.address_sizes == values.get ("address sizes"));
}

private void test_get_model_name () {
    uint64 thread_count = system_info.ncpu;

    assert (thread_count > 0);

    uint64 core_count = thread_count / 2;

    assert (core_count > 0);

    string core_label;

    if (core_count == 2) {
        core_label = "Dual-Core";
    } else if (core_count == 4) {
        core_label = "Quad-Core";
    } else if (core_count == 6) {
        core_label = "Hexa-Core";
    } else {
        core_label = core_count.to_string () + "\u00D7";
    }

    string model_name = Monitor.Utils.Strings.beautify (values.get ("model name"));

    assert (cpu.model_name == "%s %s".printf (core_label, model_name));
}

private Gee.HashMap<string, string> parse_csv (string file_name) {
    GLib.File file = File.new_for_path ("%s/%s".printf (Monitor.DBDIR, file_name));

    assert (file.query_exists ());

    Gee.HashMap<string, string> csv_data = new Gee.HashMap<string, string> ();

    try {
        GLib.DataInputStream data = new DataInputStream (file.read ());
        string? line = data.read_line_utf8 ();

        if (line != null) {
            line = line.replace ("\r", "");
        }

        while (line != null && line != "") {
            string[] bug_data = new string[2];
            int comma_position = line.index_of_char (',');

            if (comma_position == -1) break;

            bug_data[0] = line.substring (0, comma_position);

            bug_data[1] = line.substring (comma_position + 1)
                .replace ("\"", "")
                .replace("  ", " ")
                .strip ();

            csv_data.set (bug_data[0], bug_data[1]);

            line = data.read_line ();

            if (line != null) {
                line = line.replace ("\r", "");
            }
        }

        data.close ();

    } catch (Error error) {
        critical (error.message);
    }

    return csv_data;
}

private void test_get_bugs () {
    string[] bugs = values.get ("bugs").split (" ", 100); // assuming 100 is sufficient

    foreach (string bug in bugs) {
        assert (cpu.bugs.has_key (bug));
    }

    Gee.HashMap<string, string> bug_map = parse_csv ("cpu_bugs.csv");

    // 26 bugs in csv
    assert (bug_map.size == 26);

    foreach (string bug in bugs) {
        if (flag_set.contains (bug)) {
            assert (cpu.bugs.get (bug) == bug_map.get (bug));
        } else if (bug_map.get (bug) == null) {
            assert (cpu.bugs.get (bug) == Monitor.Utils.NOT_AVAILABLE);
        } else {
            assert (cpu.bugs.get (bug) == bug_map.get (bug));
        }
    }
}

private void test_get_features () {

    Gee.HashMap<string, string> feature_map = parse_csv ("cpu_features.csv");

    // 318 features in the csv
    assert (feature_map.size == 318);

    assert (cpu.features.size == flag_set.size);

    // check a few values are parsed correctly
    assert (feature_map.get ("fpu") == "Onboard FPU"); // first item
    assert (feature_map.get ("sme_coherent") == "AMD hardware-enforced cache coherency"); // last item
    assert (feature_map.get ("intel_ppin") == "Intel Processor Inventory Number");
    assert (feature_map.get ("invpcid_single") == "Effectively INVPCID && CR4.PCIDE=1");
    // values in csv surrounded by double quotes
    assert (feature_map.get ("k8") == "Opteron, Athlon64");
    assert (feature_map.get ("lm") == "Long Mode (x86-64, 64-bit support)");
    // has double-quotes and inner commas
    assert (feature_map.get ("avx512_bitalg") == "Support for VPOPCNT[B,W] and VPSHUF-BITQMB instructions");

    foreach (string key in flag_set) {
        if (feature_map.get (key) != null) {
            debug ("flag: %s -> '%s' vs '%s'", key, cpu.features.get (key), feature_map.get (key));
            assert (cpu.features.get (key) == feature_map.get (key));
        } else {
            debug ("flag: %s -> '%s' vs '%s'", key, cpu.features.get (key), Monitor.Utils.NOT_AVAILABLE);
            assert (cpu.features.get (key) == Monitor.Utils.NOT_AVAILABLE);
        }
    }
}

// https://en.wikipedia.org/wiki/Harmonic_mean
// formula is n / summation (1/val)
private void test_get_harmonic_mean_frequency () {
    GTop.SysInfo? system_info = GTop.glibtop_get_sysinfo ();

    uint64 number_of_threads = system_info.ncpu;

    double denominator = 0d;

    for (int thread = 0; thread < number_of_threads; thread++) {
        double frequency = 0d;

        try {
            string raw_reading;
            FileUtils.get_contents ("/sys/devices/system/cpu/cpu%u/cpufreq/scaling_cur_freq".printf (thread), out raw_reading);

            assert (/^\d+/.match (raw_reading));

            frequency = double.parse (raw_reading);

        } catch (Error error) {
            warning (error.message);
        }

        denominator += 1 / frequency;
    }

    cpu.update ();

    double harmonic_mean_khz = number_of_threads / denominator;
    double harmonic_mean_ghz = harmonic_mean_khz / 1000000;

    assert (harmonic_mean_ghz >= 0.1);

    // world record is 9.12GHz is the latest world record; 10 gives some room for future increases
    assert (harmonic_mean_ghz < 10);

    debug ("calculated: %.2f, actual: %.2f".printf (cpu.frequency, harmonic_mean_ghz));

    // threshold of 20% to satisfy usage spikes; normally within 0.1 to 0.2GHz outside of spikes
    double threshold = harmonic_mean_ghz * 0.2;

    assert (Math.fabs (cpu.frequency - harmonic_mean_ghz) < threshold);
}

private void test_get_core_list () {
    GTop.SysInfo? system_info = GTop.glibtop_get_sysinfo ();

    int number_of_threads = (int) system_info.ncpu;

    Gee.ArrayList<Monitor.Core> cores = new Gee.ArrayList<Monitor.Core> ();

    for (int thread = 0; thread < number_of_threads; thread++) {
        cores.add (new Monitor.Core (thread));
    }

    assert (cpu.core_list.size == cores.size);


    for (int thread = 0; thread < number_of_threads; thread++) {
        cores.get (thread).update ();
        cpu.core_list.get (thread).update ();

        assert (cores.get (thread).number == cpu.core_list.get (thread).number);
        debug ("thread: %d -> usage: %.2f vs actual %.2f".printf (thread, cores.get (thread).percentage_used, cpu.core_list.get (thread).percentage_used));

        // 10% threshold
        assert (Math.fabs (cores.get (thread).percentage_used - cpu.core_list.get (thread).percentage_used) < 0.10);
    }
}

private void test_get_load () {
    cpu.update ();

    GTop.Cpu gtop_cpu;
    GTop.get_cpu (out gtop_cpu);

    uint64 total = gtop_cpu.total;
    uint64 usage = total - gtop_cpu.iowait - gtop_cpu.idle;

    double calculated_load_percentage = ((double) usage / total) * 100;

    debug ("usage: %.0f vs recorded: %d".printf (calculated_load_percentage, cpu.percentage));
    // 2% threshold
    assert (Math.fabs ((double) cpu.percentage - calculated_load_percentage) < 2);

    assert (calculated_load_percentage >= 0);
    assert (calculated_load_percentage <= 100);

    assert (Math.round (calculated_load_percentage) <= 100);
}