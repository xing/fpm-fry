module FPM::Fry::Plugin::SameVersion

  # Generates a special constraint that ignores iterations.
  # This is especially pointful in multi-package recipes.
  # @example
  #   name 'mainpackage'
  #   version '0.2.3'
  #   package 'subpackage'
  #     plugin 'same_version'
  #     depends 'mainpackage', same_version
  #   end
  #
  def same_version
    *head, last = version.split('.')
    last = last.to_i + 1
    return ">= #{version}, << #{head.join '.'}.#{last}"
  end

end
