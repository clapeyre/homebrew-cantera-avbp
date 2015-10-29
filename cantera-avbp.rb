class CanteraAVBP < Formula
  homepage 'http://cerfacs.fr/cantera/'
  url "http://cerfacs.fr/cantera/cantera211.tar.gz"
  sha1 "9153dde34d0226f0f4445a4a817d77a16caa89f5"

  option "with-matlab=", "Path to Matlab root directory"
  option "without-check", "Disable build-time checking (not recommended)"

  depends_on :python if MacOS.version <= :snow_leopard
  depends_on "scons" => :build
  depends_on "numpy" => :python
  depends_on "cython" => :python
  depends_on "sundials" => :recommended
  depends_on :python3 => :optional
  depends_on "graphviz" => :optional

  def install
    # Make sure to use Homebrew Python to do CTI to CTML conversions
    inreplace "src/base/ct2ctml.cpp", 's = "python";', 's = "/usr/local/bin/python";'

    build_args = ["prefix=#{prefix}",
                  "python_package=new",
                  "CC=#{ENV.cc}",
                  "CXX=#{ENV.cxx}",
                  "f90_interface=n"]

    matlab_path = ARGV.value("with-matlab")
    build_args << "matlab_path=" + matlab_path if matlab_path
    build_args << "python3_package=y" if build.with? :python3

    # This is needed to make sure both the main code and the Python module use
    # the same C++ standard library. Can be removed for Cantera 2.2.x
    if MacOS.version >= :mavericks and not build.head?
      ENV.libcxx
      build_args << "python_compiler=#{ENV.cxx}"
    end

    scons "build", *build_args
    scons "test" if build.with? "check"
    scons "install"
    prefix.install Dir["License.*"]
  end

  test do
    # Run those portions of the test suite that do not depend of data
    # that's only available in the source tree.
    system("python", "-m", "unittest", "-v",
           "cantera.test.test_thermo",
           "cantera.test.test_kinetics",
           "cantera.test.test_transport",
           "cantera.test.test_purefluid",
           "cantera.test.test_mixture")
  end

  def caveats; <<-EOS.undent
    The license, demos, tutorials, data, etc. can be found in:
      #{opt_prefix}

    Try the following in python to find the equilibrium composition of a
    stoichiometric methane/air mixture at 1000 K and 1 atm:
    >>> import cantera as ct
    >>> g = ct.Solution('gri30.cti')
    >>> g.TPX = 1000, ct.one_atm, 'CH4:1, O2:2, N2:8'
    >>> g.equilibrate('TP')
    >>> g()
    EOS
  end
end
