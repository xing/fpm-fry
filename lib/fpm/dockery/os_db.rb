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
    'ubuntu'.freeze => {
      codenames: {
        'precise'.freeze => '12.04'.freeze
      },
      flavour: 'debian'.freeze
    }
  }

end ; end
