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
    'centos' => {
      codenames: {},
      flavour: 'redhat'
    },

    'debian' => {
      codenames: {
        'lenny'   => '5.0',
        'squeeze' => '6.0',
        'wheezy'  => '7.0'
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
