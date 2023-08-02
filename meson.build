project('evdevhook2', ['c', 'vala'],
          version: '0.1.0',
    meson_version: '>= 0.50.0',
  default_options: [ 'warning_level=2',
                   ],
)

gcemuhook_proj = subproject('gcemuhook', default_options: ['default_library=static'])
gcemuhook_dep  = gcemuhook_proj.get_variable('gcemuhook_dep')

extra_vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', extra_vapi_dir], language: 'vala')

subdir('src')

#install_data('ExampleConfig.ini', install_dir : get_option('datadir') / 'evdevhook2')
