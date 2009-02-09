#! /bin/sh
#
#  Shell script to create a Windows binary distribution. This will
#  compile the DLL files using MSVC or Cygwin, generate the batch file and
#  associated helpers needed for end users to build the example programs,
#  and finally zip up the results.
#
#  Note! If you use Cygwin to generate the DLLs make sure you have set up
#  your MINGDIR and ALLEGRO_USE_CYGWIN environment variables correctly.
#
#  It should be run from the root of the Allegro directory, eg.
#  bash misc/zipwin.sh, so that it can find misc/vcvars.c and misc/askq.c.


# check we have a filename, and strip off the path and extension from it
if [ $# -ne 1 ]; then
   echo "Usage: zipwin <archive_name>" 1>&2
   exit 1
fi

name=$(echo "$1" | sed -e 's/.*[\\\/]//; s/\.zip//')


# check that MSVC or Cygwin is available
if [ "$ALLEGRO_USE_CYGWIN" = "1" ]; then
   if [ "$MINGDIR" = "" ]; then
      echo "You need to set up Cygwin before running this script" 1>&2
      exit 1
   fi
else
   if [ "$MSVCDIR" = "" ]; then
      echo "You need to set up MSVC (run vcvars32.bat) before running this script" 1>&2
      exit 1
   fi
fi


# check that we are in the Allegro dir
if [ ! -f include/allegro5/allegro5.h ]; then
   echo "Oops, you don't appear to be in the root of the Allegro directory" 1>&2
   exit 1
fi


# convert Allegro to MSVC or Cygwin format
if [ "$ALLEGRO_USE_CYGWIN" = "1" ]; then
   ./fix.sh mingw --dtou
else
   ./fix.sh msvc --utod
fi


# delete all generated files
echo "Cleaning the Allegro tree..."
make.exe -s veryclean


# generate DLL export definition files
misc/fixdll.sh


# generate dependencies
echo "Generating dependencies..."
make.exe depend


# build all three libs
make.exe lib
make.exe lib DEBUGMODE=1
make.exe lib PROFILEMODE=1


# find what library version (DLL filename) the batch file should build
ver=`sed -n -e "s/LIBRARY_VERSION = \(.*\)/\1/p" makefile.ver`


# compile vcvars
echo "Compiling vcvars.exe..."
if [ "$ALLEGRO_USE_CYGWIN" = "1" ]; then
   gcc -Wl,--subsystem,console -o vcvars.exe misc/vcvars.c -ladvapi32
else
   cl -nologo misc/vcvars.c advapi32.lib
   rm vcvars.obj
fi


# compile askq
echo "Compiling askq.exe..."
if [ "$ALLEGRO_USE_CYGWIN" = "1" ]; then
   gcc -Wl,--subsystem,console -o askq.exe misc/askq.c
else
   cl -nologo misc/askq.c
   rm askq.obj
fi


# generate the setup code for msvcmake.bat (this bit checks for vcvars32,
# and builds the import libs)
echo "Generating msvcmake.bat..."

cat > msvcmake.bat << END_OF_BATCH
@echo off

rem Batch file for installing the precompiled Allegro DLL files,
rem and building the MSVC example and test programs.

rem Generated by misc/zipwin.sh

if not exist include\\allegro.h goto no_allegro

if not "%MSVCDIR%" == "" goto got_msvc

if "%VCVARS%" == "" goto no_vcvars

call "%VCVARS%"
goto got_msvc

:no_vcvars

echo MSVC environment variables not found: running vcvars.exe to look for them
vcvars.exe msvcmake.bat

goto the_end

:got_msvc

call fix.bat msvc --quick

echo Generating release mode import library
copy lib\\msvc\\allegro.def lib\\msvc\\alleg$ver.def > nul
lib /nologo /machine:ix86 /def:lib\\msvc\\alleg$ver.def /out:lib\\msvc\\alleg.lib

echo Generating debug mode import library
copy lib\\msvc\\allegro.def lib\\msvc\\alld$ver.def > nul
lib /nologo /machine:ix86 /def:lib\\msvc\\alld$ver.def /out:lib\\msvc\\alld.lib /debugtype:cv

echo Generating profile mode import library
copy lib\\msvc\\allegro.def lib\\msvc\\allp$ver.def > nul
lib /nologo /machine:ix86 /def:lib\\msvc\\allp$ver.def /out:lib\\msvc\\allp.lib

echo Compiling test and example programs
END_OF_BATCH


# If running Cygwin, we need to do some trickery
if [ "$ALLEGRO_USE_CYGWIN" = "1" ]; then
   ./fix.sh msvc --utod
   export MSVCDIR="MSVCDIR"
   make.exe depend UNIX_TOOLS=1

   echo "Fooling the MSVC makefile ..."
   cp lib/mingw32/*.dll lib/msvc/
   make.exe -t lib
fi


# SED script for converting make -n output into a funky batch file
cat > _fix1.sed << END_OF_SED

# remove any echo messages from the make output
/^echo/d

# strip out references to runner.exe
s/obj\/msvc\/runner.exe //

# turn program name slashes into DOS format
s/\\//\\\\/g

# make sure were are using command.com copy, rather than cp
s/^.*cat tools.*msvc.plugins.h/copy \/B tools\\\\plugins\\\\*.inc tools\\\\plugins\\\\plugins.h/

# add blank lines, to make the batch output more readable
s/^\([^@]*\)$/\\
\1/

# turn any @ argfile references into an echo+tmpfile sequence
s/\(.*\) @ \(.*\)/\\
echo \2 > _tmp.arg\\
\1 @_tmp.arg\\
del _tmp.arg/

END_OF_SED


# second SED script, for splitting long echos into multiple segments
cat > _fix2.sed << END_OF_SED

s/echo \(................................................[^ ]*\) \(........*\) \(>>*\) _tmp\.arg/echo \1 \3 _tmp.arg\\
echo \2 >> _tmp.arg/

END_OF_SED


# run make -n, to see what commands are needed for building this thing
echo "Running make -n, to generate the command list..."

make.exe -n | \
   sed -f _fix1.sed | \
   sed -f _fix2.sed | \
   sed -f _fix2.sed | \
   sed -f _fix2.sed | \
   sed -f _fix2.sed | \
   sed -f _fix2.sed | \
   sed -f _fix2.sed | \
   sed -f _fix2.sed | \
   sed -f _fix2.sed \
      >> msvcmake.bat

rm _fix1.sed _fix2.sed

if [ "$ALLEGRO_USE_CYGWIN" = "1" ]; then
   unset MSVCDIR
fi

# finish writing msvcmake.bat (this bit asks whether to install the headers,
# libs, and DLL files)
cat >> msvcmake.bat << END_OF_BATCH
askq.exe Would you like to copy the headers and libs to your MSVC directories
if errorlevel 1 goto no_lib_copy

if not "%MSVCDIR%" == "" set _VC_DIR_=%MSVCDIR%

echo Copying libraries
copy lib\\msvc\\*.lib "%_VC_DIR_%\\lib"

echo Copying allegro.h
copy include\\allegro.h "%_VC_DIR_%\\include"

echo Copying winalleg.h
copy include\\winalleg.h "%_VC_DIR_%\\include"

echo Copying module headers
md "%_VC_DIR_%\\include\\allegro"
copy include\\allegro\\*.h "%_VC_DIR_%\\include\\allegro"

echo Copying inline headers
md "%_VC_DIR_%\\include\\allegro\\inline"
copy include\\allegro\\inline\\*.inl "%_VC_DIR_%\\include\\allegro\\inline"

echo Copying internal headers
md "%_VC_DIR_%\\include\\allegro\\internal"
copy include\\allegro\\internal\\*.h "%_VC_DIR_%\\include\\allegro\\internal"

echo Copying platform headers
md "%_VC_DIR_%\\include\\allegro\\platform"
copy include\\allegro\\platform\\aintwin.h "%_VC_DIR_%\\include\\allegro\\platform"
copy include\\allegro\\platform\\al386vc.h "%_VC_DIR_%\\include\\allegro\\platform"
copy include\\allegro\\platform\\almsvc.h "%_VC_DIR_%\\include\\allegro\\platform"
copy include\\allegro\\platform\\alplatf.h "%_VC_DIR_%\\include\\allegro\\platform"
copy include\\allegro\\platform\\alwin.h "%_VC_DIR_%\\include\\allegro\\platform"

set _VC_DIR_=

goto lib_copy_done

:no_lib_copy
echo Library and header files were not installed.
echo You can find the headers in the allegro\\include directory,
echo and the libs in allegro\\lib\\msvc\\

:lib_copy_done

askq.exe Would you like to copy the DLL files to your Windows system directory
if errorlevel 1 goto no_dll_copy

if "%OS%" == "Windows_NT" set _WIN_DIR_=%SYSTEMROOT%\\system32
if "%OS%" == "" set _WIN_DIR_=%windir%\\system

echo Copying DLL files to %_WIN_DIR_%
copy lib\\msvc\\*.dll %_WIN_DIR_%

set _WIN_DIR_=

goto dll_copy_done

:no_dll_copy
echo DLL files were not installed.
echo You can find them in allegro\\lib\\msvc\\

:dll_copy_done

echo.
echo All done: Allegro is now installed on your system!

goto the_end

:no_allegro

echo Can't find the Allegro library source files! To install this binary
echo distribution, you must also have a copy of the library sources, so
echo that I can compile the support programs and convert the documentation.

:the_end

END_OF_BATCH


# generate the readme
cat > $name.txt << END_OF_README
     ______   ___    ___
    /\\  _  \\ /\\_ \\  /\\_ \\
    \\ \\ \\L\\ \\\\//\\ \\ \\//\\ \\      __     __   _ __   ___ 
     \\ \\  __ \\ \\ \\ \\  \\ \\ \\   /'__\`\\ /'_ \`\\/\\\`'__\\/ __\`\\
      \\ \\ \\/\\ \\ \\_\\ \\_ \\_\\ \\_/\\  __//\\ \\L\\ \\ \\ \\//\\ \\L\\ \\
       \\ \\_\\ \\_\\/\\____\\/\\____\\ \\____\\ \\____ \\ \\_\\\\ \\____/
	\\/_/\\/_/\\/____/\\/____/\\/____/\\/___L\\ \\/_/ \\/___/
				       /\\____/
				       \\_/__/


		 Windows binary distribution.



This package contains precompiled copies of the Windows DLL files for the 
Allegro library, to save you having to compile it yourself. This is not a 
complete distribution of Allegro, as it does not contain any of the 
documentation, example programs, headers, etc. You need to download the full 
source version, and then just unzip this package over the top of it.

To install, run the batch file msvcmake.bat, either from a command prompt or 
by double-clicking on it from the Windows explorer. This will hopefully be 
able to autodetect all the details of where to find your compiler, and will 
automatically compile the various support programs that come with Allegro.

At the end of the install process you will be asked whether to copy libs and 
headers into your compiler directories, and whether to install the DLL files 
into the Windows system directory. You should normally say yes here, but if 
you prefer, you can leave these files in the Allegro directory, and then 
specify the paths to them later on, when you come to compile your own 
programs using Allegro.

There are three versions of the DLL included in this zip:

   alleg$ver.dll is the normal optimised version
   alld$ver.dll is the debugging build, and should be used during development
   allp$ver.dll is a profiling build, for collecting performance info

For more general information about using Allegro, see the readme.txt and 
docs/build/msvc.txt files from the source distribution.

END_OF_README


# build the main zip archive
echo "Creating $name.zip..."
cd ..
if [ -f $name.zip ]; then rm $name.zip; fi

if [ "$ALLEGRO_USE_CYGWIN" = "1" ]; then
   unix2dos allegro/$name.txt
   unix2dos allegro/msvcmake.bat
fi

zip -9 $name.zip allegro/$name.txt allegro/msvcmake.bat allegro/vcvars.exe allegro/askq.exe allegro/lib/msvc/*.dll


# clean up after ourselves
cd allegro
rm $name.txt msvcmake.bat vcvars.exe askq.exe


echo "Done!"
