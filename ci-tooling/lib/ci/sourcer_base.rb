# frozen_string_literal: true
#
# Copyright (C) 2015 Rohan Garg <rohan@garg.io>
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'fileutils'

require_relative '../kci'

module CI
  # Base class for sourcer implementations.
  class SourcerBase
    private

    def initialize(release:, strip_symbols:, restricted_packaging_copy:)
      @release = release # e.g. vivid
      @strip_symbols = strip_symbols
      @restricted_packaging_copy = restricted_packaging_copy

      # vcs
      @packaging_dir = File.absolute_path('packaging').freeze
      # orig
      @packagingdir = @packaging_dir.freeze

      # vcs
      @build_dir = "#{Dir.pwd}/build".freeze
      # orig
      @builddir = @build_dir.freeze
      FileUtils.rm_r(@build_dir) if Dir.exist?(@build_dir)
      Dir.mkdir(@build_dir)

      # vcs
      # TODO:
      # orig
      @sourcepath = "#{@builddir}/source" # Created by extract.
    end

    def mangle_symbols
      # Rip out symbol files unless we are on latest
      if @strip_symbols || @release != KCI.latest_series
        symbols = Dir.glob('debian/symbols') +
                  Dir.glob('debian/*.symbols') +
                  Dir.glob('debian/*.symbols.*')
        symbols.each { |s| FileUtils.rm(s) }
      end
    end

    def substvars!(version)
      Dir.glob('debian/*') do |path|
        next unless File.file?(path)
        data = File.read(path)
        File.write(path, data)
      end
    end

    def create_changelog_entry(version, message = 'Automatic CI Build')
      dch = [
        'dch',
        '--force-bad-version',
        '--distribution', @release,
        '--newversion', version,
        message
      ]
      # dch cannot actually fail because we parse the changelog beforehand
      # so it is of acceptable format here already.
      raise 'Failed to create changelog entry' unless system(*dch)
      substvars!(version)
    end

    def dpkg_buildpackage
      system('update-maintainer')
      args = [
        'dpkg-buildpackage',
        '-us', '-uc', # Do not sign .dsc / .changes
        '-S', # Only build source
        '-d' # Do not enforce build-depends
      ]
      raise 'Could not run dpkg-buildpackage!' unless system(*args)
    end
  end
end
