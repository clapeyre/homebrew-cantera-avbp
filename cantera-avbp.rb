class CanteraAvbp < Formula
  homepage 'http://cerfacs.fr/cantera/'
  url "http://cerfacs.fr/cantera/cantera211.tar.gz"
  #sha1 "9515a6447d962317544b8e9bae28c6b3aa9a721f"

  option "with-matlab=", "Path to Matlab root directory"
  option "without-check", "Disable build-time checking (not recommended)"

  depends_on "python"
  depends_on "open-mpi"
  depends_on "scons" => :build
  depends_on "gcc" => :build
  depends_on "numpy" => :python
  depends_on "cython" => :python
  depends_on "homebrew/science/sundials" => :recommended
  depends_on :python3 => :optional
  depends_on "graphviz" => :optional

  # Fix build on mac
  patch :DATA

  def install
    # Make sure to use Homebrew Python to do CTI to CTML conversions
    inreplace "src/base/ct2ctml.cpp", 's = "python";', 's = "/usr/local/bin/python";'

    build_args = ["prefix=#{prefix}",
                  "gfortran_lib_dir=#{Formula.factory('gcc').lib}/gcc/5"]

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
diff --git a/site_scons/buildutils.py b/site_scons/buildutils.py
index 1676e47..a8c8a6f 100644
--- a/site_scons/buildutils.py
+++ b/site_scons/buildutils.py
@@ -302,7 +302,10 @@ def compareCsvFiles(env, file1, file2):
     """
     try:
         import numpy as np
-        hasSkipHeader = tuple(np.version.version.split('.')[:2]) >= ('1','4')
+        hasSkipHeader = [int(n) for n in np.version.version.split('.')[:2]] >= [int(n) for n in ('1','4')]
+        print (int(n) for n in np.version.version.split('.')[:2])
+        print (int(n) for n in ('1','4'))
+        print hasSkipHeader
     except ImportError:
         print 'WARNING: skipping .csv diff because numpy is not installed'
         return 0
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
diff --git a/test_problems/SConscript b/test_problems/SConscript
index 0e27b86..d7a1df5 100644
--- a/test_problems/SConscript
+++ b/test_problems/SConscript
@@ -4,6 +4,7 @@ Import('env','build','install')
 localenv = env.Clone()
 localenv.Prepend(CPPPATH=['#include', '#src', 'shared'])
 localenv.Append(CCFLAGS=env['warning_flags'])
+localenv.Append(LIBPATH=localenv['gfortran_lib_dir'])
 
 os.environ['PYTHONPATH'] = pjoin(os.getcwd(), '..', 'interfaces', 'python')
 os.environ['CANTERA_DATA'] = pjoin(os.getcwd(), '..', 'build', 'data')
@@ -106,7 +107,7 @@ class CompileAndTest(Test):
     def run(self, env):
         prog = env.Program(pjoin(self.subdir, self.programName),
                            mglob(env, self.subdir, *self.extensions),
-                           LIBS=env['cantera_libs'])
+                           LIBS=localenv['FORTRANSYSLIBS'] +env['cantera_libs'])
         source = [prog]
         return Test.run(self, env, *source)
 
