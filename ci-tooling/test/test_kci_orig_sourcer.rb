require 'vcr'
require 'webmock/test_unit'

require_relative 'lib/serve'
require_relative 'lib/testcase'

require_relative '../kci/orig_sourcer.rb'

module KCI
  class OrigSourcerTestCase < TestCase
    SERVE_PORT = '9474'.freeze

    def setup
      # For unknown reasons we require VCR for our in-process connections as
      # otherwise VCR and/or webmock will fall over dead or funnier yet,
      # connection errors will be raised for no apparent reason.
      VCR.configure do |config|
        config.cassette_library_dir = @datadir
        config.hook_into :webmock
        config.default_cassette_options = {
          match_requests_on: [:method, :uri, :body]
        }
      end
    end

    def test_tarball # also tests watch
      require_binaries('uscan')
      FileUtils.cp_r(Dir.glob("#{data}/*"), Dir.pwd)
      Test.http_serve(data('http'), port: SERVE_PORT) do
        tarball = KCI::OrigSourcer.tarball
        assert_not_equal(nil, tarball)
        assert_equal('dragon_15.08.1.orig.tar.xz', File.basename(tarball.path))
      end
    end

    def test_tarball_fail
      assert_raise RuntimeError do
        KCI::OrigSourcer.tarball
      end
    end

    def test_lookup
      Dir.mkdir('source')
      File.write('source/foo_1.orig.tar.gz', '')
      tarball = KCI::OrigSourcer.tarball
      assert_not_equal(nil, tarball)
      assert_equal('foo_1.orig.tar.gz', File.basename(tarball.path))
    end

    def test_url
      Dir.mkdir('source')
      File.write('source/url',
                 "http://localhost:#{SERVE_PORT}/dragon-15.08.1.tar.xz\n")
      Test.http_serve(data, port: SERVE_PORT) do
        VCR.use_cassette(__method__) do
          tarball = KCI::OrigSourcer.tarball
          assert_not_equal(nil, tarball)
          assert_equal('dragon_15.08.1.orig.tar.xz',
                       File.basename(tarball.path))
        end
      end
    end
  end
end
