module FPM; module Fry

  # Structure is
  #
  # <distribution> => {
  #   codenames: {
  #     <codename> => <version>
  #   },
  #   flavour: <flavour>
  # }
  OsDb = {
    'centos' => {
      codenames: {},
      flavour: 'redhat'
    },

    'debian' => {
      codenames: {
        'lenny'   => '5',
        'squeeze' => '6',
        'wheezy'  => '7'
      },
      flavour: 'debian'
    },

    'ubuntu' => {
      codenames: {
        'precise' => '12.04',
        'trusty'  => '14.04'
      },
      flavour: 'debian'
    }
  }

end ; end
