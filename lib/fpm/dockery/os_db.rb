module FPM; module Dockery

  # Structure is
  #
  # <distribution> => {
  #   codenames: {
  #     <codename> => <version>
  #   },
  #   flavour: <flavour>
  # }
  OsDb = {
    'centos'.freeze => {
      codenames: {},
      flavour: 'redhat'.freeze
    },

    'debian'.freeze => {
      codenames: {
        'squeeze'.freeze => '6.0'.freeze
      },
      flavour: 'debian'.freeze
    },

    'ubuntu'.freeze => {
      codenames: {
        'precise'.freeze => '12.04'.freeze
      },
      flavour: 'debian'.freeze
    }
  }

end ; end
