require 'mercurial-ruby'
require 'fileutils'
require_relative 'debian/changelog'

class KDEIfy
  PATCHES = %w(../suse/firefox-kde.patch ../suse/mozilla-kde.patch).freeze
  class << self
    def init_env
      ENV['QUILT_PATCHES'] = 'debian/patches'
    end

    def apply_patches
      # Need to remove unity menubar from patches first since it interferes with
      # the KDE patches
      system('quilt delete unity-menubar.patch')
      PATCHES.each do |patch|
        system("quilt import #{patch}")
      end
    end

    def install_kde_js
      FileUtils.cp('../suse/MozillaFirefox/kde.js', 'debian/')
      rules = File.read('debian/rules')
      rules.gsub!(/pre-build.*$/) do |m|
        m += "\n\tmkdir -p $(MOZ_DISTDIR)/bin/defaults/pref/\n\tcp $(CURDIR)/debian/kde.js $(MOZ_DISTDIR)/bin/defaults/pref/kde.js"
      end
      File.write('debian/rules', rules)
    end

    def add_plasma_package(package)
      # Add dummy package
      control = File.read('debian/control.in')
      control += "\nPackage: @MOZ_PKG_NAME@-plasma
Architecture: any
Depends: @MOZ_PKG_NAME@ (= ${binary:Version}), mozilla-kde-support
Description: #{package} package for integration with KDE
 Install this package if you'd like #{package} with Plasma integration
"
      File.write('debian/control.in', control)
      system('debian/rules debian/control')
    end

    def filterdiff
      PATCHES.each do |patch|
        filterdiff = `filterdiff --addprefix=a/mozilla/ --strip 1 #{patch}`
        # Newly created files are represented as /dev/null in the old prefix
        # This leads to issues when we add the new prefix via filterdiff
        # gsub'ing the path's back to /dev/null allows for the patches to
        # apply properly
        filterdiff.gsub!(%r{a\/mozilla\/\/dev\/null}, '/dev/null')
        File.write(patch, filterdiff)
      end
    end

    def firefox!
      init_env
      Dir.chdir('packaging') do
        apply_patches
        install_kde_js
        add_plasma_package('firefox')
      end
    end

    def thunderbird!
      init_env
      Dir.chdir('packaging') do
        filterdiff
        apply_patches
        install_kde_js
        add_plasma_package('thunderbird')
      end
    end
  end
end
