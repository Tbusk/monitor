test_sources = files(run_command('list-src.sh', check: true).stdout().strip().split('\n'))

test(
    'monitor-test',
    executable('monitor-test', test_sources, [
              meson.source_root() / 'src/Resources/CPU.vala',
              meson.source_root() / 'src/Resources/Core.vala',
              meson.source_root() / 'src/Resources/CPUCache.vala',
              meson.source_root() / 'src/Resources/Hwmon/HwmonTemperature.vala',
              meson.source_root() / 'src/Utils.vala',
              meson.source_root() / 'src/Widgets/Statusbar/Statusbar.vala',
              meson.source_root() / 'src/Resources/ResourcesSerialized.vala'
    ],
    project_config,
    dependencies: app_dependencies)
)