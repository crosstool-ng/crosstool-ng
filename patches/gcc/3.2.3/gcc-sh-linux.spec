Summary: The GNU Compiler Collection for SuperH.
%define GCC_VERSION 3.2.3
%define arch_list sh3-linux sh3eb-linux sh4-linux sh4eb-linux
%define TARGET_LIBSTDC 1
%define TARGET_JAVA 1

Name: gcc
Version: 3.2.3
Release: 3

Copyright: GPL
Group: Development/Languages
Source0: gcc-%{GCC_VERSION}.tar.bz2
Patch1: gcc-20030210-sh-linux-1.patch
Patch2: gcc-3.2.3-libffi-1.patch
Patch3: gcc-3.2.3-sh-linux-dwarf2-1.patch
Buildroot: /var/tmp/gcc-%{_target}-root
ExclusiveArch: i386 sh3 sh3eb sh4 sh4eb

%description
This package contains the GNU Compiler Collection: gcc and g++.
You'll need this package in order to compile C/C++ code.

%ifarch i386

# ==================== Cross Compiler ===============================

%package sh-linux
Summary: The GNU Compiler Collection for sh-linux.
Group: Development/Languages
Requires: binutils-sh-linux >= 2.13.2
Provides: gcc-sh-linux
Obsoletes: gcc-sh3-linux gcc-sh3eb-linux gcc-sh4-linux gcc-sh4eb-linux
Obsoletes: gcc-sh3-linux-c++ gcc-sh3eb-linux-c++ gcc-sh4-linux-c++ gcc-sh4eb-linux-c++
Obsoletes: libstdc++-sh3-linux libstdc++-sh3eb-linux libstdc++-sh4-linux libstdc++-sh4eb-linux
AutoReqProv: no

%description sh-linux
The gcc-sh-linux package contains GNU Compiler Collection: gcc g++ and libstdc++-v3.

It includes support for most of the current C++ specification, including templates and
exception handling. It does also include the standard C++ library and C++ header files.
You'll need this package in order to cross compile C/C++ code for sh-linux.

%package -n libgcj-sh-linux
Summary: Header files and libraries for sh-linux Java development.
Group: Development/Libraries
Requires: gcc-sh-linux = %{version}-%{release}
AutoReqProv: no

%description -n libgcj-sh-linux
The Java static libraries and C header files. You will need this
package to compile your Java programs for sh-linux using the gcc Java compiler (gcj).

%else
# =========================== Native Compiler =================================
%package libgcc
Summary: runtime libraries for the GNU Compiler Collection.
Group: System Environment/Libraries

%description libgcc
This package contains libgcc shared libraries for the GNU C Compiler Collection.
You'll need this package in order to execute C,C++,JAVA code
that uses shared libgcc.

%package c++
Summary: C++ support for gcc
Group: Development/Languages
Requires: gcc = %{version}-%{release}

%description c++
This package adds C++ support to the GNU Compiler Collection. It includes
support for most of the current C++ specification, including templates and
exception handling. It does include the static standard C++
library and C++ header files; the library for dynamically linking
programs is available separately.

%package -n libstdc++
Summary: GNU c++ library.
Group: System Environment/Libraries

%description -n libstdc++
The libstdc++ package contains a snapshot of the GCC Standard C++
Library v3, an ongoing project to implement the ISO 14882 Standard C++
library.

%package -n libstdc++-devel
Summary: Header files and libraries for C++ development
Group: Development/Libraries
Requires: libstdc++ = %{version}-%{release}, gcc-c++ = %{version}-%{release}

%description -n libstdc++-devel
This is the GNU implementation of the standard C++ libraries.  This
package includes the header files and libraries needed for C++
development. This includes SGI's implementation of the STL.

%package java
Summary: Java support for gcc
Group: Development/Languages
Requires: gcc = %{version}-%{release}, libgcj = %{version}-%{release}, libgcj-devel = %{version}-%{release}

%description java
This package adds experimental support for compiling Java(tm) programs and
bytecode into native code. To use this you will also need the libgcj and
libgcj-devel packages.

%package -n libgcj
Summary: Java runtime library for gcc.
Group: System Environment/Libraries

%description -n libgcj
The Java runtime library. You will need this package to run your Java
programs compiled using the gcc Java compiler (gcj).

%package -n libgcj-devel
Summary: Header files and libraries for Java development.
Group: Development/Libraries
Requires: libgcj = %{version}-%{release}

%description -n libgcj-devel
The Java static libraries and C header files. You will need this
package to compile your Java programs using the gcc Java compiler (gcj).

%endif

%prep
%setup -q -n gcc-%{GCC_VERSION}
%patch1 -p1
%patch2 -p1
##%patch3 -p1

%build
%ifarch i386
# build cross compiler for i386-linux host
for arch in sh-linux; do
  rm -rf ${arch}
  mkdir ${arch}

  CONFIG_ARGS="\
        --prefix=%{_prefix} \
        --mandir=%{_mandir} \
        --infodir=%{_infodir} \
        --target=${arch} \
        --host=%{_host} \
        --build=%{_build} \
        --enable-languages=c,c++,java \
        --with-system-zlib \
        --with-gxx-include-dir=%{_prefix}/${arch}/include/g++-v3 \
        --includedir=%{_prefix}/${arch}/include \
	--disable-checking \
	--disable-shared \
	--enable-__cxa_atexit \
	--enable-c99 \
        --enable-threads=posix \
        --enable-long-long"
  if [ %{TARGET_JAVA} -ne 0 ]; then
    CONFIG_ARGS="$CONFIG_ARGS --enable-libgcj"
  fi
  (  cd $arch
     ../configure ${CONFIG_ARGS}
  )
  if [ %{TARGET_LIBSTDC} -ne 0 -o %{TARGET_JAVA} -ne 0 ]; then
    sed -e s:-Dinhibit_libc::g ${arch}/gcc/Makefile >${arch}/gcc/Makefile.$$$
    mv -f ${arch}/gcc/Makefile.$$$ ${arch}/gcc/Makefile
  fi
  make all-gcc -C ${arch}

  if [ %{TARGET_LIBSTDC} -ne 0 ]; then
    CONFIG_ARGS="`echo $CONFIG_ARGS | sed -e s/--disable-shared/--enable-shared/`"
    make TARGET_CONFIGARGS="${CONFIG_ARGS} --with-cross-host" all-target-libstdc++-v3 -C ${arch}
  fi

  if [ %{TARGET_JAVA} -ne 0 ]; then
    make all-fastjar -C ${arch}
    CONFIG_ARGS="`echo $CONFIG_ARGS | sed -e s/--host=%{_host}/--host=${arch}/`"
    dir=`pwd`

    ac_cv_file__proc_self_exe=yes \
    ac_cv_prog_GCJ="$dir/$arch/gcc/gcj -B$dir/$arch/$arch/libjava/ -B$dir/$arch/gcc/ -B%{_prefix}/$arch/bin/ -B%{_prefix}/$arch/lib/ -isystem %{_prefix}/$arch/include" \
      make TARGET_CONFIGARGS="${CONFIG_ARGS} --with-cross-host --enable-multilib --with-target-subdir=${arch} --with-x=no" \
      all-target-libjava -C ${arch}
  fi

%else
# Canadian cross (build native compiler)
for arch in %{_target}; do
  rm -rf ${arch}
  mkdir -p ${arch}
  CONFIG_ARGS="\
        --prefix=%{_prefix} \
        --mandir=%{_mandir} \
        --infodir=%{_infodir} \
        --target=${arch} \
        --host=${arch} \
        --build=%{_build} \
        --enable-languages=c,c++,java \
        --with-system-zlib \
        --with-gxx-include-dir=%{_prefix}/include/g++-v3 \
	--disable-checking \
	--disable-shared \
	--enable-__cxa_atexit \
	--enable-c99 \
        --enable-threads=posix \
        --enable-long-long"

  if [ %{TARGET_JAVA} -ne 0 ]; then
    CONFIG_ARGS="$CONFIG_ARGS --enable-libgcj"
  fi

  (  cd ${arch}
     CC=${arch}-gcc AR=${arch}-ar RANLIB=${arch}-ranlib CXX=${arch}-g++ \
        ../configure $CONFIG_ARGS
  )

  if [ %{TARGET_LIBSTDC} -ne 0 -o %{TARGET_JAVA} -ne 0 ]; then
    sed -e s:-Dinhibit_libc::g ${arch}/gcc/Makefile >${arch}/gcc/Makefile.$$$
    mv -f ${arch}/gcc/Makefile.$$$ ${arch}/gcc/Makefile
  fi

  make all-build-libiberty all-gcc -C ${arch}

  if [ %{TARGET_LIBSTDC} -ne 0 ]; then
    CONFIG_ARGS="`echo $CONFIG_ARGS | sed -e s/--disable-shared/--enable-shared/`"
    make TARGET_CONFIGARGS="${CONFIG_ARGS}" all-target-libstdc++-v3 -C ${arch}
    if [ %{TARGET_JAVA} -ne 0 ]; then
      ( mkdir -p ${arch}/fastjar; cd ${arch}/fastjar; rm *; ../../fastjar/configure --with-system-zlib; make )
      ac_cv_file__proc_self_exe=yes \
        CC=${arch}-gcc AR=${arch}-ar RANLIB=${arch}-ranlib CXX=${arch}-g++ GCJ=${arch}-gcj \
        make TARGET_CONFIGARGS="${CONFIG_ARGS} --with-x=no" configure-target-libjava -C ${arch}

        make -C ${arch}/${arch}/libffi
        make -C ${arch}/${arch}/boehm-gc
        make -C ${arch}/${arch}/zlib
        make GCJ=${arch}-gcj GCJH=${arch}-gcjh ZIP=${arch}-jar -C ${arch}/${arch}/libjava
      (
        rm -rf ${arch}/${arch}/fastjar
        mkdir -p ${arch}/${arch}/fastjar
        cd ${arch}/${arch}/fastjar

        ac_cv_sizeof_char=1 \
        ac_cv_sizeof_short=2 \
        ac_cv_sizeof_int=4 \
        ac_cv_sizeof_long=4 \
        ac_cv_sizeof_long_long=8 \
        ac_cv_sizeof_float=4 \
        ac_cv_sizeof_double=8 \
        ac_cv_sizeof_long_double=8 \
        ac_cv_sizeof_void_p=4 \
        ac_cv_file__proc_self_exe=yes \
        ac_cv_header_langinfo_h=yes \
        CC=${arch}-gcc ../../../fastjar/configure $CONFIG_ARGS

        make
      )

    fi
  fi
%endif
done

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p ${RPM_BUILD_ROOT}/{%{_prefix}/bin,lib}

%ifarch i386
  ARCH_STRTIP=strip
  EXESUFFIX=""
  arch=sh-linux
  TOOLPREFIX=${arch}-
  mkdir -p ${RPM_BUILD_ROOT}%{_prefix}/${arch}/{bin,include,lib,share}
  mkdir -p ${RPM_BUILD_ROOT}%{_prefix}/${arch}/lib/{m4,mb/m4}
  make DESTDIR=${RPM_BUILD_ROOT} \
	install-gcc \
	install-fastjar \
	-C ${arch}
%if 0
  ( cd ${RPM_BUILD_ROOT}%{_prefix}/sh-linux/lib
    rm -f libgcc_s_*.so
    mv libgcc_s_mb.so.1 mb/libgcc_s.so.1
    mv libgcc_s_m4.so.1 m4/libgcc_s.so.1
    mv libgcc_s_mb_m4.so.1 mb/m4/libgcc_s.so.1
    ln -s libgcc_s.so.1 mb/libgcc_s.so
    ln -s libgcc_s.so.1 m4/libgcc_s.so
    ln -s libgcc_s.so.1 mb/m4/libgcc_s.so
  )
%endif

  if [ %{TARGET_LIBSTDC} -ne 0 ]; then
    make DESTDIR=${RPM_BUILD_ROOT} \
      install-target-libstdc++-v3 \
      -C ${arch}
  fi
  if [ %{TARGET_JAVA} -ne 0 ]; then
    make DESTDIR=${RPM_BUILD_ROOT} \
      install-target-libjava \
      install-target-boehm-gc \
      install-target-zlib \
      -C ${arch}
    make DESTDIR=${RPM_BUILD_ROOT} prefix=%{_prefix}/${arch} \
      install -C ${arch}/${arch}/libffi
    mv -f $RPM_BUILD_ROOT%{_prefix}/share/java $RPM_BUILD_ROOT%{_prefix}/sh-linux/share/
  fi
  rm -f $RPM_BUILD_ROOT%{_prefix}/bin/{gcov,gccbug}
  rm -f $RPM_BUILD_ROOT%{_prefix}/${arch}/bin/{gij,jv-convert}
  sed -e 's/@@VERSION@@/%{GCC_VERSION}/g' debian/shCPU-linux-GCC >$RPM_BUILD_ROOT%{_prefix}/bin/shCPU-linux-GCC
  chmod 0755 $RPM_BUILD_ROOT%{_prefix}/bin/shCPU-linux-GCC

  LIBSTDC=`cd $RPM_BUILD_ROOT%{_prefix}/sh-linux/lib; echo libstdc++.so*`
  LIBGCJ=`cd $RPM_BUILD_ROOT%{_prefix}/sh-linux/lib; echo libgcj.so*`
  LIBFFI=`cd $RPM_BUILD_ROOT%{_prefix}/sh-linux/lib; echo libffi*.so*`
  # literally (binary-ly) same
  PROGS="cpp c++ g++ g77 gcc gcj"
  DRIVERS="cc1 cc1obj cc1plus collect2 cpp0 f771 jc1 tradcpp0 jvgenmain"
  OBJS="crtbegin.o crtbeginS.o crtend.o crtendS.o crtbeginT.o"
  LIBS="libgcc.a libgcc_eh.a libobjc.a"
  LIBS_1="$LIBSTDC \
          $LIBGCJ libgcj.spec \
          $LIBFFI "
  LIBS_2="libstdc++.a libstdc++.la \
	  libsupc++.a libsupc++.la \
	  libgcj.a libgcj.la \
          libffi.a libffi.la"
  INCLUDE="include"

  for CPU in sh3 sh3eb sh4 sh4eb; do
    mkdir -p ${RPM_BUILD_ROOT}%{_prefix}/lib/gcc-lib/${CPU}-linux/%{GCC_VERSION}
    mkdir -p ${RPM_BUILD_ROOT}%{_prefix}/${CPU}-linux/{lib,share/java}
    # Make symbolic links for include dir.
    ln -s ../sh-linux/include $RPM_BUILD_ROOT%{_prefix}/${CPU}-linux/include

    # Make symbolic links for libgcj.jar
    ln -s ../../sh-linux/share/java/libgcj-%{GCC_VERSION}.jar $RPM_BUILD_ROOT%{_prefix}/${CPU}-linux/share/java/libgcj-%{GCC_VERSION}.jar

    # Make symbolic links for executables.
    for p in ${PROGS}; do
      ln -s shCPU-linux-GCC $RPM_BUILD_ROOT%{_prefix}/bin/${CPU}-linux-$p
    done
    ln -s sh-linux-gcjh $RPM_BUILD_ROOT%{_prefix}/bin/${CPU}-linux-gcjh

    case "${CPU}" in
        sh3)
	    MULTILIBDIR=
	    MULTIPARENTDIR=
	    AS_ENDIAN_FLAG="-little"
	    CPP_ENDIAN_DEF="-D__LITTLE_ENDIAN__"
	    CPP_CPU_DEFS='-D__SH3__ -D__sh3__'
	    CC1_CPU_ENDIAN_FLAGS="-ml -m3"
	    CC1PLUS_CPU_ENDIAN_FLAGS="-ml -m3"
	    LINKER_CPU_ENDIAN_FLAGS="-m shlelf_linux -EL --architecture sh3"
	    LINKER_RPATH_LINK_FLAG="-rpath-link %{_prefix}/sh3-linux/lib"
        ;;
        sh3eb)
	    MULTILIBDIR=/mb
	    MULTIPARENTDIR=../
	    AS_ENDIAN_FLAG="-big"
	    CPP_ENDIAN_DEF="-D__BIG_ENDIAN__"
	    CPP_CPU_DEFS='-D__SH3__ -D__sh3__'
	    CC1_CPU_ENDIAN_FLAGS="-mb -m3"
	    CC1PLUS_CPU_ENDIAN_FLAGS="-mb -m3"
	    LINKER_CPU_ENDIAN_FLAGS="-m shelf_linux -EB --architecture sh3"
	    LINKER_RPATH_LINK_FLAG="-rpath-link %{_prefix}/sh3eb-linux/lib"
        ;;
        sh4)
	    MULTILIBDIR=/m4
	    MULTIPARENTDIR=../
	    AS_ENDIAN_FLAG="-little"
	    CPP_ENDIAN_DEF="-D__LITTLE_ENDIAN__"
	    CPP_CPU_DEFS="-D__SH4__"
	    CC1_CPU_ENDIAN_FLAGS="-ml -m4"
	    CC1PLUS_CPU_ENDIAN_FLAGS="-ml -m4"
	    LINKER_CPU_ENDIAN_FLAGS="-m shlelf_linux -EL --architecture sh4"
	    LINKER_RPATH_LINK_FLAG="-rpath-link %{_prefix}/sh4-linux/lib"
        ;;
        sh4eb)
	    MULTILIBDIR=/mb/m4
	    MULTIPARENTDIR=../../
	    AS_ENDIAN_FLAG="-big"
	    CPP_ENDIAN_DEF="-D__BIG_ENDIAN__"
	    CPP_CPU_DEFS="-D__SH4__"
	    CC1_CPU_ENDIAN_FLAGS="-mb -m4"
	    CC1PLUS_CPU_ENDIAN_FLAGS="-mb -m4"
	    LINKER_CPU_ENDIAN_FLAGS="-m shelf_linux -EB --architecture sh4"
	    LINKER_RPATH_LINK_FLAG="-rpath-link %{_prefix}/sh4eb-linux/lib"
        ;;
    esac

    # Make symbolic links for GCC drivers, objects, libraries, and include dir.
    for f in ${DRIVERS} ${INCLUDE}; do
       if [ -a $RPM_BUILD_ROOT%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/$f ]; then
         ln -s ../../sh-linux/%{GCC_VERSION}/$f $RPM_BUILD_ROOT%{_prefix}/lib/gcc-lib/${CPU}-linux/%{GCC_VERSION}/$f
       fi
    done
    for f in ${OBJS} ${LIBS}; do
       if [ -a $RPM_BUILD_ROOT%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}${MULTILIBDIR}/$f ]; then
         ln -s ../../sh-linux/%{GCC_VERSION}${MULTILIBDIR}/$f $RPM_BUILD_ROOT%{_prefix}/lib/gcc-lib/${CPU}-linux/%{GCC_VERSION}/$f
       fi
    done

    for f in ${LIBS_1} ${LIBS_2}; do
      if [ -e $RPM_BUILD_ROOT%{_prefix}/sh-linux/lib${MULTILIBDIR}/$f ]; then
        mv -f $RPM_BUILD_ROOT%{_prefix}/sh-linux/lib${MULTILIBDIR}/$f $RPM_BUILD_ROOT%{_prefix}/${CPU}-linux/lib
        ln -s ${MULTIPARENTDIR}../../${CPU}-linux/lib/$f $RPM_BUILD_ROOT%{_prefix}/sh-linux/lib${MULTILIBDIR}/$f
      fi
    done

    sed -e "s+@AS_ENDIAN_FLAG@+${AS_ENDIAN_FLAG}+" \
        -e "s+@CPP_ENDIAN_DEF@+${CPP_ENDIAN_DEF}+" \
        -e "s+@CPP_CPU_DEFS@+${CPP_CPU_DEFS}+" \
        -e "s+@CC1_CPU_ENDIAN_FLAGS@+${CC1_CPU_ENDIAN_FLAGS}+" \
        -e "s+@CC1PLUS_CPU_ENDIAN_FLAGS@+${CC1PLUS_CPU_ENDIAN_FLAGS}+" \
        -e "s+@LINKER_CPU_ENDIAN_FLAGS@+${LINKER_CPU_ENDIAN_FLAGS}+" \
        -e "s+@LINKER_RPATH_LINK_FLAG@+${LINKER_RPATH_LINK_FLAG}+" \
        debian/edit-specs.in >${arch}/edit-specs-${CPU}.sed

    sed -f ${arch}/edit-specs-${CPU}.sed \
        $RPM_BUILD_ROOT%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/specs \
        > $RPM_BUILD_ROOT%{_prefix}/lib/gcc-lib/${CPU}-linux/%{GCC_VERSION}/specs

  done

%else
  ARCH_STRTIP=%{_target}-strip
  EXESUFFIX=""
  TOOLPREFIX=""
  ln -s ..%{_prefix}/bin/cpp ${RPM_BUILD_ROOT}/lib/cpp
  ln -s gcc ${RPM_BUILD_ROOT}%{_prefix}/bin/cc
  arch=%{_target}
  make DESTDIR=${RPM_BUILD_ROOT} \
	install -C ${arch}
  if [ %{TARGET_JAVA} -ne 0 ]; then
    make DESTDIR=${RPM_BUILD_ROOT} install -C ${arch}/${arch}/libffi
    make DESTDIR=${RPM_BUILD_ROOT} install -C ${arch}/${arch}/fastjar
    mv -f ${RPM_BUILD_ROOT}/%{_prefix}/%{_lib}/libgcj.spec \
          ${RPM_BUILD_ROOT}/%{_prefix}/lib/gcc-lib/${arch}/%{GCC_VERSION}/
  fi
  $ARCH_STRTIP $RPM_BUILD_ROOT%{_prefix}/bin/gcov$EXESUFFIX || :

cat >${arch}/edit-specs <<EOF
/^*cross_compile:$/ {
n
c\\
0
}
EOF
  sed -f ${arch}/edit-specs -e 's#-rpath-link.*/usr/%{_target}/lib##' \
     ${RPM_BUILD_ROOT}%{_prefix}/lib/gcc-lib/${arch}/%{GCC_VERSION}/specs \
    >${RPM_BUILD_ROOT}%{_prefix}/lib/gcc-lib/${arch}/%{GCC_VERSION}/specs.$$
  mv -f ${RPM_BUILD_ROOT}%{_prefix}/lib/gcc-lib/${arch}/%{GCC_VERSION}/specs.$$ \
        ${RPM_BUILD_ROOT}%{_prefix}/lib/gcc-lib/${arch}/%{GCC_VERSION}/specs

  sed -e "s/dependency_libs=.*/dependency_libs='-lm -lgcc -lc -lgcc'/" \
     ${RPM_BUILD_ROOT}%{_prefix}/lib/libstdc++.la \
    >${RPM_BUILD_ROOT}%{_prefix}/lib/libstdc++.la.$$
  mv -f ${RPM_BUILD_ROOT}%{_prefix}/lib/libstdc++.la.$$ \
        ${RPM_BUILD_ROOT}%{_prefix}/lib/libstdc++.la

  sed -e "s/dependency_libs=.*/dependency_libs='-lpthread -ldl -lz -lm -lgcc -lc -lgcc'/" \
     ${RPM_BUILD_ROOT}%{_prefix}/lib/libgcj.la \
    >${RPM_BUILD_ROOT}%{_prefix}/lib/libgcj.la.$$
  mv -f ${RPM_BUILD_ROOT}%{_prefix}/lib/libgcj.la.$$ \
        ${RPM_BUILD_ROOT}%{_prefix}/lib/libgcj.la

cat >$RPM_BUILD_ROOT%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/include/syslimits.h <<EOF
#define _GCC_NEXT_LIMITS_H		/* tell gcc's limits.h to recurse */
#include_next <limits.h>
#undef _GCC_NEXT_LIMITS_H
EOF

%endif

  $ARCH_STRTIP $RPM_BUILD_ROOT%{_prefix}/bin/${TOOLPREFIX}{gcc,cpp,c++,c++filt,gcj,gcjh,gij,jar,grepjar,jcf-dump,jv-convert,jv-scan}$EXESUFFIX || :
  FULLPATH=$(dirname $RPM_BUILD_ROOT%{_prefix}/lib/gcc-lib/${arch}/%{GCC_VERSION}/cc1${EXESUFFIX})
  $ARCH_STRTIP $FULLPATH/{cc1${EXESUFFIX},cc1plus${EXESUFFIX},cpp0${EXESUFFIX},tradcpp0${EXESUFFIX},collect2${EXESUFFIX},jc1${EXESUFFIX},jvgenmain${EXESUFFIX}} || :

  # Strip static libraries
  sh-linux-strip -S -R .comment `find $RPM_BUILD_ROOT -type f -name "*.a"` || :

  # Strip ELF shared objects
  for f in `find $RPM_BUILD_ROOT -type f  \( -perm -0100 -or -perm -0010 -or -perm -0001 \) `; do
        if file $f | grep -q "shared object.*not stripped"; then
                sh-linux-strip --strip-unneeded -R .comment $f
        fi
  done

%clean
rm -rf $RPM_BUILD_ROOT

# ==================== Cross Compiler ===============================
%ifarch i386

%files sh-linux
%defattr(-,root,root)
%{_prefix}/bin/sh*
%dir %{_prefix}/lib/gcc-lib/sh-linux
%dir %{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}
%dir %{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/include
%dir %{_prefix}/lib/gcc-lib/sh3-linux
%dir %{_prefix}/lib/gcc-lib/sh3-linux/%{GCC_VERSION}
%dir %{_prefix}/lib/gcc-lib/sh3eb-linux
%dir %{_prefix}/lib/gcc-lib/sh3eb-linux/%{GCC_VERSION}
%dir %{_prefix}/lib/gcc-lib/sh4-linux
%dir %{_prefix}/lib/gcc-lib/sh4-linux/%{GCC_VERSION}
%dir %{_prefix}/lib/gcc-lib/sh4eb-linux
%dir %{_prefix}/lib/gcc-lib/sh4eb-linux/%{GCC_VERSION}
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/cc1
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/cc1plus
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/collect2
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/cpp0
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/*.o
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/libgcc*.a
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/specs
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/tradcpp0
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/jc1
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/jvgenmain
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/m4
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/mb
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/include/stddef.h
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/include/stdarg.h
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/include/varargs.h
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/include/float.h
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/include/limits.h
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/include/stdbool.h
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/include/iso646.h
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/include/syslimits.h
%{_prefix}/lib/gcc-lib/sh-linux/%{GCC_VERSION}/include/README
%{_prefix}/lib/gcc-lib/sh3-linux/%{GCC_VERSION}/*
%{_prefix}/lib/gcc-lib/sh3eb-linux/%{GCC_VERSION}/*
%{_prefix}/lib/gcc-lib/sh4-linux/%{GCC_VERSION}/*
%{_prefix}/lib/gcc-lib/sh4eb-linux/%{GCC_VERSION}/*
%{_mandir}/man1/sh-linux-*
%dir %{_prefix}/sh-linux/include
%{_prefix}/sh3-linux/include
%{_prefix}/sh3eb-linux/include
%{_prefix}/sh4-linux/include
%{_prefix}/sh4eb-linux/include
%endif

%if %{TARGET_LIBSTDC}
%ifarch i386
%{_prefix}/sh-linux/include/g++-v3
%{_prefix}/sh-linux/lib/libs*
%{_prefix}/sh-linux/lib/m4/libs*
%{_prefix}/sh-linux/lib/mb/libs*
%{_prefix}/sh-linux/lib/mb/m4/libs*
%{_prefix}/sh3-linux/lib/libs*
%{_prefix}/sh4-linux/lib/libs*
%{_prefix}/sh3eb-linux/lib/libs*
%{_prefix}/sh4eb-linux/lib/libs*
%endif
%endif

%if %{TARGET_JAVA}
%ifarch i386
%files -n libgcj-sh-linux
%defattr(-,root,root)
%{_prefix}/sh-linux/include/*.h
%{_prefix}/sh-linux/include/gcj
%{_prefix}/sh-linux/include/gnu/*
%{_prefix}/sh-linux/include/java
%{_prefix}/sh-linux/lib/lib*gcj*
%{_prefix}/sh-linux/lib/m4/lib*gcj*
%{_prefix}/sh-linux/lib/mb/lib*gcj*
%{_prefix}/sh-linux/lib/mb/m4/lib*gcj*
%{_prefix}/sh-linux/lib/libffi*
%{_prefix}/sh-linux/lib/m4/libffi*
%{_prefix}/sh-linux/lib/mb/libffi*
%{_prefix}/sh-linux/lib/mb/m4/libffi*
%{_prefix}/sh-linux/share/java/libgcj-%{GCC_VERSION}.jar
%{_prefix}/sh3-linux/lib/lib*gcj*
%{_prefix}/sh3-linux/lib/libffi*
%{_prefix}/sh3-linux/share/java/libgcj-%{GCC_VERSION}.jar
%{_prefix}/sh4-linux/lib/lib*gcj*
%{_prefix}/sh4-linux/lib/libffi*
%{_prefix}/sh4-linux/share/java/libgcj-%{GCC_VERSION}.jar
%{_prefix}/sh3eb-linux/lib/lib*gcj*
%{_prefix}/sh3eb-linux/lib/libffi*
%{_prefix}/sh3eb-linux/share/java/libgcj-%{GCC_VERSION}.jar
%{_prefix}/sh4eb-linux/lib/lib*gcj*
%{_prefix}/sh4eb-linux/lib/libffi*
%{_prefix}/sh4eb-linux/share/java/libgcj-%{GCC_VERSION}.jar
%endif
%endif

%ifarch sh3 sh3eb sh4 sh4eb
# =========================== Native Compiler =================================
%files
%defattr(-,root,root)
%dir %{_prefix}/lib/gcc-lib/%{_target}
%dir %{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}
%dir %{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/include
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/cc1
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/collect2
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/cpp0
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/crt*.o
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/libgcc*.a
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/specs
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/tradcpp0
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/include/stddef.h
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/include/stdarg.h
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/include/varargs.h
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/include/float.h
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/include/limits.h
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/include/stdbool.h
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/include/iso646.h
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/include/syslimits.h
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/include/README
%{_prefix}/bin/gcc
%{_prefix}/bin/%{_target}-gcc
%{_prefix}/bin/cpp
%{_prefix}/bin/gccbug
%{_prefix}/bin/gcov
%{_prefix}/bin/cc
/lib/cpp
%{_infodir}/cpp*
%{_infodir}/gcc*

%if 0
%files libgcc
%defattr(-,root,root)
/lib/libgcc_s.so*
%endif

%files c++
%defattr(-,root,root)
%{_prefix}/bin/c++
%{_prefix}/bin/g++
%{_prefix}/bin/c++filt
%{_prefix}/bin/%{_target}-c++
%{_prefix}/bin/%{_target}-g++
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/cc1plus
%endif

%if %{TARGET_LIBSTDC}
%ifarch sh3 sh3eb sh4 sh4eb
%files -n libstdc++
%defattr(-,root,root)
%{_prefix}/lib/libstdc++.so*

%files -n libstdc++-devel
%defattr(-,root,root)
%{_prefix}/include/g++-v3
%{_prefix}/lib/libstdc++.*a
%endif
%endif

%if %{TARGET_JAVA}
%ifarch sh3 sh3eb sh4 sh4eb
%files java
%defattr(-,root,root)
%{_prefix}/bin/addr2name.awk
%{_prefix}/bin/gcj
%{_prefix}/bin/gcjh
%{_prefix}/bin/gij
%{_prefix}/bin/jar
%{_prefix}/bin/grepjar
%{_prefix}/bin/jcf-dump
%{_prefix}/bin/jv-convert
%{_prefix}/bin/jv-scan
%dir %{_prefix}/lib/gcc-lib
%dir %{_prefix}/lib/gcc-lib/%{_target}
%dir %{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/jc1
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/jvgenmain
%{_infodir}/gcj*

%files -n libgcj
%defattr(-,root,root)
%{_prefix}/%{_lib}/libgcj.so*
%{_prefix}/%{_lib}/libffi*.so*
%{_prefix}/lib/gcc-lib/%{_target}/%{GCC_VERSION}/libgcj.spec
%{_prefix}/share/java/libgcj-%{GCC_VERSION}.jar

%files -n libgcj-devel
%defattr(-,root,root)
%{_prefix}/include/*.h
%{_prefix}/include/gcj
%{_prefix}/include/gnu/*
%{_prefix}/include/java
%{_prefix}/lib/libgcj.*a
%{_prefix}/lib/libffi.*a
%endif
%endif

%changelog
* Wed Feb 19 2003 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- version 3.2.2.

* Tue Feb 19 2002 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- version 3.0.4.

* Tue Feb 12 2002 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- add java support.

* Thu Feb 7 2002 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- follow debian/SH update.

* Tue Feb 5 2002 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- follow debian/SH update.

* Thu Jan 24 2002 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- rebuild with new binutils.

* Tue Jan 22 2002 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- leaf function optimization fixed.

* Thu Dec 06 2001 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- add gcc-ice-rml patch.

* Tue Nov 13 2001 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- add configure option.

* Thu Nov 01 2001 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- tablejump fix by gniibe.

* Mon Oct 22 2001 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- updated gcc patch.

* Wed Oct 17 2001 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- updated gcc patch.

* Tue Oct 02 2001 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- gcc/config/sh/sh.c bug fix.

* Fri Aug 24 2001 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- gcc version 3.0.1.

* Thu Jun 28 2001 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- gcc version 3.0.
- Add libstdc++ package.

* Mon Apr 23 2001 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- Add cygwin host.

* Sat Dec 23 2000 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- fix file attribute.
- add asmspecs patch.

* Sat Nov 11 2000 SUGIOKA Toshinobu <sugioka@itonet.co.jp>
- initial version.
