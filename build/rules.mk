# vim: ft=make ts=3 sw=3
#
# BEGIN SONGBIRD GPL
#
# This file is part of the Songbird web player.
#
# Copyright(c) 2005-2008 POTI, Inc.
# http://www.songbirdnest.com
#
# This file may be licensed under the terms of of the
# GNU General Public License Version 2 (the GPL).
#
# Software distributed under the License is distributed
# on an AS IS basis, WITHOUT WARRANTY OF ANY KIND, either
# express or implied. See the GPL for the specific language
# governing rights and limitations.
#
# You should have received a copy of the GPL along with this
# program. If not, go to http://www.gnu.org/licenses/gpl.html
# or write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# END SONGBIRD GPL
#

##############################################################################
# Rules.mk
#
# This file takes care of lots of messy rules. Each one is explained below.
###############################################################################

#------------------------------------------------------------------------------
# Only include this file once
ifndef RULES_MK_INCLUDED
RULES_MK_INCLUDED=1
#------------------------------------------------------------------------------

# include config.mk to pick up extra variables
include $(topsrcdir)/build/config.mk

# define the tiers of the application
include $(topsrcdir)/build/tiers.mk

# Provide working dependencies for the Mac vendor-binaries bits we use in the
# build
ifeq (macosx,$(SB_PLATFORM))
  SB_DYLD_LIBRARY_PATH = $(DEPS_DIR)/libIDL/$(SB_CONFIGURATION)/lib:$(DEPS_DIR)/glib/$(SB_CONFIGURATION)/lib:$(DEPS_DIR)/gettext/$(SB_CONFIGURATION)/lib
  export DYLD_LIBRARY_PATH = $(SB_DYLD_LIBRARY_PATH)
endif

# Since public, src, and test are directories used throughout the tree
# we automatically add them to SUBDIRS _unless_ it's requested that we don't
ifeq (,$(DISABLE_IMPLICIT_SUBDIRS))
   OUR_SUBDIRS = $(NULL)
   OUR_SUBDIRS += $(if $(wildcard $(srcdir)/public), public)
   OUR_SUBDIRS += $(if $(wildcard $(srcdir)/src), src)
   OUR_SUBDIRS += $(SUBDIRS)
   ifdef SB_ENABLE_TESTS
      OUR_SUBDIRS += $(if $(wildcard $(srcdir)/test), test)
   endif
else
   OUR_SUBDIRS = $(SUBDIRS)
endif

# Right now this system is not compatible with parallel make.
.NOTPARALLEL: all clean libs export

#------------------------------------------------------------------------------
# Redefine these file locations when building extensions
#------------------------------------------------------------------------------

ifdef EXTENSION_STAGE_DIR
   SONGBIRD_CHROMEDIR = $(EXTENSION_STAGE_DIR)/chrome
   SONGBIRD_COMPONENTSDIR = $(EXTENSION_STAGE_DIR)/components
   SONGBIRD_DEFAULTSDIR = $(EXTENSION_STAGE_DIR)/defaults
   SONGBIRD_PREFERENCESDIR = $(EXTENSION_STAGE_DIR)/defaults/preferences
   SONGBIRD_PLUGINSDIR = $(EXTENSION_STAGE_DIR)/plugins
   SONGBIRD_SEARCHPLUGINSDIR = $(EXTENSION_STAGE_DIR)/searchplugins
   SONGBIRD_SCRIPTSDIR = $(EXTENSION_STAGE_DIR)/scripts
   SONGBIRD_JSMODULESDIR = $(EXTENSION_STAGE_DIR)/jsmodules
endif

ifdef SONGBIRD_TEST_COMPONENT
   SONGBIRD_TEST_COMPONENT_DIR = $(SONGBIRD_TESTSDIR)/$(SONGBIRD_TEST_COMPONENT)
   ifdef SB_ENABLE_TESTS
      APP_DIST_DIRS += $(SONGBIRD_TEST_COMPONENT_DIR)
   endif
endif

###############################################################################

LOOP_OVER_SUBDIRS = \
   @$(EXIT_ON_ERROR) \
   $(foreach dir,$(OUR_SUBDIRS), $(MAKE) -C $(dir) $@; ) true

# MAKE_DIRS: List of directories to build while looping over directories.
ifneq (,$(OBJS)$(XPIDLSRCS)$(SDK_XPIDLSRCS)$(SIMPLE_PROGRAMS))
   MAKE_DIRS += $(MDDEPDIR)
   GARBAGE_DIRS += $(MDDEPDIR)
endif

ifdef DYNAMIC_LIB
   ifneq (,$(DISABLE_IMPLICIT_NAMING))
      OUR_DYNAMIC_LIB = $(DYNAMIC_LIB)
   else
      OUR_DYNAMIC_LIB = $(DYNAMIC_LIB)$(DEBUG:%=_d)$(DLL_SUFFIX)
   endif
endif

ifdef STATIC_LIB
   ifneq (,$(DISABLE_IMPLICIT_NAMING))
      OUR_STATIC_LIB = $(STATIC_LIB)
   else
      OUR_STATIC_LIB = $(STATIC_LIB)$(DEBUG:%=_d)$(LIB_SUFFIX)
   endif
endif

ifdef SIMPLE_PROGRAM
   ifneq (,$(DISABLE_IMPLICIT_NAMING))
      OUR_SIMPLE_PROGRAM = $(SIMPLE_PROGRAM)
   else
      OUR_SIMPLE_PROGRAM = $(SIMPLE_PROGRAM)$(DEBUG:%=_d)$(BIN_SUFFIX)
   endif
endif

# SUBMAKEFILES: List of Makefiles for next level down.
#   This is used to update or create the Makefiles before invoking them.
SUBMAKEFILES += $(addsuffix /Makefile, $(OUR_SUBDIRS))

###############################################################################

ifdef TIERS
   OUR_SUBDIRS += $(foreach tier,$(TIERS),$(tier_$(tier)_dirs))

# The $(CREATEDIRS) dependency may look a bit out of place, but it's required
# because the top-level makefile not only defines a bunch of tiers (i.e. this
# branch of the ifdef), but also sets up the dist (and other) directories; if
# we make CREATEDIRS only a dependency of export (which we do below), we'll
# move on to processing the tiers before we've created the directories,
# and all sorts of stuff will fail.

default all alldep:: $(SUBMAKEFILES) $(APP_DIST_DIRS)
	$(EXIT_ON_ERROR) \
	$(foreach tier,$(TIERS),$(MAKE) tier_$(tier); ) true

else

default all:: 
	$(MAKE) export
	$(MAKE) libs
endif

ALL_TRASH = \
   $(GARBAGE) \
   $(COMPILER_GARBAGE) \
   $(XPIDL_HEADERS) $(XPIDL_TYPELIBS) $(XPIDL_MODULE) \
   $(OUR_DYNAMIC_LIB_OBJS) $(OUR_DYNAMIC_LIB) \
   $(OUR_DYNAMIC_LIB_OBJS:$(OBJ_SUFFIX)=.s) \
   $(OUR_DYNAMIC_LIB_OBJS:$(OBJ_SUFFIX)=.i) \
   $(OUR_STATIC_LIB_OBJS) $(OUR_STATIC_LIB) \
   $(OUR_STATIC_LIB_OBJS:$(OBJ_SUFFIX)=.s) \
   $(OUR_STATIC_LIB_OBJS:$(OBJ_SUFFIX)=.i) \
   $(GENERATED_PP_DEPS) \
   $(SIMPLE_PROGRAM_OBJS) $(SIMPLE_PROGRAM) \
   $(JAR_MANIFEST) \
   LOGS TAGS a.out

ifeq (windows,$(SB_PLATFORM))
   ALL_TRASH += \
    $(OUR_DYNAMIC_LIB:$(DLL_SUFFIX)=.pdb) \
    $(OUR_DYNAMIC_LIB:$(DLL_SUFFIX)=.lib) \
    $(OUR_DYNAMIC_LIB:$(DLL_SUFFIX)=.exp) \
    $(OUR_DYNAMIC_LIB).manifest \
    $(OUR_SIMPLE_PROGRAM:$(BIN_SUFFIX)=.pdb) \
    $(OUR_SIMPLE_PROGRAM:$(BIN_SUFFIX)=.lib) \
    $(OUR_SIMPLE_PROGRAM:$(BIN_SUFFIX)=.exp) \
    $(OUR_SIMPLE_PROGRAM).manifest \
    $(NULL)
endif

clean:: $(SUBMAKEFILES)
	-$(RM) $(ALL_TRASH)
	+$(LOOP_OVER_SUBDIRS)

distclean:: FORCE
	$(RM) -r $(SONGBIRD_DISTDIR)

export_tier_%:
	$(EXIT_ON_ERROR) \
    $(foreach dir,$(tier_$*_dirs),$(MAKE) -C $(dir) export; ) true

libs_tier_%:
	$(EXIT_ON_ERROR) \
    $(foreach dir,$(tier_$*_dirs),$(MAKE) -C $(dir) libs; ) true

# This dependency listing is technically incorrect, in that it states that
# _all_ the tiers are dependent on the makefiles of _all_ the tiers, not just
# the tier you're actually building. We did this to avoid spawning a (99% of
# the time) useless make invocation just to check the makefiles of the specific
# tier we're building. Plus, re-generating makefiles is pretty cheap, even if
# it's all of them for all the tier_dirs.
$(foreach tier,$(TIERS),tier_$(tier)):: $(foreach tier,$(TIERS),$(if $(tier_$(tier)_dirs),$(addsuffix /Makefile,$(tier_$(tier)_dirs))))
	@echo "BUILDING $(patsubst tier_%,%,$@) TIER; directories: $($@_dirs)"
	$(MAKE) export_$@
	$(MAKE) libs_$@

##
## SUBDIRS handling for libs and export targets
##

libs:: $(SUBMAKEFILES) $(OUR_SUBDIRS)
	+$(LOOP_OVER_SUBDIRS)

export:: $(SUBMAKEFILES) $(APP_DIST_DIRS) $(CREATEDIRS) $(OUR_SUBDIRS)
	+$(LOOP_OVER_SUBDIRS)

## 
## Handle application and component directory creation
##
$(APP_DIST_DIRS) $(CREATEDIRS): %: FORCE
	$(if $(wildcard $@),,$(MKDIR) $@)

##
## Program handling for libs and export targets
##

libs:: $(OUR_STATIC_LIB) $(OUR_DYNAMIC_LIB) $(OUR_SIMPLE_PROGRAM) $(SONGBIRD_COMPONENTS)
ifndef NO_DIST_INSTALL
   ifdef SIMPLE_PROGRAM
	   $(INSTALL_PROG) $(OUR_SIMPLE_PROGRAM) $(FINAL_TARGET)
   endif
   ifdef DYNAMIC_LIB
      ifdef IS_COMPONENT
	      $(INSTALL_PROG) $(OUR_DYNAMIC_LIB) $(SONGBIRD_COMPONENTSDIR)/
      else
	      $(INSTALL_PROG) $(OUR_DYNAMIC_LIB) $(SONGBIRD_LIBDIR)/
      endif
   endif
endif # !NO_DIST_INSTALL

##
## Unit test handling 
##

libs:: $(SONGBIRD_TESTS)
ifdef SB_ENABLE_TESTS
   ifneq (,$(SONGBIRD_TEST_COMPONENT_DIR))
	   $(INSTALL_FILE) $(SONGBIRD_TESTS) $(SONGBIRD_TEST_COMPONENT_DIR)
   endif
endif

#------------------------------------------------------------------------------
# Rules for Makefile generation
#------------------------------------------------------------------------------

makefiles: $(SUBMAKEFILES)
	+$(LOOP_OVER_SUBDIRS)

Makefile: $(srcdir)/Makefile.in
	$(PERL) $(MOZSDK_SCRIPTS_DIR)/make-makefile -t $(topsrcdir) -d $(DEPTH) $@

$(SUBMAKEFILES): % : $(srcdir)/%.in
	$(PERL) $(MOZSDK_SCRIPTS_DIR)/make-makefile -t $(topsrcdir) -d $(DEPTH) $@

#------------------------------------------------------------------------------
# Rules for XPIDL compilation
#------------------------------------------------------------------------------
#
# XPIDL_SRCS - a list of idl files to turn into header and typelib files
# XPIDL_HEADER_SRCS - a list of idl files to turn into C++ header files
# XPIDL_TYPELIB_SRCS - a list of idl files to turn into xpt typelib files
# XPIDL_MODULE - the name of an xpt file that will created from linking several
#                other xpt typelibs
# XPIDL_MODULE_TYPELIBS - a list of xpt files to link into the module
# XPIDL_INCLUDES - a list of dirs to search when looking for included idls
# XPIDL_EXTRA_FLAGS - additional flags to send to XPIDL
#

XPIDL_INCLUDES += $(MOZSDK_IDL_DIR) \
                  $(srcdir) \
                  $(NULL)

XPIDL_HEADERS = $(XPIDL_SRCS:.idl=.h)

$(XPIDL_HEADERS): %.h: %.idl
	$(XPIDL) -m header $(addprefix -I,$(XPIDL_INCLUDES)) $(XPIDL_EXTRA_FLAGS) $<

export:: $(XPIDL_HEADERS)

XPIDL_TYPELIBS = $(XPIDL_SRCS:.idl=.xpt)

$(XPIDL_TYPELIBS): %.xpt: %.idl
	$(XPIDL) -m typelib $(addprefix -I,$(XPIDL_INCLUDES)) $(XPIDL_EXTRA_FLAGS) -e $@ $<

# The ifneq() check is in here because if the collected typelibs are the same 
# (single file) as XPIDL_MODULE, there's no reason to run xpt_link on them.
# (In fact, this creates a circular make dependency that gets dropped, but 
# xpt_link clobbers the file in the process of trying to link it, and 
# fails anyway.

$(XPIDL_MODULE): $(XPIDL_MODULE_TYPELIBS)
ifneq ($(strip $(XPIDL_MODULE)),$(strip $(XPIDL_MODULE_TYPELIBS)))
	$(XPTLINK) $(XPIDL_MODULE) $(XPIDL_MODULE_TYPELIBS)
endif

libs:: $(XPIDL_TYPELIBS) $(XPIDL_MODULE)
ifneq (,$(XPIDL_MODULE))
	$(INSTALL_FILE) $(XPIDL_MODULE) $(SONGBIRD_COMPONENTSDIR)
endif

#------------------------------------------------------------------------------
# Common compiler flags
#------------------------------------------------------------------------------

ifeq (windows,$(SB_PLATFORM))
   COMPILER_OUTPUT_FLAG = -Fo$@
else
   COMPILER_OUTPUT_FLAG = -o $@
endif

#------------------------------------------------------------------------------
# rules for C++ compilation
#------------------------------------------------------------------------------
#
# CPP_SRCS           - a list of .cpp files to be compiled
#
# CPP_INCLUDES       - an override of the default include dirs to pass to 
#                      the compiler
# CPP_EXTRA_INCLUDES - a list of additional include dirs 
# CPP_RAW_INCLUDES   - a list of additional include dirs that don't get 
#                      processed designed to be the target for cflags vars 
#                      that are generated by pkg-config
#
# CPP_FLAGS          - an override of the default flags to pass to the compiler
# CPP_EXTRA_FLAGS    - a list of additional flags to pass to the compiler
#
# CPP_DEFS           - a override of the default defines to pass to the 
#                      compiler with -D added
# CPP_EXTRA_DEFS     - a list of additional defines with -D to pass to the 
#                      compiler
#

CPP_DEFAULT_INCLUDES = $(MOZSDK_INCLUDE_DIR) \
                       $(MOZSDK_INCLUDE_DIR)/nspr \
                       $(MOZSDK_INCLUDE_DIR)/xpcom \
                       $(MOZSDK_INCLUDE_DIR)/string \
                       $(NULL)

ifdef CPP_FLAGS
   OUR_CPP_FLAGS = $(CPP_FLAGS)
else
   OUR_CPP_FLAGS = $(CXXFLAGS) $(CPP_EXTRA_FLAGS)
   ifeq (macosx,$(SB_PLATFORM))
      OUR_CPP_FLAGS += -isysroot $(SB_MACOSX_SDK)
   endif
endif

ifdef CPP_DEFS
   OUR_CPP_DEFS = $(CPP_DEFS)
else
   OUR_CPP_DEFS = $(ACDEFINES) $(CPP_EXTRA_DEFS)
endif

ifdef CPP_INCLUDES
   OUR_CPP_INCLUDES = $(addsuffix $(CFLAGS_INCLUDE_SUFFIX),$(addprefix $(CFLAGS_INCLUDE_PREFIX),$(CPP_INCLUDES)))
else
   OUR_CPP_INCLUDES = $(addsuffix $(CFLAGS_INCLUDE_SUFFIX),$(addprefix $(CFLAGS_INCLUDE_PREFIX),$(CPP_EXTRA_INCLUDES) $(CPP_DEFAULT_INCLUDES)))
   OUR_CPP_INCLUDES += $(CPP_RAW_INCLUDES)
endif

%$(OBJ_SUFFIX): %.cpp
	$(CXX) $(COMPILER_OUTPUT_FLAG) $(OUR_CPP_FLAGS) $(OUR_CPP_DEFS) $(OUR_CPP_INCLUDES) $<

%.i: %.cpp
	$(CXX) $(COMPILER_OUTPUT_FLAG) $(CFLAGS_PREPROCESS) $(OUR_CPP_FLAGS) $(OUR_CPP_DEFS) $(OUR_CPP_INCLUDES) $<

%.s: %.cpp
	$(CXX) $(COMPILER_OUTPUT_FLAG) $(CFLAGS_ASSEMBLER) $(OUR_CPP_FLAGS) $(OUR_CPP_DEFS) $(OUR_CPP_INCLUDES) $<

#------------------------------------------------------------------------------
# rules for Objective C compilation
#------------------------------------------------------------------------------
#
# CMM_SRCS           - a list of .mm files to be compiled
#
# CMM_INCLUDES       - an override of the default include dirs to pass to 
#                      the compiler
# CMM_EXTRA_INCLUDES - a list of additional include dirs 
# CMM_RAW_INCLUDES   - a list of additional include dirs that don't get 
#                      processed designed to be the target for cflags vars 
#                      that are generated by pkg-config
#
# CMM_FLAGS          - an override of the default flags to pass to the compiler
# CMM_EXTRA_FLAGS    - a list of additional flags to pass to the compiler
#
# CMM_DEFS - a override of the default defines to pass to the compiler with 
#            -D added
# CMM_EXTRA_DEFS - a list of additional defines with -D to pass to the compiler
#

CMM_DEFAULT_INCLUDES = $(MOZSDK_INCLUDE_DIR) \
                       $(MOZSDK_INCLUDE_DIR)/nspr \
                       $(MOZSDK_INCLUDE_DIR)/xpcom \
                       $(MOZSDK_INCLUDE_DIR)/string \
                       $(NULL)

ifdef CMM_FLAGS
   OUR_CMM_FLAGS = $(CMM_FLAGS)
else
   OUR_CMM_FLAGS = $(CMMFLAGS) $(CMM_EXTRA_FLAGS)
   ifeq (macosx,$(SB_PLATFORM))
      OUR_CMM_FLAGS += -isysroot $(SB_MACOSX_SDK)
   endif
endif

ifdef CMM_DEFS
   OUR_CMM_DEFS = $(CMM_DEFS)
else
   OUR_CMM_DEFS = $(ACDEFINES) $(CMM_EXTRA_DEFS)
endif

ifdef CMM_INCLUDES
   OUR_CMM_INCLUDES = $(addsuffix $(CFLAGS_INCLUDE_SUFFIX),$(addprefix $(CFLAGS_INCLUDE_PREFIX),$(CMM_INCLUDES)))
else
   OUR_CMM_INCLUDES = $(addsuffix $(CFLAGS_INCLUDE_SUFFIX),$(addprefix $(CFLAGS_INCLUDE_PREFIX),$(CMM_EXTRA_INCLUDES) $(CMM_DEFAULT_INCLUDES)))
   OUR_CMM_INCLUDES += $(CMM_RAW_INCLUDES)
endif

%$(OBJ_SUFFIX): %.mm
	$(CXX) $(COMPILER_OUTPUT_FLAG) $(OUR_CMM_FLAGS) $(OUR_CMM_DEFS) $(OUR_CMM_INCLUDES) $<

%.i: %.mm
	$(CXX) $(COMPILER_OUTPUT_FLAG) $(CFLAGS_PREPROCESS) $(OUR_CMM_FLAGS) $(OUR_CMM_DEFS) $(OUR_CMM_INCLUDES) $<

%.s: %.mm
	$(CXX) $(COMPILER_OUTPUT_FLAG) $(CFLAGS_ASSEMBLER) $(OUR_CMM_FLAGS) $(OUR_CMM_DEFS) $(OUR_CMM_INCLUDES) $<


#------------------------------------------------------------------------------
# rules for C compilation
#------------------------------------------------------------------------------
#
# C_SRCS           - a list of .c files to be compiled
#
# C_INCLUDES       - an override of the default include dirs to pass to 
#                    the compiler
# C_EXTRA_INCLUDES - a list of additional include dirs 
# C_RAW_INCLUDES   - a list of additional include dirs that don't get 
#                    processed designed to be the target for cflags vars 
#                    that are generated by pkg-config
#
# C_FLAGS          - an override of the default flags to pass to the compiler
# C_EXTRA_FLAGS    - a list of additional flags to pass to the compiler
#
# C_DEFS           - a override of the default defines to pass to the 
#                    compiler with -D added
# C_EXTRA_DEFS     - a list of additional defines with -D to pass to the 
#                    compiler
#

C_DEFAULT_INCLUDES = $(NULL)

ifdef C_FLAGS
   OUR_C_FLAGS = $(C_FLAGS)
else
   OUR_C_FLAGS = $(CFLAGS) $(C_EXTRA_FLAGS)
   ifeq (macosx,$(SB_PLATFORM))
      OUR_C_FLAGS += -isysroot $(SB_MACOSX_SDK)
   endif
endif

ifdef C_DEFS
   OUR_C_DEFS = $(C_DEFS)
else
   OUR_C_DEFS = $(ACDEFINES) $(C_EXTRA_DEFS)
endif

ifdef C_INCLUDES
   OUR_C_INCLUDES = $(addsuffix $(CFLAGS_INCLUDE_SUFFIX),$(addprefix $(CFLAGS_INCLUDE_PREFIX),$(C_INCLUDES)))
else
   OUR_C_INCLUDES = $(addsuffix $(CFLAGS_INCLUDE_SUFFIX),$(addprefix $(CFLAGS_INCLUDE_PREFIX),$(C_EXTRA_INCLUDES) $(C_DEFAULT_INCLUDES)))
   OUR_C_INCLUDES += $(C_RAW_INCLUDES)
endif

%$(OBJ_SUFFIX): %.c
	$(CC) $(COMPILER_OUTPUT_FLAG) $(OUR_C_FLAGS) $(OUR_C_DEFS) $(OUR_C_INCLUDES) $<

%.i: %.c
	$(CC) $(COMPILER_OUTPUT_FLAG) $(CFLAGS_PREPROCESS) $(OUR_C_FLAGS) $(OUR_C_DEFS) $(OUR_C_INCLUDES) $<

%.s: %.c
	$(CC) $(COMPILER_OUTPUT_FLAG) $(CFLAGS_ASSEMBLER) $(OUR_C_FLAGS) $(OUR_C_DEFS) $(OUR_C_INCLUDES) $<

#------------------------------------------------------------------------------
# Rules for dynamic (.so/.dylib/.dll) library generation
#------------------------------------------------------------------------------
# DYNAMIC_LIB                - the name of a lib to generate
# DYNAMIC_LIB_OBJS           - an override to the defaut list of object files 
#                              to link into the shared lib
#
# DYNAMIC_LIB_EXTRA_OBJS     - a list of extra objects to add to the library
#
# DYNAMIC_LIB_IMPORT_PATHS   - an overide to the default list of libs to link
# DYNAMIC_LIB_IMPORT_EXTRA_PATHS   - a list of paths to search for libs
#
# DYNAMIC_LIB_IMPORTS        - an override to the default list of libs to link
# DYNAMIC_LIB_EXTRA_IMPORTS  - an additional list of libs to link in
# DYNAMIC_LIB_STATIC_IMPORTS - a list of static libs to link in
#
# DYNAMIC_LIB_FLAGS          - an override to the default linker flags
# DYNAMIC_LIB_EXTRA_FLAGS    - a list of additional flags to pass to the linker
#
# DISABLE_IMPLICIT_LIBNAME   - disables the automatic generation of the 
#                              library name; DYNAMIC_LIB is used directly

DEFAULT_DYNAMIC_LIBS_IMPORTS = xpcomglue_s \
                               nspr4 \
                               xpcom \
                               $(DEFAULT_LIBS) \
                               $(NULL)

DEFAULT_DYNAMIC_LIB_IMPORT_PATHS = $(MOZSDK_LIB_DIR)

ifdef DYNAMIC_LIB # {

ifdef DYNAMIC_LIB_OBJS
   OUR_DYNAMIC_LIB_OBJS = $(DYNAMIC_LIB_OBJS)
else
   OUR_DYNAMIC_LIB_OBJS = $(CPP_SRCS:.cpp=$(OBJ_SUFFIX)) \
                          $(C_SRCS:.c=$(OBJ_SUFFIX)) \
                          $(CMM_SRCS:.mm=$(OBJ_SUFFIX)) \
                          $(DYNAMIC_LIB_EXTRA_OBJS) \
                          $(NULL)
endif

ifdef DYNAMIC_LIB_FLAGS
   OUR_LD_FLAGS = $(DYNAMIC_LIB_FLAGS)
else
   OUR_LD_FLAGS = $(LDFLAGS) $(LDFLAGS_DLL) $(DYNAMIC_LIB_EXTRA_FLAGS)

   ifeq (macosx,$(SB_PLATFORM))
      OUR_LD_FLAGS += -isysroot $(SB_MACOSX_SDK) -Wl,-syslibroot,$(SB_MACOSX_SDK)
       ifdef IS_COMPONENT
          OUR_LD_FLAGS += -bundle
       else 
          OUR_LD_FLAGS += -dynamiclib -install_name @executable_path/$(OUR_DYNAMIC_LIB) -compatibility_version 1 -current_version 1
       endif
   endif
endif

ifdef DYNAMIC_LIB_IMPORT_PATHS
   OUR_LINKER_PATHS_LIST = $(DYNAMIC_LIB_IMPORT_PATHS)
else
   OUR_LINKER_PATHS_LIST = $(DEFAULT_DYNAMIC_LIB_IMPORT_PATHS) $(DYNAMIC_LIB_IMPORT_EXTRA_PATHS)
endif

ifneq (,$(OUR_LINKER_PATHS_LIST))
   OUR_LINKER_PATHS = $(addsuffix $(LDFLAGS_PATH_SUFFIX),\
                       $(addprefix $(LDFLAGS_PATH_PREFIX),\
                       $(foreach dir,$(OUR_LINKER_PATHS_LIST),\
                       $(call normalizepath,$(dir)))))
else
   OUR_LINKER_PATHS = $(NULL)
endif

ifdef DYNAMIC_LIB_IMPORTS
   OUR_LD_IMPORT_LIST = $(DYNAMIC_LIB_IMPORTS)
else
   OUR_LD_IMPORT_LIST = $(DEFAULT_DYNAMIC_LIBS_IMPORTS) \
    $(foreach i, \
    $(DYNAMIC_LIB_EXTRA_IMPORTS), \
    $(if $(filter sb%,$i), \
    $i$(DEBUG:%=_d), \
    $i)) 
endif

OUR_LD_STATIC_IMPORT_LIST = $(foreach import, \
                             $(DYNAMIC_LIB_STATIC_IMPORTS), \
                             $(if $(wildcard $(dir $(import))), \
                             $(import)$(LIB_SUFFIX), \
                             $(addprefix $(SONGBIRD_OBJDIR)/, \
                             $(import)$(DEBUG:%=_d)$(LIB_SUFFIX))))

OUR_LD_IMPORTS = $(OUR_LD_STATIC_IMPORT_LIST) \
                  $(addsuffix $(LDFLAGS_IMPORT_SUFFIX),\
                  $(addprefix $(LDFLAGS_IMPORT_PREFIX),\
                  $(OUR_LD_IMPORT_LIST)))

OUR_LINKER_OUTPUT = $(LDFLAGS_OUT_PREFIX)$@$(LDFLAGS_OUT_SUFFIX)

$(OUR_DYNAMIC_LIB): $(OUR_DYNAMIC_LIB_OBJS)
ifdef FORCE_RANLIB
	$(RANLIB) $(OUR_LINKER_OUTPUT) $(FORCE_RANLIB)
endif
	$(LD) $(OUR_LINKER_OUTPUT) $(OUR_LD_FLAGS) $(OUR_LINKER_PATHS) $(OUR_DYNAMIC_LIB_OBJS) $(OUR_LD_IMPORTS)
endif # } DYNAMIC_LIB

#------------------------------------------------------------------------------
# Rules for static (.a/.lib) library generation
#------------------------------------------------------------------------------
# STATIC_LIB                - the name of a lib to generate
# STATIC_LIB_OBJS           - an override to the defaut list of object files 
#                             to link into the lib
# STATIC_LIB_FLAGS          - an overide t the default list of flags to
#                             pass to the static linker
# STATIC_LIB_EXTRA_FLAGS    - additional flags to pass to the linker
#
# STATIC_LIB_EXTRA_OBJS     - a list of extra objects to add to the library
#

ifdef STATIC_LIB

ifdef STATIC_LIB_FLAGS
   OUR_LINKER_FLAGS = $(STATIC_LIB_FLAGS)
else
   OUR_LINKER_FLAGS = $(ARFLAGS) $(ARFLAGS_LIB) $(STATIC_LIB_EXTRA_FLAGS)
endif

OUR_LINKER_OUTPUT = $(ARFLAGS_OUT_PREFIX)$@$(ARFLAGS_OUT_SUFFIX)

ifdef STATIC_LIB_OBJS
   OUR_STATIC_LIB_OBJS = $(STATIC_LIB_OBJS)
else
   OUR_STATIC_LIB_OBJS = $(CPP_SRCS:.cpp=$(OBJ_SUFFIX)) \
                         $(C_SRCS:.c=$(OBJ_SUFFIX)) \
                         $(CMM_SRCS:.mm=$(OBJ_SUFFIX)) \
                         $(STATIC_LIB_EXTRA_OBJS) \
                         $(NULL)
endif

$(OUR_STATIC_LIB): $(OUR_STATIC_LIB_OBJS)
ifdef USING_RANLIB
	$(RM) $@
endif
	$(AR) $(OUR_LINKER_FLAGS) $(OUR_LINKER_OUTPUT) $(OUR_STATIC_LIB_OBJS)
ifdef USING_RANLIB
	$(RANLIB) $(OUR_LINKER_OUTPUT)
endif

endif


#------------------------------------------------------------------------------
# Rules for creating simple programs
#------------------------------------------------------------------------------
#
#  A target for creating a simple program, consisting of a list of object
#  to link into a program.
# SIMPLE_PROGRAM - the name of a dll to link
# SIMPLE_PROGRAM_OBJS - the object files to link into the dll
# SIMPLE_PROGRAM_IMPORT_PATHS - a list of paths to search for libs
# SIMPLE_PROGRAM_IMPORTS - an override to the default list of libs to link
# SIMPLE_PROGRAM_EXTRA_IMPORTS - an additional list of libs to link
# SIMPLE_PROGRAM_STATIC_IMPORTS - a list of static libs to link
# SIMPLE_PROGRAM_FLAGS - an override to the default linker flags
# SIMPLE_PROGRAM_EXTRA_FLAGS - a list of additional flags to pass to the linker

ifdef SIMPLE_PROGRAM

ifneq (,$(STATIC_LIB)$(DYNAMIC_LIB))
   $(error SIMPLE_PROGRAM cannot be specified together with DYNAMIC_LIB or STATIC_LIB)
endif # STATIC_LIB || DYNAMIC_LIB

CPP_EXTRA_FLAGS += $(CFLAGS_STATIC_LIBC)

ifdef SIMPLE_PROGRAM_FLAGS
   OUR_SIMPLE_PROGRAM_FLAGS = $(SIMPLE_PROGRAM_FLAGS)
else
   OUR_SIMPLE_PROGRAM_FLAGS = $(LDFLAGS) $(LDFLAGS_BIN) $(SIMPLE_PROGRAM_EXTRA_FLAGS)
endif

ifdef SIMPLE_PROGRAM_IMPORTS
   OUR_SIMPLE_PROGRAM_IMPORTS_LIST = $(SIMPLE_PROGRAM_IMPORTS)
else
   OUR_SIMPLE_PROGRAM_IMPORTS_LIST = $(SIMPLE_PROGRAM_DEFAULT_LIBS) $(SIMPLE_PROGRAM_EXTRA_IMPORTS)
endif

ifdef SIMPLE_PROG_OBJS
   OUR_SIMPLE_PROGRAM_OBJS = $(SIMPLE_PROGRAM_OBJS)
else
   OUR_SIMPLE_PROGRAM_OBJS = $(CPP_SRCS:.cpp=$(OBJ_SUFFIX)) \
                             $(C_SRCS:.c=$(OBJ_SUFFIX)) \
                             $(CMM_SRCS:.mm=$(OBJ_SUFFIX)) \
                             $(SIMPLE_PROGRAM_EXTRA_OBJS) \
                             $(NULL)
endif

ifdef SIMPLE_PROGRAM_IMPORTS
   OUR_SIMPLE_PROGRAM_IMPORTS_LIST = $(SIMPLE_PROGRAM_IMPORTS)
else
   OUR_SIMPLE_PROGRAM_IMPORTS_LIST = $(DEFAULT_LIBS) $(SIMPLE_PROGRAM_EXTRA_IMPORTS)
endif

ifdef SIMPLE_PROGRAM_STATIC_IMPORTS
   ifeq (windows,$(SB_PLATFORM))
      OUR_SIMPLE_PROGRAM_IMPORTS_LIST += $(SIMPLE_PROGRAM_STATIC_IMPORTS)
   else
      OUR_SIMPLE_PROGRAM_OBJS += $(addsuffix $(LIB_SUFFIX),$(SIMPLE_PROGRAM_STATIC_IMPORTS))
   endif
endif

OUR_LINKER_IMPORTS = $(addsuffix $(LDFLAGS_IMPORT_SUFFIX), \
                      $(addprefix $(LDFLAGS_IMPORT_PREFIX), \
                      $(OUR_SIMPLE_PROGRAM_IMPORTS_LIST)))

ifdef SIMPLE_PROGRAM_IMPORT_PATHS
   OUR_SIMPLE_PROGRAM_LINKER_PATHS = $(addsuffix $(LDFLAGS_PATH_SUFFIX), \
                                      $(addprefix $(LDFLAGS_PATH_PREFIX), \
                                      $(foreach dir, \
                                      $(SIMPLE_PROGRAM_IMPORT_PATHS),\
                                      $(call normalizepath,$(dir)))))
endif

OUR_SIMPLE_PROGRAM_OUT = $(LDFLAGS_OUT_PREFIX)$@$(LDFLAGS_OUT_SUFFIX)

$(OUR_SIMPLE_PROGRAM): $(OUR_SIMPLE_PROGRAM_OBJS)
	$(LD) $(OUR_SIMPLE_PROGRAM_OUT) $(OUR_SIMPLE_PROGRAM_FLAGS) $(OUR_SIMPLE_PROGRAM_LINKER_PATHS) $(OUR_SIMPLE_PROGRAM_OBJS) $(OUR_LINKER_IMPORTS)

endif

#------------------------------------------------------------------------------
# Rules for pre-processed resources
#------------------------------------------------------------------------------
#
#  A target for pre-processing a list of files and a directory for those files
#  to end up at.
#
#  SONGBIRD_PP_RESOURCES - The list of files to preprocess, the target assumes
#                          that all the files in with ".in"
#
#  SONGBIRD_PP_DIR       - The target directory to put the pre-processed file
#                          list in $(SONGBIRD_PP_RESOURCES).
#
#  PP_RESOURCES_STRIP_SUFFIX  - The suffix of the files to be preprocessed; 
#                               defaults to ".in", but can be most anything,
#                               including empty.
#  
#  RESOURCES_PPFLAGS     - Command-line flags to pass to the preprocessor
#
#  PPDEFINES             - Extra definitions to pass to the preprocessor (in
#                          the form of -DFOO="bar")
#

ifeq (windows,$(SB_PLATFORM))
   RESOURCES_PPFLAGS += --line-endings=crlf
endif

ifndef PP_RESOURCES_STRIP_SUFFIX
   PP_RESOURCES_STRIP_SUFFIX = .in
endif

ifndef SONGBIRD_PP_DIR
   SONGBIRD_PP_DIR = $(CURDIR)
endif

GENERATED_PP_DEPS = $(addprefix $(SONGBIRD_PP_DIR)/,$(foreach f,$(SONGBIRD_PP_RESOURCES),$(patsubst %$(PP_RESOURCES_STRIP_SUFFIX),%,$(notdir $f))))

$(GENERATED_PP_DEPS): $(SONGBIRD_PP_RESOURCES)
   ifeq (,$(wildcard $(SONGBIRD_PP_DIR)))
	   $(MKDIR) $(SONGBIRD_PP_DIR)
   endif
	@for item in $(SONGBIRD_PP_RESOURCES); do \
      target=$(SONGBIRD_PP_DIR)/`basename $$item $(PP_RESOURCES_STRIP_SUFFIX)`; \
      echo Preprocessing $$item into $$target...; \
      $(RM) -f $$target; \
      $(PERL) $(MOZSDK_SCRIPTS_DIR)/preprocessor.pl \
       $(ACDEFINES) $(RESOURCES_PPFLAGS) \
       $(PPDEFINES) -- $$item > $$target; \
   done

export:: $(GENERATED_PP_DEPS)

#------------------------------------------------------------------------------
# Rules for chrome jar files
#------------------------------------------------------------------------------
#
# JAR_MANIFEST - The manifest file to use for creating the jar; if this file 
#                ends with '.in,' it will be pre-processed first.
#
# FORCE_JARS - Force use of JAR files.
#
# FLAT_JARS - Force use of flat JARs.
#
# MAKE_JAR_FLAGS - An override tot he flags passed to the make-jars.pl command
#
# MAKE_JAR_EXTRA_FLAGS - Extra flags to pass to the make-jars.pl command
#
# JAR_TARGET_DIR - An overide to the directory to create the jar in.
#

ifdef EXTENSION_STAGE_DIR
   JAR_IS_EXTENSION = 1
endif

# Extension jars need to go to the extensions subdirectory of the xulrunner
# folder. Otherwise everything goes into the chrome directory.

# We use flat jars (i.e. plain directories) if we have DEBUG defined and
# FORCE_JARS is _not_defined. Also use flat jars if in a release build and
# PREVENT_JARS is defined.

ifdef DEBUG
   ifneq (1,$(FORCE_JARS))
      USING_FLAT_JARS = 1
   endif
else
   ifeq (1,$(FLAT_JARS))
      USING_FLAT_JARS = 1
   endif
endif

# Allow this to be overridden
ifdef JAR_TARGET_DIR
   OUR_JAR_TARGET_DIR = $(JAR_TARGET_DIR)
else
   ifeq (1,$(JAR_IS_EXTENSION))
      OUR_JAR_TARGET_DIR = $(SONGBIRD_EXTENSIONSDIR)/$(EXTENSION_UUID)/chrome
   else
      OUR_JAR_TARGET_DIR = $(SONGBIRD_CHROMEDIR)
   endif
endif

ifdef MAKE_JARS_FLAGS
   OUR_MAKE_JARS_FLAGS = $(MAKE_JARS_FLAGS)
else
   OUR_MAKE_JARS_FLAGS = -s $(srcdir) \
                         -t $(topsrcdir) \
                         -j $(OUR_JAR_TARGET_DIR) \
                         -z $(ZIP) \
                         -p $(MOZSDK_SCRIPTS_DIR)/preprocessor.pl \
                         -v \
								 $(EXTRA_MAKE_JARS_FLAGS) \
                         $(NULL)
   ifdef USING_FLAT_JARS
      OUR_MAKE_JARS_FLAGS += -f flat -d $(OUR_JAR_TARGET_DIR)
   else
      OUR_MAKE_JARS_FLAGS += -d $(OUR_JAR_TARGET_DIR)/stage
      ALL_TRASH += $(OUR_JAR_TARGET_DIR)/stage
   endif

   ifdef JAR_IS_EXTENSION
      OUR_MAKE_JARS_FLAGS += -e
   endif
endif

ifdef USING_FLAT_JARS
   PPDEFINES += -DUSING_FLAT_JARS=$(USING_FLAT_JARS)
endif

# Check to see if the manifest file exists in the source dir. If not then we're
# going to assume it needs to be generated through preprocessing. The
# postprocessed file will be generated in the object directory.

ifeq (.in,$(suffix $(strip $(JAR_MANIFEST))))
   OUR_JAR_MN = $(patsubst %.in,%,$(strip $(JAR_MANIFEST)))
   OUR_JAR_MN_IN = $(strip $(JAR_MANIFEST))
   ALL_TRASH += $(OUR_JAR_MN)
else
   OUR_JAR_MN = $(srcdir)/$(strip $(JAR_MANIFEST))
   OUR_JAR_MN_IN = 
endif

ifdef JAR_MANIFEST
   ifneq (1,$(words $(strip JAR_MANIFEST)))
      $(error Cannot specify multiple JAR_MANIFESTs. Bailing...)
   endif
endif

# We want the preprocessor to run every time regrdless of whether or not
# $(OUR_JAR_MN_IN) has changed because defines may change as well.
$(OUR_JAR_MN): FORCE
ifneq (,$(OUR_JAR_MN_IN))
	$(RM) $(OUR_JAR_MN)
	$(PERL) $(MOZSDK_SCRIPTS_DIR)/preprocessor.pl $(ACDEFINES) $(PPDEFINES) -- \
    $(srcdir)/$(OUR_JAR_MN_IN) | \
    $(PERL) $(SCRIPTS_DIR)/expand-jar-mn.pl $(srcdir) > $(OUR_JAR_MN)
endif

# preedTODO: when we have a JAR_MANIFEST, actually look at it to figure out
# what the real dependency should be.
libs:: $(if $(JAR_MANIFEST),$(OUR_JAR_MN)) $(CHROME_DEPS)
ifdef JAR_MANIFEST
	$(MKDIR) $(OUR_JAR_TARGET_DIR)
	$(PERL) -I$(MOZSDK_SCRIPTS_DIR) $(MOZSDK_SCRIPTS_DIR)/make-jars.pl \
    $(OUR_MAKE_JARS_FLAGS) -- $(ACDEFINES) $(PPDEFINES) < $(OUR_JAR_MN)
	$(RM) -r $(OUR_JAR_TARGET_DIR)/stage
endif

#------------------------------------------------------------------------------
# Rules for creating XPIs
#------------------------------------------------------------------------------

# XPI_NAME - The base name (no extension) of the XPI to create. To do this you
#            must also set the following variables:
#
#              EXTENSION_STAGE_DIR - dir where the XPIs contents reside
#              EXTENSION_NAME - name of the extension (coolthing)
#
#            You must have 'install.rdf' in your src directory OR you can use
#            the preprocessor to create one. To do that either name your input
#            file 'install.rdf.in' or specify its name with the following:
#
#              INSTALL_RDF -  the name of the input file that will be passed to
#                             the preprocessor to create 'install.rdf'
#
#            If you use the preprocessor you may want to also set the
#            following variables:
#
#              EXTENSION_UUID    - uuid of the extension
#                                  (e.g. "coolthing@example.com")
#              EXTENSION_ARCH    - arch string describing the build machine
#                                  (e.g. "WINNT_x86-msvc" or "Darwin_x86-gcc4")
#              EXTENSION_VER     - extension version
#                                  (e.g. "1.2.3")
#              EXTENSION_MIN_VER - minimum version of application needed for 
#                                  extension (e.g. "0.7pre")
#              EXTENSION_MAX_VER - maximum version of application needed for 
#                                  extension (e.g. "0.7.*")
#
#            If you want to also install the contents of the XPI to the
#            extensions directory then you may set the following variable:
#
#              INSTALL_EXTENSION - whether or not to install the XPI
#
#            Note that INSTALL_EXTENSION requires that EXTENSION_UUID be set
#
#            You may override this variable if you want the output of the
#            extension build process to output your xpi to a different location
#            than standard. Defaults to OBJDIR/xpi-stage/EXTENSION_NAME. You
#            wouldn't normally want to do this.
#
#              EXTENSION_DIR - dir where the final XPI should be moved
#

# set a specific location for the output if it doesn't already exist
EXTENSION_DIR ?= $(SONGBIRD_OBJDIR)/xpi-stage/$(EXTENSION_NAME)
EXTENSION_LICENSE ?= $(wildcard $(srcdir)/LICENSE)

ifdef EXTENSION_VER
   ifeq (_,$(SONGBIRD_OFFICIAL)_$(SONGBIRD_NIGHTLY))
      OUR_EXTENSION_VER = $(EXTENSION_VER)+dev
   else
      OUR_EXTENSION_VER = $(EXTENSION_VER).$(SB_BUILD_NUMBER)
   endif
endif

ifdef EXTENSION_NAME
   ifndef INSTALL_RDF
	   # The notdir is because this is to check if these files exist, but
		# we have to do in the srcdir; but we really only want the file name
      POSSIBLE_INSTALL_RDF = $(notdir $(wildcard $(srcdir)/install.rdf))
      POSSIBLE_INSTALL_RDF_IN = $(notdir $(wildcard $(srcdir)/install.rdf.in))

      ifneq (,$(POSSIBLE_INSTALL_RDF))
         INSTALL_RDF = $(POSSIBLE_INSTALL_RDF)
      endif
      ifneq (,$(POSSIBLE_INSTALL_RDF_IN))
         INSTALL_RDF = $(POSSIBLE_INSTALL_RDF_IN)
      endif
   endif

   ifeq (,$(INSTALL_RDF))
      $(error Could not detect an install.rdf; set it explicitily using INSTALL_RDF)
   endif

   ifeq (.in,$(suffix $(strip $(INSTALL_RDF))))
      OUR_INSTALL_RDF = $(patsubst %.in,%,$(strip $(INSTALL_RDF)))
      OUR_INSTALL_RDF_IN = $(strip $(srcdir)/$(INSTALL_RDF))
      ALL_TRASH += $(OUR_INSTALL_RDF)
   else
      OUR_INSTALL_RDF = $(strip $(srcdir)/$(INSTALL_RDF))
      OUR_INSTALL_RDF_IN =
   endif

   ifdef XPI_NAME
      OUR_XPI_NAME = $(XPI_NAME)
   else
      ifdef EXTENSION_ARCH
         OUR_XPI_NAME = $(EXTENSION_NAME)-$(OUR_EXTENSION_VER)-$(SB_PLATFORM)-$(SB_ARCH)$(DEBUG:%=-debug)
      else
         OUR_XPI_NAME = $(EXTENSION_NAME)-$(OUR_EXTENSION_VER)$(DEBUG:%=-debug)
      endif
   endif
endif

#preedTODO; set INSTALL_EXTENSION to 1 if debug, unless that's disabled

$(OUR_INSTALL_RDF): $(OUR_INSTALL_RDF_IN)
	$(PERL) $(MOZSDK_SCRIPTS_DIR)/preprocessor.pl \
    $(ACDEFINES) $(PPDEFINES) \
    -DEXTENSION_ARCH="$(EXTENSION_ARCH)" \
    -DEXTENSION_UUID="$(EXTENSION_UUID)" \
    -DEXTENSION_VER="$(OUR_EXTENSION_VER)" \
    -DEXTENSION_MIN_VER="$(EXTENSION_MIN_VER)" \
    -DEXTENSION_MAX_VER="$(EXTENSION_MAX_VER)" \
    -DEXTENSION_NAME=$(EXTENSION_NAME) -- \
    $(OUR_INSTALL_RDF_IN) > $(OUR_INSTALL_RDF)

# Check for an extension license; default file name is "LICENSE" in the root
# directory of the extension. You can override this by setting EXTENSION_LICENSE
# in the extension's Makefile

export:: $(if $(EXTENSION_NAME), $(OUR_INSTALL_RDF))
ifdef EXTENSION_NAME
	$(MKDIR) $(EXTENSION_STAGE_DIR)
endif

libs:: $(if $(EXTENSION_NAME), $(OUR_SUBDIRS) $(if $(JAR_MANIFEST),$(OUR_JAR_MN)))
ifdef EXTENSION_NAME
	@echo packaging $(EXTENSION_DIR)/$(OUR_XPI_NAME).xpi
	$(RM) -f $(EXTENSION_DIR)/$(OUR_XPI_NAME).xpi
	$(INSTALL_FILE) $(OUR_INSTALL_RDF) $(EXTENSION_STAGE_DIR)/install.rdf
   ifneq (,$(EXTENSION_LICENSE))
	   $(INSTALL_FILE) $(EXTENSION_LICENSE) $(EXTENSION_STAGE_DIR)
   endif
	cd $(EXTENSION_STAGE_DIR) && $(ZIP) -qr ../$(OUR_XPI_NAME).xpi.tmp *
	$(MKDIR) $(EXTENSION_DIR)
	$(MV) -f $(EXTENSION_STAGE_DIR)/../$(OUR_XPI_NAME).xpi.tmp \
    $(EXTENSION_DIR)/$(OUR_XPI_NAME).xpi
   ifdef INSTALL_EXTENSION
	   $(MKDIR) $(SONGBIRD_EXTENSIONSDIR)
	   $(RM) -r $(SONGBIRD_EXTENSIONSDIR)/$(EXTENSION_UUID)
	   $(CP) -rf $(EXTENSION_STAGE_DIR) $(SONGBIRD_EXTENSIONSDIR)/$(EXTENSION_UUID)
   endif
endif


ifdef EXTENSION_NAME
   ALL_TRASH += $(EXTENSION_DIR)/$(OUR_XPI_NAME).xpi \
                $(if $(OUR_INSTALL_RDF_IN), $(OUR_INSTALL_RDF)) \
                $(EXTENSION_STAGE_DIR) \
                $(NULL)
endif

#------------------------------------------------------------------------------
# Utilities
#------------------------------------------------------------------------------

# from mozilla/config/rules.mk (the Java rules section)
# note that an extra slash was added between root-path and non-root-path to
# account for non-standard mount points in msys
# (C:/ vs C:/foo with missing trailing slash)
# Cygwin and MSYS have their own special path form, but manifest tool expects
# them to be in the DOS form (i.e. e:/builds/...).  This function
# does the appropriate conversion on Windows, but is a noop on other systems.
ifeq (windows,$(SB_PLATFORM))
   # We use 'pwd -W' to get DOS form of the path.  However, since the given path
   # could be a file or a non-existent path, we cannot call 'pwd -W' directly
   # on the path.  Instead, we extract the root path (i.e. "c:/"), call 'pwd -W'
   # on it, then merge with the rest of the path.
   root-path = $(shell echo $(1) | sed -e "s|\(/[^/]*\)/\?\(.*\)|\1|")
   non-root-path = $(shell echo $(1) | sed -e "s|\(/[^/]*\)/\?\(.*\)|\2|")
   normalizepath = $(if $(filter /%,$(1)),$(shell cd $(call root-path,$(1)) && pwd -W)/$(call non-root-path,$(1)),$(1))
else
   normalizepath = $(1)
endif


#########################

echo-variable-%:
	@echo $($*)

echo-tiers:
	@echo $(TIERS)

echo-subdirs:
	@echo SUBDIRS: $(SUBDIRS)
ifneq ($(SUBDIRS),$(OUR_SUBDIRS))
	@echo OUR_SUBDIRS: $(OUR_SUBDIRS)
endif

FORCE:

# Cancel these implicit rules

%: %,v

%: RCS/%,v

%: RCS/%

%: s.%

%: SCCS/s.%

# Re-define the list of default suffixes, so gmake won't have to churn through
# hundreds of built-in suffix rules for stuff we don't need.

.SUFFIXES:

.PHONY: $(OUR_SUBDIRS) FORCE libs export

include $(topsrcdir)/build/file-autotargets.mk

#------------------------------------------------------------------------------
endif #RULES_MK_INCLUDED
#------------------------------------------------------------------------------
