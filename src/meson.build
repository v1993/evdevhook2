evdevhook2_sources = [
  'main.vala',
  'Config.vala',
  'EvdevCemuhookDevice.vala',
  'Server.vala',
]

evdevhook2_deps = [
  dependency('glib-2.0',      version: '>= 2.50'),
  dependency('gio-2.0',       version: '>= 2.50'),
  dependency('gee-0.8',       version: '>= 0.20'),
  dependency('libudev'),
  dependency('libevdev'),

  gcemuhook_dep,

  meson.get_compiler('vala').find_library('linux'),
  meson.get_compiler('vala').find_library('posix'),
]

gnome = import('gnome')

evdevhook2_sources += gnome.compile_resources('evdevhook2-resources',
  'evdevhook2.gresource.xml',
  c_name: 'evdevhook2'
)

evdevhook2 = executable ('evdevhook2', evdevhook2_sources,
  dependencies: evdevhook2_deps,
  install: true,

  vala_args: [
    #'--enable-experimental-non-null',
  ],

  c_args: [
    '-DEV_VERSION="@0@"'.format(meson.project_version())
  ]
)
