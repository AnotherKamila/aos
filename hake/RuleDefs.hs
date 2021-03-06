-------------------------------------------------------------------------
-- Copyright (c) 2007-2011, 2012, 2015 ETH Zurich.
-- All rights reserved.
--
-- This file is distributed under the terms in the attached LICENSE file.
-- If you do not find this file, copies can be found by writing to:-
-- ETH Zurich D-INFK CAB F.78, Universitaetstr 6, CH-8092 Zurich.
-- Attn: Systems Group.
--
-- Basic Hake rule definitions and combinators
--
--------------------------------------------------------------------------

module RuleDefs where
import Data.List (intersect, isSuffixOf, union, (\\), nub, sortBy, elemIndex)
import Data.Maybe (fromMaybe)
import System.FilePath
import qualified ARMv7
import HakeTypes
import qualified Args
import qualified Config
import TreeDB

import Debug.Trace
-- enable debug spew
-- should we move this to Config.hs? -AB
debugFlag = False

--
-- Is a token to be displayed in a rule?
--
inRule :: RuleToken -> Bool
inRule (Dep _ _ _) = False
inRule (PreDep _ _ _) = False
inRule (Target _ _) = False
inRule _ = True

--
-- Look for a set of files: this is called using the "find" combinator
--
withSuffix :: TreeDB -> String -> String -> [String]
withSuffix srcDB hakepath extension =
    map (\f -> "/" </> f) $
        fromMaybe [] $ tdbByDirExt (takeDirectory hakepath) extension srcDB

withSuffices :: TreeDB -> String -> [String] -> [String]
withSuffices srcDB hakepath extensions =
    map (\f -> "/" </> f) $
        fromMaybe [] $ tdbByDirExts (takeDirectory hakepath) extensions srcDB

--
-- Find files with a given suffix in a given dir
--
inDir :: TreeDB -> String -> String -> String -> [String]
inDir srcDB hakepath dir extension =
    map (\f -> "/" </> f) $
        fromMaybe [] $
            tdbByDirExt (dropTrailingPathSeparator $ normalise $
                            takeDirectory hakepath </> dir)
                        extension srcDB

cInDir :: TreeDB -> String -> String -> [String]
cInDir tdb tf dir = inDir tdb tf dir ".c"

sInDir :: TreeDB -> String -> String -> [String]
sInDir tdb tf dir = inDir tdb tf dir ".S"

-------------------------------------------------------------------------
--
-- Architecture specific definitions
--
-------------------------------------------------------------------------

options :: String -> Options
options "armv7" = ARMv7.options
options s = error $ "Unknown architecture " ++ s

kernelCFlags "armv7" = ARMv7.kernelCFlags
kernelCFlags s = error $ "Unknown architecture " ++ s

kernelLdFlags "armv7" = ARMv7.kernelLdFlags
kernelLdFlags s = error $ "Unknown architecture " ++ s

archFamily :: String -> String
archFamily arch = optArchFamily (options arch)

-------------------------------------------------------------------------
--
-- Options for compiling the kernel, which is special
--
-------------------------------------------------------------------------

kernelOptIncludes :: String -> [ RuleToken ]
kernelOptIncludes arch = [ ]

kernelIncludes arch = [ NoDep BuildTree arch f | f <- [
                    "/include" ]]
                 ++
                 [ NoDep SrcTree "src" f | f <- [
                    "/kernel/include/arch" </> arch,
                    "/kernel/include/arch" </> archFamily arch,
                    "/kernel/include",
                    "/include",
                    "/include/arch" </> archFamily arch,
                    "/lib/newlib/newlib/libc/include",
                    "/include/c",
                    "/include/target" </> archFamily arch]]
                 ++ kernelOptIncludes arch

kernelOptions arch = Options {
            optArch = arch,
            optArchFamily = archFamily arch,
            optFlags = kernelCFlags arch,
            optCxxFlags = [],
            optDefines = (optDefines (options arch)) ++ [ Str "-DIN_KERNEL",
                Str ("-DCONFIG_SCHEDULER_" ++ (show Config.scheduler)),
                Str ("-DCONFIG_TIMESLICE=" ++ (show Config.timeslice)) ],
            optIncludes = kernelIncludes arch,
            optDependencies =
                [ Dep InstallTree arch "/include/errors/errno.h",
                  Dep InstallTree arch "/include/barrelfish_kpi/capbits.h",
                  Dep InstallTree arch "/include/asmoffsets.h" ],
            optLdFlags = kernelLdFlags arch,
            optLdCxxFlags = [],
            optLibs = [],
            optCxxLibs = [],
            optSuffix = [],
            optInterconnectDrivers = [],
            optFlounderBackends = [],
            extraFlags = [],
            extraCxxFlags = [],
            extraDefines = [],
            extraIncludes = [],
            extraDependencies = [],
            extraLdFlags = []
          }


-------------------------------------------------------------------------
--
-- IMPORTANT: This section contains extraction of functions from the
-- relevant architecture module.  The names and types should be
-- exactly the same as in the architecture.hs file.  This section
-- should not contain any logic; ony architecture extraction.
--
--------------------------------------------------------------------------

--
-- First, the default C compiler for an architecture
--

compiler :: Options -> String
compiler opts
    | optArch opts == "armv7" = ARMv7.compiler

cCompiler :: Options -> String -> String -> String -> [ RuleToken ]
cCompiler opts phase src obj
    | optArch opts == "armv7" = ARMv7.cCompiler opts phase src obj
    | otherwise = [ ErrorMsg ("no C compiler for " ++ (optArch opts)) ]

cPreprocessor :: Options -> String -> String -> String -> [ RuleToken ]
cPreprocessor opts phase src obj
    | otherwise = [ ErrorMsg ("no C preprocessor for " ++ (optArch opts)) ]


--
-- makeDepend step; note that obj can be whatever the intended output is
--
makeDepend :: Options -> String -> String -> String -> String -> [ RuleToken ]
makeDepend opts phase src obj depfile
    | optArch opts == "armv7" = 
        ARMv7.makeDepend opts phase src obj depfile
    | otherwise = [ ErrorMsg ("no dependency generator for " ++ (optArch opts)) ]

cToAssembler :: Options -> String -> String -> String -> String -> [ RuleToken ]
cToAssembler opts phase src afile objdepfile
    | optArch opts == "armv7" = ARMv7.cToAssembler opts phase src afile objdepfile
    | otherwise = [ ErrorMsg ("no C compiler for " ++ (optArch opts)) ]

--
-- Assemble an assembly language file
--
assembler :: Options -> String -> String -> [ RuleToken ]
assembler opts src obj
    | optArch opts == "armv7" = ARMv7.assembler opts src obj
    | otherwise = [ ErrorMsg ("no assembler for " ++ (optArch opts)) ]

archive :: Options -> [String] -> [String] -> String -> String -> [ RuleToken ]
archive opts objs libs name libname
    | optArch opts == "armv7" = ARMv7.archive opts objs libs name libname
    | otherwise = [ ErrorMsg ("Can't build a library for " ++ (optArch opts)) ]

linker :: Options -> [String] -> [String] -> String -> [RuleToken]
linker opts objs libs bin
    | optArch opts == "armv7" = ARMv7.linker opts objs libs bin
    | otherwise = [ ErrorMsg ("Can't link executables for " ++ (optArch opts)) ]

strip :: Options -> String -> String -> String -> [RuleToken]
strip opts src debuglink target
    | optArch opts == "armv7" = ARMv7.strip opts src debuglink target
    | otherwise = [ ErrorMsg ("Can't strip executables for " ++ (optArch opts)) ]

debug :: Options -> String -> String -> [RuleToken]
debug opts src target
    | optArch opts == "armv7" = ARMv7.debug opts src target
    | otherwise = [ ErrorMsg ("Can't extract debug symbols for " ++ (optArch opts)) ]

--
-- The C compiler for compiling things on the host
--
nativeCCompiler :: String
nativeCCompiler = "$(CC)"

nativeArchiver :: String
nativeArchiver = "ar"

-------------------------------------------------------------------------
--
-- Functions to create useful filenames
--

dependFilePath :: String -> String
dependFilePath obj = obj ++ ".depend"

objectFilePath :: Options -> String -> String
objectFilePath opts src = optSuffix opts </> replaceExtension src ".o"

generatedObjectFilePath :: Options -> String -> String
generatedObjectFilePath opts src = replaceExtension src ".o"

preprocessedFilePath :: Options -> String -> String
preprocessedFilePath opts src = optSuffix opts </> replaceExtension src ".i"

-- Standard convention is that human generated assembler is .S, machine generated is .s
assemblerFilePath :: Options -> String -> String
assemblerFilePath opts src = optSuffix opts </> replaceExtension src ".s"


-------------------------------------------------------------------------
--
-- Functions with logic to start doing things
--

--
-- Create C file dependencies
--

-- Since this is where we know what the depfile is called it is here that we also
-- decide to include it.  This stops many different places below trying to
-- guess what the depfile is called
--
makeDependArchSub :: Options -> String -> String -> String -> String -> [ RuleToken ]
makeDependArchSub opts phase src objfile depfile =
   [ Str ("@if [ -z $Q ]; then echo Generating $@; fi"), NL ] ++
     makeDepend opts phase src objfile depfile

makeDependArch :: Options -> String -> String -> String -> String -> HRule
makeDependArch opts phase src objfile depfile =
    Rules [ Rule (makeDependArchSub opts phase src objfile depfile),
            Include (Out (optArch opts) depfile)
          ]

-- Make depend for a standard object file
makeDependObj :: Options -> String -> String -> HRule
makeDependObj opts phase src =
    let objfile = (objectFilePath opts src)
    in
      makeDependArch opts phase src objfile (dependFilePath objfile)

-- Make depend for an assembler output
makeDependAssembler :: Options -> String -> String -> HRule
makeDependAssembler opts phase src =
    let objfile = (assemblerFilePath opts src)
    in
      makeDependArch opts phase src objfile (dependFilePath objfile)

--
-- Compile a C program to assembler
--
makecToAssembler :: Options -> String -> String -> String -> [ RuleToken ]
makecToAssembler opts phase src obj =
    cToAssembler opts phase src (assemblerFilePath opts src) (dependFilePath obj)

--
-- Assemble an assembly language file
--
assemble :: Options -> String -> [ RuleToken ]
assemble opts src =
    assembler opts src (objectFilePath opts src)

--
-- Create a library from a set of object files
--
archiveLibrary :: Options -> String -> [String] -> [String] -> [ RuleToken ]
archiveLibrary opts name objs libs =
    archive opts objs libs name (libraryPath name)

--
-- Link an executable
--
linkExecutable :: Options -> [String] -> [String] -> String -> [RuleToken]
linkExecutable opts objs libs bin =
    linker opts objs libs (applicationPath bin)

--
-- Strip debug symbols from an executable
--
stripExecutable :: Options -> String -> String -> String -> [RuleToken]
stripExecutable opts src debuglink target =
    strip opts (applicationPath src) (applicationPath debuglink)
               (applicationPath target)

--
-- Extract debug symbols from an executable
--
debugExecutable :: Options -> String -> String -> [RuleToken]
debugExecutable opts src target =
    debug opts (applicationPath src) (applicationPath target)

-------------------------------------------------------------------------





-------------------------------------------------------------------------
--
-- Hake macros (hacros?): each of these evaluates to HRule, i.e. a
-- list of templates for Makefile rules
--
-------------------------------------------------------------------------

--
-- Compile a C file for a particular architecture
-- We include cToAssembler to permit humans to type "make foo/bar.s"
--
compileCFile :: Options -> String -> HRule
compileCFile opts src =
    Rules [ Rule (cCompiler opts "src" src (objectFilePath opts src)),
            Rule (makecToAssembler opts "src" src (objectFilePath opts src)),
            makeDependObj opts "src" src
          ]

--
-- Compile a C file for a particular architecture
--
compileGeneratedCFile :: Options -> String -> HRule
compileGeneratedCFile opts src =
    let o2 = opts { optSuffix = "" }
        arch = optArch o2
    in
      Rules [ Rule (cCompiler o2 arch src (objectFilePath o2 src) ),
              Rule (makecToAssembler o2 arch src (objectFilePath o2 src)),
              makeDependObj o2 arch src
            ]

compileCFiles :: Options -> [String] -> HRule
compileCFiles opts srcs = Rules [ compileCFile opts s | s <- srcs ]
compileGeneratedCFiles :: Options -> [String] -> HRule
compileGeneratedCFiles opts srcs =
    Rules [ compileGeneratedCFile opts s | s <- srcs ]

--
-- Add a set of C (or whatever) dependences on a *generated* file.
-- Somewhere else this file has to be defined as a target, of
-- course...
--
extraCDependencyForObj :: Options -> String -> String -> String -> [RuleToken]
extraCDependencyForObj opts file s obj =
    let arch = optArch opts
    in
      [ Target arch (dependFilePath obj),
        Target arch obj,
        Dep BuildTree arch file
      ]

extraCDependency :: Options -> String -> String -> HRule
extraCDependency opts file s = Rule (extraCDependencyForObj opts file s obj)
    where obj = objectFilePath opts s


extraCDependencies :: Options -> String -> [String] -> HRule
extraCDependencies opts file srcs =
    Rules [ extraCDependency opts file s | s <- srcs ]

extraGeneratedCDependency :: Options -> String -> String -> HRule
extraGeneratedCDependency opts file s =
    extraCDependency (opts { optSuffix = "" }) file s

--
-- Copy include files to the appropriate directory
--
includeFile :: Options -> String -> HRule
includeFile opts hdr =
    Rules [ (Rule [ Str "cp", In SrcTree "src" hdr, Out (optArch opts) hdr ]),
            (Rule [ PreDep BuildTree (optArch opts) hdr,
                    Target (optArch opts) "/include/errors/errno.h" ]
            )
          ]

--
-- Build a Mackerel header file from a definition.
--
mackerelProgLoc = In InstallTree "tools" "/bin/mackerel"
mackerelDevFileLoc d = In SrcTree "src" ("/devices" </> (d ++ ".dev"))
mackerelDevHdrPath d = "/include/dev/" </> (d ++ "_dev.h")

mackerel2 :: Options -> String -> HRule
mackerel2 opts dev = mackerel_generic opts dev "shift-driver"

mackerel :: Options -> String -> HRule
mackerel opts dev = mackerel_generic opts dev "bitfield-driver"

mackerel_generic :: Options -> String -> String -> HRule
mackerel_generic opts dev flag =
    let
        arch = optArch opts
    in
      Rule [ mackerelProgLoc,
             Str ("--" ++ flag),
             Str "-c", mackerelDevFileLoc dev,
             Str "-o", Out arch (mackerelDevHdrPath dev)
           ]

mackerelDependencies :: Options -> String -> [String] -> HRule
mackerelDependencies opts d srcs =
    extraCDependencies opts (mackerelDevHdrPath d) srcs

applicationPath name = "/sbin" </> name
libraryPath libname = "/lib" </> ("lib" ++ libname ++ ".a")
kernelPath = "/sbin/cpu"

--
-- Build a Fugu library
--
fuguCFile :: Options -> String -> HRule
fuguCFile opts file =
    let arch = optArch opts
        cfile = file ++ ".c"
    in
      Rules [ Rule [ In InstallTree "tools" "/bin/fugu",
                     In SrcTree "src" (file++".fugu"),
                     Str "-c",
                     Out arch cfile ],
              compileGeneratedCFile opts cfile
         ]

fuguHFile :: Options -> String -> HRule
fuguHFile opts file =
    let arch = optArch opts
        hfile = "/include/errors/" ++ file ++ ".h"
    in
      Rule [ In InstallTree "tools" "/bin/fugu",
             In SrcTree "src" (file++".fugu"),
             Str "-h",
             Out arch hfile ]

--
-- Build a Hamlet file
--
hamletFile :: Options -> String -> HRule
hamletFile opts file =
    let arch = optArch opts
        hfile = "/include/barrelfish_kpi/capbits.h"
        cfile = "cap_predicates.c"
        usercfile = "user_cap_predicates.c"
        ofile = "user_cap_predicates.o"
        nfile = "cap_predicates"
        afile = "/lib/libcap_predicates.a"
    in
      Rules [ Rule [In InstallTree "tools" "/bin/hamlet",
                    In SrcTree "src" (file++".hl"),
                    Out arch hfile,
                    Out arch cfile,
                    Out arch usercfile ],
              compileGeneratedCFile opts usercfile,
              Rule (archive opts [ ofile ] [] nfile afile)
         ]

--
-- Link a set of object files and libraries together
--
link :: Options -> [String] -> [ String ] -> String -> HRule
link opts objs libs bin =
    let full = bin ++ ".full"
        debug = bin ++ ".debug"
    in Rules [
        Rule $ linkExecutable opts objs libs full,
        Rule $ debugExecutable opts full debug,
        Rule $ stripExecutable opts full debug bin
    ]

--
-- Link a CPU driver.  This is where it gets distinctly architecture-specific.
--
linkKernel :: Options -> String -> [String] -> [String] -> String -> HRule
linkKernel opts name objs libs driverType
    | optArch opts == "armv7" = ARMv7.linkKernel opts objs [libraryPath l | l <- libs ] name driverType
    | otherwise = Rule [ Str ("Error: Can't link kernel for '" ++ (optArch opts) ++ "'") ]

--
-- Copy a file from one place to another
--
copy :: Options -> String -> String -> HRule
copy opts src dest =
    Rule [ Str "cp", In BuildTree (optArch opts) src, Out (optArch opts) dest ]

--
-- Assemble a list of S files for a particular architecture
--
assembleSFile :: Options -> String -> HRule
assembleSFile opts src =
    Rules [ Rule (assemble opts src),
            makeDependObj opts "src" src
          ]

assembleSFiles :: Options -> [String] -> HRule
assembleSFiles opts srcs = Rules [ assembleSFile opts s | s <- srcs ]

--
-- Archive a bunch of objects into a library
--
staticLibrary :: Options -> String -> [String] -> [String] -> HRule
staticLibrary opts libpath objs libs =
    Rule (archiveLibrary opts libpath objs libs)

--
-- Compile a Haskell binary (for the host architecture)
--
compileHaskell prog main deps = compileHaskellWithLibs prog main deps []
compileHaskellWithLibs prog main deps dirs =
  let
    tools_dir = (Dep InstallTree "tools" "/tools/.marker")
  in
    Rule ([ NStr "ghc -i",
            NoDep SrcTree "src" ".",
            Str "-odir ", NoDep BuildTree "tools" ".",
            Str "-hidir ", NoDep BuildTree "tools" ".",
            Str "-rtsopts=all",
            Str "--make ",
            In SrcTree "src" main,
            Str "-o ",
            Out "tools" ("/bin" </> prog),
            Str "$(LDFLAGS)" ]
          ++ concat [[ NStr "-i", NoDep SrcTree "src" d] | d <- dirs]
          ++ [ (Dep SrcTree "src" dep) | dep <- deps ]
          ++ [ tools_dir ])

nativeOptions = Options {
      optArch                = "",
      optArchFamily          = "",
      optFlags               = [],
      optCxxFlags            = [],
      optDefines             = [],
      optIncludes            = [],
      optDependencies        = [],
      optLdFlags             = [],
      optLdCxxFlags          = [],
      optLibs                = [],
      optCxxLibs             = [],
      optInterconnectDrivers = [],
      optFlounderBackends    = [],
      extraFlags             = [],
      extraCxxFlags          = [],
      extraDefines           = [],
      extraIncludes          = [],
      extraDependencies      = [],
      extraLdFlags           = [],
      optSuffix              = ""
    }

--
-- Compile (and link) a C binary (for the host architecture)
--
compileNativeC :: String -> [String] -> [String] -> [String] -> [String] ->
                  HRule
compileNativeC prog cfiles cflags ldflags localLibs =
    Rule ([ Str nativeCCompiler,
            Str "-o",
            Out "tools" ("/bin" </> prog),
            Str "$(CFLAGS)",
            Str "$(LDFLAGS)" ]
          ++ [ (Str flag) | flag <- cflags ]
          ++ [ (In SrcTree "src" dep) | dep <- cfiles ]
          -- source file needs to be left of ldflags for modern-ish GCC
          ++ [ (Str flag) | flag <- ldflags ]
          ++ [ In BuildTree "tools" ("/lib" </> ("lib" ++ l ++ ".a")) |
               l <- localLibs ])

--
-- Compile a static library for the host architecture
--
compileNativeLib :: String -> [String] -> [String] -> HRule
compileNativeLib name cfiles cflags =
    Rules (
        [ Rule ([ Str nativeCCompiler,
                  Str "-c", In SrcTree "src" s,
                  Str "-o", Out "tools" (objectFilePath nativeOptions s),
                  Str "$(CFLAGS)",
                  Str "$(LDFLAGS)" ]
                ++ [ (Str flag) | flag <- cflags ])
            | s <- cfiles ] ++
        [ Rule ([ Str nativeArchiver,
                  Str "rcs",
                  Out "tools" ("/lib" </> ("lib" ++ name ++ ".a")) ] ++
                [ In BuildTree "tools" o | o <- objs ]) ]
        )
    where
        objs = [ objectFilePath nativeOptions s | s <- cfiles ]
--
-- Build a Technical Note
--
buildTechNote :: String -> String -> Bool -> Bool -> [String] -> HRule
buildTechNote input output bib glo figs =
    buildTechNoteWithDeps input output bib glo figs []
buildTechNoteWithDeps :: String -> String -> Bool -> Bool -> [String] -> [RuleToken] -> HRule
buildTechNoteWithDeps input output bib glo figs deps =
    let
        working_dir = NoDep BuildTree "tools" "/tmp/"
        style_files = [ "bfish-logo.pdf", "bftn.sty", "defs.bib", "barrelfish.bib" ]
    in
      Rule ( [ Dep SrcTree "src" (f ++ ".pdf") | f <- figs]
             ++
             [ Dep SrcTree "src" ("/doc/style" </> f) | f <- style_files ]
             ++
             [ Str "mkdir", Str "-p", working_dir, NL ]
             ++
             deps
             ++
             [ In SrcTree "src" "/tools/run-pdflatex.sh",
               Str "--input-tex", In SrcTree "src" input,
               Str "--working-dir", working_dir,
               Str "--output-pdf", Out "docs" ("/" ++ output),
               Str "--texinput", NoDep SrcTree "src" "/doc/style",
               Str "--bibinput", NoDep SrcTree "src" "/doc/style"
             ]
             ++ (if bib then [ Str "--has-bib" ] else [])
             ++ (if glo then [ Str "--has-glo" ] else [])
           )

---------------------------------------------------------------------
--
-- Transformations on file names
--
----------------------------------------------------------------------

allObjectPaths :: Options -> Args.Args -> [String]
allObjectPaths opts args =
    [objectFilePath opts g
         | g <- (Args.cFiles args)++(Args.assemblyFiles args)]
    ++
    [generatedObjectFilePath opts g
         | g <- (Args.generatedCFiles args)
    ]

allLibraryPaths :: Args.Args -> [String]
allLibraryPaths args =
    [ libraryPath l | l <- Args.addLibraries args ]


---------------------------------------------------------------------
--
-- Very large-scale macros
--
----------------------------------------------------------------------

--
-- Build an application binary
--

application :: Args.Args
application = Args.defaultArgs { Args.buildFunction = applicationBuildFn }

applicationBuildFn :: TreeDB -> String -> Args.Args -> HRule
applicationBuildFn tdb tf args
    | debugFlag && trace (Args.showArgs (tf ++ " Application ") args) False
        = undefined
applicationBuildFn tdb tf args =
    Rules [ appBuildArch tdb tf args arch | arch <- Args.architectures args ]

appGetOptionsForArch arch args =
    (options arch) { extraIncludes =
                         [ NoDep SrcTree "src" a | a <- Args.addIncludes args]
                         ++
                         [ NoDep BuildTree arch a | a <- Args.addGeneratedIncludes args],
                     optIncludes = (optIncludes $ options arch) \\
                         [ NoDep SrcTree "src" i | i <- Args.omitIncludes args ],
                     optFlags = (optFlags $ options arch) \\
                                [ Str f | f <- Args.omitCFlags args ],
                     optCxxFlags = (optCxxFlags $ options arch) \\
                                   [ Str f | f <- Args.omitCxxFlags args ],
                     optSuffix = "_for_app_" ++ Args.target args,
                     extraFlags = Args.addCFlags args,
                     extraCxxFlags = Args.addCxxFlags args,
                     extraLdFlags = [ Str f | f <- Args.addLinkFlags args ],
                     extraDependencies =
                         [Dep BuildTree arch s |
                            s <- Args.addGeneratedDependencies args]
                   }

appBuildArch tdb tf args arch =
    let -- Fiddle the options
        opts = appGetOptionsForArch arch args
        csrcs = Args.cFiles args
        gencsrc = Args.generatedCFiles args
        appname = Args.target args
    in
      Rules ( [ mackerelDependencies opts m csrcs | m <- Args.mackerelDevices args ]
              ++
              [ compileCFiles opts csrcs,
                compileGeneratedCFiles opts gencsrc,
                assembleSFiles opts (Args.assemblyFiles args),
                link opts (allObjectPaths opts args) (allLibraryPaths args) appname
              ]
            )

--
-- Build a static library
--

library :: Args.Args
library = Args.defaultArgs { Args.buildFunction = libraryBuildFn }

libraryBuildFn :: TreeDB -> String -> Args.Args -> HRule
libraryBuildFn tdb tf args | debugFlag && trace (Args.showArgs (tf ++ " Library ") args) False = undefined
libraryBuildFn tdb tf args =
    Rules [ libBuildArch tdb tf args arch | arch <- Args.architectures args ]

libGetOptionsForArch arch args =
    (options arch) { extraIncludes =
                         [ NoDep SrcTree "src" a | a <- Args.addIncludes args],
                     optIncludes = (optIncludes $ options arch) \\
                         [ NoDep SrcTree "src" i | i <- Args.omitIncludes args ],
                     optFlags = (optFlags $ options arch) \\
                                [ Str f | f <- Args.omitCFlags args ],
                     optCxxFlags = (optCxxFlags $ options arch) \\
                                   [ Str f | f <- Args.omitCxxFlags args ],
                     optSuffix = "_for_lib_" ++ Args.target args,
                     extraFlags = Args.addCFlags args,
                     extraCxxFlags = Args.addCxxFlags args,
                     extraDependencies =
                         [Dep BuildTree arch s | s <- Args.addGeneratedDependencies args]
                   }

libBuildArch tdb tf args arch =
    let -- Fiddle the options
        opts = libGetOptionsForArch arch args
        csrcs = Args.cFiles args
        gencsrc = Args.generatedCFiles args
    in
      Rules ( [ mackerelDependencies opts m csrcs | m <- Args.mackerelDevices args ]
              ++
              [ compileCFiles opts csrcs,
                compileGeneratedCFiles opts gencsrc,
                assembleSFiles opts (Args.assemblyFiles args),
                staticLibrary opts (Args.target args) (allObjectPaths opts args) (allLibraryPaths args)
              ]
            )

--
-- Library dependecies
--

-- The following code is under heavy construction, and also somewhat ugly
data LibDepTree = LibDep String | LibDeps [LibDepTree] deriving (Show,Eq)

-- manually add dependencies for now (it would be better if each library
-- defined each own dependencies locally, but that does not seem to be an
-- easy thing to do currently
libposixcompat_deps   = LibDeps [ LibDep "posixcompat",
                                  (libvfs_deps_all "vfs"), LibDep "term_server" ]
liblwip_deps          = LibDeps $ [ LibDep x | x <- deps ]
    where deps = ["lwip" ,"contmng" ,"net_if_raw" ,"timer" ,"hashtable"]
libnetQmng_deps       = LibDeps $ [ LibDep x | x <- deps ]
    where deps = ["net_queue_manager", "contmng" ,"procon" , "net_if_raw", "bfdmuxvm"]
libnfs_deps           = LibDeps $ [ LibDep "nfs", liblwip_deps]
libssh_deps           = LibDeps [ libposixcompat_deps, libopenbsdcompat_deps,
                                  LibDep "zlib", LibDep "crypto", LibDep "ssh" ]
libopenbsdcompat_deps = LibDeps [ libposixcompat_deps, LibDep "crypto",
                                  LibDep "openbsdcompat" ]

-- we need to make vfs more modular to make this actually useful
data VFSModules = VFS_RamFS | VFS_NFS | VFS_BlockdevFS | VFS_FAT
vfsdeps :: [VFSModules] -> String -> [LibDepTree]
vfsdeps [] t                  = [LibDep t]
vfsdeps (VFS_RamFS:xs) t      = [] ++ vfsdeps xs t
vfsdeps (VFS_NFS:xs) t        = [libnfs_deps] ++ vfsdeps xs t
vfsdeps (VFS_BlockdevFS:xs) t = [LibDep "ahci", LibDep "megaraid"] ++ vfsdeps xs t
vfsdeps (VFS_FAT:xs) t        = [] ++ vfsdeps xs t

libvfs_deps_all t        = LibDeps $ (vfsdeps [VFS_NFS, VFS_RamFS, VFS_BlockdevFS,
                                               VFS_FAT] t)
libvfs_deps_noblockdev t = LibDeps $ (vfsdeps [VFS_NFS, VFS_RamFS] t)
libvfs_deps_nonfs t      = LibDeps $ (vfsdeps [VFS_RamFS, VFS_BlockdevFS, VFS_FAT] t)
libvfs_deps_nfs t        = LibDeps $ (vfsdeps [VFS_NFS] t)
libvfs_deps_ramfs t      = LibDeps $ (vfsdeps [VFS_RamFS] t)
libvfs_deps_blockdevfs t = LibDeps $ (vfsdeps [VFS_BlockdevFS] t)
libvfs_deps_fat t        = LibDeps $ (vfsdeps [VFS_FAT, VFS_BlockdevFS] t)

-- flatten the dependency tree
flat :: [LibDepTree] -> [LibDepTree]
flat [] = []
flat ((LibDep  l):xs) = [LibDep l] ++ flat xs
flat ((LibDeps t):xs) = flat t ++ flat xs

str2dep :: String -> LibDepTree
str2dep  str
    | str == "vfs"           = libvfs_deps_all str
    | str == "vfs_ramfs"     = libvfs_deps_ramfs str
    | str == "vfs_nonfs"     = libvfs_deps_nonfs str
    | str == "vfs_noblockdev"= libvfs_deps_noblockdev str
    | str == "lwip"          = liblwip_deps
    | str == "netQmng"       = libnetQmng_deps
    | str == "ssh"           = libssh_deps
    | str == "openbsdcompat" = libopenbsdcompat_deps
    | otherwise              = LibDep str

-- get library depdencies
--   we need a specific order for the .a, so we define a total order
libDeps :: [String] -> [String]
libDeps xs = [x | (LibDep x) <- (sortBy xcmp) . nub . flat $ map str2dep xs ]
    where xord = [ "ssh"
                  , "openbsdcompat"
                  , "crypto"
                  , "zlib"
                  , "posixcompat"
                  , "term_server"
                  , "vfs"
                  , "ahci"
                  , "megaraid"
                  , "nfs"
                  , "net_queue_manager"
                  , "bfdmuxvm"
                  , "lwip"
                  , "arranet"
                  , "e1000n"
                  , "e10k"
                  , "e10k_vf"
                  , "contmng"
                  , "procon"
                  , "net_if_raw"
                  , "vfsfd"
                  , "timer"
                  , "hashtable"]
          xcmp (LibDep a) (LibDep b) = compare (elemIndex a xord) (elemIndex b xord)


--
-- Build a CPU driver
--

cpuDriver :: Args.Args
cpuDriver = Args.defaultArgs { Args.buildFunction = cpuDriverBuildFn,
                               Args.target = "cpu",
                               Args.driverType = "cpu" }

bootDriver :: Args.Args
bootDriver = Args.defaultArgs { Args.buildFunction = cpuDriverBuildFn,
                                Args.driverType = "boot" }

-- CPU drivers are built differently
cpuDriverBuildFn :: TreeDB -> String -> Args.Args -> HRule
cpuDriverBuildFn tdb tf args = Rules []

bootDriverBuildFn :: TreeDB -> String -> Args.Args -> HRule
bootDriverBuildFn tdb tf args = Rules []

--
-- Build a platform
--
platform :: String -> [ String ] -> [ ( String, String ) ] -> String -> HRule
platform name archs files docstr =
  if null $ archs Data.List.\\ Config.architectures then
    Rules [
      Phony name False
      ([ NStr "@echo 'Built platform <",  NStr name, NStr ">'" ] ++
       [ Dep BuildTree arch file | (arch,file) <- files ]) ,
      Phony "help-platforms" True
      [ Str "@echo \"", NStr name, Str ":\\n\\t", NStr docstr, Str "\"" ]
      ]
  else
    Rules []

--
-- Boot an image.
--   name: the boot target name
--   archs: list of architectures required
--   tokens: the hake tokens for the target
--   docstr: description of the target
--
boot :: String -> [ String ] -> [ RuleToken ] -> String -> HRule
boot name archs tokens docstr =
  if null $ archs Data.List.\\ Config.architectures then
    Rules [
      Phony name False tokens,
      Phony "help-boot" True
      [ Str "@echo \"", NStr name, Str ":\\n\\t", NStr docstr, Str "\"" ]
      ]
  else
    Rules []

--
-- Copy a file from the source tree
--
copyFile :: TreeRef -> String -> String -> String -> String -> HRule
copyFile stree sarch spath darch dpath =
  Rule [ Str "cp", Str "-v", In stree sarch spath, Out darch dpath ]

getExternalDependency :: String -> String -> [ HRule ]
getExternalDependency url name =
    [
        Rule ( [
            Str "curl",
            Str "--create-dirs",
            Str "-o",
            Out "cache" name,
            Str url
        ] ),
        copyFile SrcTree "cache" name "" name
    ]
