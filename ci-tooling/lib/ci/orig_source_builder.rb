require 'fileutils'

require_relative '../debian/changelog'
require_relative '../lsb'
require_relative '../os'
require_relative 'build_version'
require_relative 'source'
require_relative 'tar_fetcher'

module CI
  class OrigSourceBuilder
    def initialize(release: LSB::DISTRIB_CODENAME, strip_symbols: false)
      # @name
      # @version
      # @tar
      @release = release
      @release_version = OS::VERSION_ID
      @strip_symbols = strip_symbols

      @build_rev = ENV.fetch('BUILD_NUMBER')

      @packagingdir = File.absolute_path('packaging')

      # This is probably behavior that should be in a base sourcer?
      FileUtils.rm_r('build') if Dir.exist?('build')
      Dir.mkdir('build')
      @builddir = File.absolute_path('build')

      @sourcepath = "#{@builddir}/source" # Created by extract.

      # FIXME: builder should generate a Source instance
    end

    def log_change
      # FIXME: this has email and fullname from env, see build_source
      # FIXME: code copy from build_source
      changelog = Changelog.new
      raise "Can't parse changelog!" if changelog.nil?
      base_version = changelog.version
      if base_version.include?('ubuntu')
        base_version = base_version.split('ubuntu')
        base_version = base_version[0..-2].join('ubuntu')
      end
      base_version = "#{base_version}+#{@release_version}+build#{@build_rev}"
      # FIXME: code copy from build_source
      # FIXME: dch should include build url
      dch = %w(dch)
      dch << '--force-bad-version'
      dch << '--distribution' << @release
      dch << '-v' << base_version
      dch << 'Automatic CI Build'
      unless system(*dch)
        # :nocov:
        # dch cannot actually fail because we parse the changelog beforehand
        # so it is of acceptable format here already.
        raise 'Failed to create changelog entry'
        # :nocov:
      end
    end

    def build(tarball)
      FileUtils.cp(tarball.path, @builddir)
      tarball.extract(@sourcepath)
      FileUtils.cp_r(Dir.glob("#{@packagingdir}/*"), @sourcepath)
      Dir.chdir(@sourcepath) do
        log_change
        mangle!
        build_internal
      end
    end

    def mangle!
      if @strip_symbols
        Dir.chdir(@sourcepath) do
          symbols = Dir.glob('debian/symbols') +
                    Dir.glob('debian/*.symbols') +
                    Dir.glob('debian/*.symbols.*')
          symbols.each { |s| FileUtils.rm(s) }
        end
      end
    end

    def build_internal
      # FIXME: code copy from build_source
      # dpkg-buildpackage
      Dir.chdir(@sourcepath) do
        system('update-maintainer')
        # Force -sa as reprepreo refuses to accept uploads without orig.
        return if system('dpkg-buildpackage', '-us', '-uc', '-S', '-d', '-sa')
        raise 'Could not run dpkg-buildpackage!'
      end
    end
  end
end
