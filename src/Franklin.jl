module Franklin

using FranklinTemplates
using FranklinTemplates: filecmp

using Markdown
using Markdown: htmlesc
using Dates
using DelimitedFiles: readdlm
using OrderedCollections
using Pkg
using DocStringExtensions: SIGNATURES, TYPEDEF

import Logging
import LiveServer
import Base.push!
import NodeJS
import Literate
import HTTP
import Random
import REPL.REPLCompletions: emoji_symbols

export serve, publish, cleanpull, newsite, optimize, fd2html,
       literate_folder, verify_links, @OUTPUT, get_url

# Extra functions
export lunr

# Convenience functions that get loaded in every module, see eval/module
export fdplotly

# -----------------------------------------------------------------------------
# Legacy with JuDoc
export jd2html # = fd2html

# -----------------------------------------------------------------------------
#
# CONSTANTS
#

const HOME =
    "https://franklinjl.org"
const POINTER_PV =
    "- page variables and {{...}} blocks: $HOME/syntax/page-variables/"
const POINTER_HFUN =
    "- h-functions (hfun) and lx-functions: $HOME/syntax/utils/"
const POINTER_EVAL =
    "- evaluation of Julia code blocks: $HOME/code/"
const POINTER_WORKFLOW =
    "- workflow and folder structure: $HOME/workflow/"

# These are common IP addresses that we can quickly ping to see if the
# user seems online. This is used in `verify_links`. The IPs were
# obtained via `dig www...`; they may change over time; see `check_ping`
# we check in sequence, one should work if the user is online...
const IP_CHECK = (
    "172.217.21.132" => "Google", # google
    "140.82.118.4"   => "GitHub",   # github
    "103.235.46.39"  => "Baidu",  # baidu
    )

"""Big number when we want things to be far."""
const BIG_INT = typemax(Int)

# This dictionary keeps track of a few useful flags that help keept track
# of the context in which particular functions are called. This is not great
# but works fine for what we do here and limits the necessity of passing lots
# of arguments to lots of functions.
const FD_ENV = LittleDict(
    :FULL_PASS     => true,
    :CLEAR         => false,
    :VERB          => false,
    :FINAL_PASS    => false,
    :PRERENDER     => false,
    :NO_FAIL_PRERENDER => true,  # skip prerendering if fails on a page
    :ON_WRITE      => (_, _) -> nothing,
    :FORCE_REEVAL  => false,
    :CUR_PATH      => "",        # complements fd-rpath
    :SOURCE        => "",        # keeps track of the origin of a HTML string
    :OFFSET_LXDEFS => -BIG_INT,  # helps keep track of order in lxcoms
    :DEBUG_MODE    => false,
    :SUPPRESS_ERR  => false,
    :SILENT_MODE   => false,
    :STRUCTURE     => v"0.2",
    :QUIET_TEST    => false,
    :SHOW_WARNINGS => true,     # franklin-specific warnings
    )

"""Dict to keep track of languages and how comments are indicated and their extensions. This is relevant to allow hiding lines of code. """
const CODE_LANG = LittleDict{String,NTuple{2,String}}(
    # expected most common ones
    "julia"      => (".jl",   "#"),
    "julia-repl" => (".jl",   "#"),
    "python"     => (".py",   "#"),
    "r"          => (".r",    "#"),
    "matlab"     => (".m",    "%"),
    # other ones that could appear (this may get completed over time)
    # note: HTML, Markdown are not here **on purpose** as there can be
    # ambiguities in context.
    "bash"       => (".sh",   "#"),
    "c"          => (".c",    "//"),
    "cpp"        => (".cpp",  "//"),
    "fortran"    => (".f90",  "!"),
    "go"         => (".go",   "//"),
    "javascript" => (".js",   "//"),
    "lua"        => (".lua",  "--"),
    "toml"       => (".toml", "#"),
    "ruby"       => (".ruby", "#"),
    )

# copied from Base/path.jl
if Sys.isunix()
    """Indicator for directory separation on the OS."""
    const PATH_SEP = "/"
elseif Sys.iswindows()
    const PATH_SEP = "\\"
else
    error("Unhandled OS")
end

"""Type of the containers for page variables (local and global)."""
const PageVars = LittleDict{String,Pair}

"""Shorter name for a type that we use everywhere"""
const AS = Union{String,SubString{String}}

"""Convenience constants for an automatic message to add to code files."""
const MESSAGE_FILE_GEN     = "This file was generated, do not modify it."
const MESSAGE_FILE_GEN_LIT = "# $MESSAGE_FILE_GEN\n\n"
const MESSAGE_FILE_GEN_FMD = "# $MESSAGE_FILE_GEN # hide\n"

# -----------------------------------------------------------------------------

"""Debugging mode"""
const LOGGING = Ref(false)

function logger(t)
    LOGGING[] || return nothing
    printstyled("LOG: ", color=:yellow, bold=true)
    printstyled(rpad(t[1], 20), color=:blue)
    println(escape_string(t[2]))
    return nothing
end

# -----------------------------------------------------------------------------

include("build.jl") # check if user has Node/minify

include("regexes.jl")

# UTILS
include("utils/warnings.jl")
include("utils/errors.jl")
include("utils/paths.jl")
include("utils/vars.jl")
include("utils/misc.jl")
include("utils/html.jl")


# PARSING
include("parser/tokens.jl")
include("parser/ocblocks.jl")
# > markdown
include("parser/markdown/tokens.jl")
include("parser/markdown/indent.jl")
include("parser/markdown/validate.jl")
# > latex
include("parser/latex/tokens.jl")
include("parser/latex/blocks.jl")
# > html
include("parser/html/tokens.jl")
include("parser/html/blocks.jl")

# EVAL
include("eval/module.jl")
include("eval/run.jl")
include("eval/codeblock.jl")
include("eval/io.jl")
include("eval/literate.jl")

# CONVERSION
# > markdown
include("converter/markdown/blocks.jl")
include("converter/markdown/utils.jl")
include("converter/markdown/mddefs.jl")
include("converter/markdown/tags.jl")
include("converter/markdown/md.jl")
# > latex
include("converter/latex/latex.jl")
include("converter/latex/commands.jl")
include("converter/latex/hyperrefs.jl")
include("converter/latex/io.jl")
# > html
include("converter/html/functions.jl")
include("converter/html/html.jl")
include("converter/html/blocks.jl")
include("converter/html/link_fixer.jl")
include("converter/html/prerender.jl")

# FILE AND DIR MANAGEMENT
include("manager/rss_generator.jl")
include("manager/write_page.jl")
include("manager/dir_utils.jl")
include("manager/file_utils.jl")
include("manager/franklin.jl")
include("manager/extras.jl")
include("manager/post_processing.jl")

end # module
