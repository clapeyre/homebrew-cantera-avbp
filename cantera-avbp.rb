class CanteraAvbp < Formula
  homepage 'http://cerfacs.fr/cantera/'
  url "http://cerfacs.fr/cantera/cantera211.tar.gz"
  sha1 "d0368bf224acbb67235952f7fcd81f71514fe242"

  option "with-matlab=", "Path to Matlab root directory"
  option "without-check", "Disable build-time checking (not recommended)"

  depends_on :python if MacOS.version <= :snow_leopard
  depends_on "scons" => :build
  depends_on "numpy" => :python
  depends_on "cython" => :python
  depends_on "sundials" => :recommended
  depends_on :python3 => :optional
  depends_on "graphviz" => :optional

  # Fix build on mac
  patch :DATA

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

__END__
diff --git a/.gitignore b/.gitignore
index f01b81e..0adc010 100644
--- a/.gitignore
+++ b/.gitignore
@@ -12,7 +12,6 @@ interfaces/matlab/ctpath.m
 stage/
 .sconsign.dblite
 .sconf_temp
-cantera.conf*
 config.log
 *.lib
 *.exp
diff --git a/SConstruct b/SConstruct
index 13b8600..dab745f 100644
--- a/SConstruct
+++ b/SConstruct
@@ -533,6 +533,10 @@ config_options = [
         'Location of the Boost header files',
         defaults.boostIncDir, PathVariable.PathAccept),
     PathVariable(
+        'gfortran_lib_dir',
+        'Directory containing the gfortran library',
+        defaults.boostLibDir, PathVariable.PathAccept),
+    PathVariable(
         'boost_lib_dir',
         'Directory containing the Boost.Thread library',
         defaults.boostLibDir, PathVariable.PathAccept),
diff --git a/interfaces/cython/SConscript b/interfaces/cython/SConscript
index 768524e..42fa302 100644
--- a/interfaces/cython/SConscript
+++ b/interfaces/cython/SConscript
@@ -106,8 +106,11 @@ def install_module(prefix, python_version):
 
 
 libDirs = ('../../build/lib', localenv['sundials_libdir'],
-           localenv['blas_lapack_dir'], localenv['boost_lib_dir'])
-localenv['py_cantera_libs'] = repr(localenv['cantera_libs'])
+           localenv['blas_lapack_dir'], localenv['boost_lib_dir'], localenv['gfortran_lib_dir'])
+#ORIlocalenv['py_cantera_libs'] = repr(localenv['cantera_libs'])
+CantLibs = localenv['cantera_libs']
+CantLibs.extend(localenv['FORTRANSYSLIBS'])
+localenv['py_cantera_libs'] = repr([x for x in CantLibs  if x])
 localenv['py_libdirs'] = repr([x for x in libDirs if x])
 
 # Compile the Python module with the same compiler as the rest of Cantera,
diff --git a/src/SConscript b/src/SConscript
index 8000a30..72b7c32 100644
--- a/src/SConscript
+++ b/src/SConscript
@@ -80,7 +80,8 @@ if localenv['layout'] != 'debian':
                                        SPAWN=getSpawn(localenv)))
     install('$inst_libdir', lib)
     env['cantera_shlib'] = lib
-    localenv.Append(LIBS='gfortran',
-                        LIBPATH='/usr/lib64')
+#    localenv.Append(LIBS='gfortran',
+#                        LIBPATH='/usr/lib64')
+    localenv.Append(LIBS=localenv['FORTRANSYSLIBS'],LIBPATH=localenv['gfortran_lib_dir'])
 
     localenv.Depends(lib, localenv['config_h_target'])
