using Franklin, Test, Markdown, Dates, Random, Pkg
using Literate, DelimitedFiles, Suppressor
const F = Franklin
const R = @__DIR__
const D = joinpath(dirname(dirname(pathof(Franklin))), "test", "_dummies")

INIT_DIR = pwd()

F.FD_ENV[:SILENT_MODE] = true
# F.FD_ENV[:DEBUG_MODE] = true

Franklin.FD_ENV[:QUIET_TEST] = true

# UTILS
println("UTILS-1")
include("utils/folder_structure.jl")
include("utils/paths_vars.jl"); include("test_utils.jl")
# ---
println("UTILS-2")
include("utils/misc.jl")
include("utils/errors.jl")
include("utils/warnings.jl")
include("utils/html.jl")
include("regexes.jl")
println("🍺")

# MANAGER folder
println("MANAGER")
include("manager/utils.jl")
include("manager/config.jl")
include("manager/dir_utils.jl")
include("manager/page_vars_html.jl")
include("manager/paginate.jl")
include("manager/robots_generator.jl")
include("manager/rss_generator.jl")
include("manager/sitemap_generator.jl")
println("🍺")

# PARSER folder
println("PARSER/MD+LX")
include("parser/1-tokenize.jl")
include("parser/2-blocks.jl")
include("parser/markdown+latex.jl")
include("parser/markdown-extra.jl")
include("parser/footnotes+links.jl")
include("parser/latex++.jl")
include("parser/indentation++.jl")
include("parser/md-dbb.jl")
println("🍺")

# EVAL
println("EVAL")
include("eval/module.jl")
include("eval/run.jl")
include("eval/io.jl")
include("eval/codeblock.jl")
include("eval/eval.jl")
include("eval/integration.jl")
include("eval/extras.jl")
include("eval/repl.jl")

# LATEX
println("LATEX")
include("latex/newcommand.jl")
include("latex/begin-end.jl")
include("latex/nesting.jl")
# include("latex/custom.jl")
println("🍺")

# CONVERTER folder
println("CONVERTER/MD")
include("converter/md/markdown.jl")
include("converter/md/markdown2.jl")
include("converter/md/markdown3.jl")
include("converter/md/markdown4.jl")
include("converter/md/hyperref.jl")
include("converter/md/md_defs.jl")
include("converter/md/md_defs2.jl")
include("converter/md/tags.jl")
println("🍺")
println("CONVERTER/HTML")
include("converter/html/html.jl")
include("converter/html/html2.jl")
include("converter/html/html_for.jl")
include("converter/html/html_functions.jl")
println("🍺")
println("CONVERTER/LX")
include("converter/lx/input.jl")
include("converter/lx/simple.jl")
println("🍺")

fs()

println("GLOBAL")
include("global/cases1.jl")
include("global/cases2.jl")
include("global/ordering.jl")
include("global/html_esc.jl")

begin
    # create temp dir to do complete integration testing (has to be here in
    # order to locally play nice with node variables etc, otherwise it's a big
    # headache)
    p = joinpath(D, "..", "__tmp");
    # after errors, this may not have been deleted properly
    isdir(p) && rm(p; recursive=true, force=true)
    # make dir, go in it, do the tests, then get completely out (otherwise
    # windows can't delete the folder)
    mkdir(p); cd(p);
    include("global/postprocess.jl")
    include("global/sitemap.jl")
    cd(p)
    include("global/eval.jl")
    cd(joinpath(D, ".."))
    # clean up
    rm(p; recursive=true, force=true)
end
cd(dirname(dirname(pathof(Franklin))))

println("TEMPLATING")
include("templating/for.jl")
include("templating/fill.jl")

println("UTILS FILE")
include("utils_file/basic.jl")

println("INTEGRATION")
include("integration/literate.jl")
include("integration/literate_extras.jl")
include("integration/hfuns.jl")

flush_td()
cd(joinpath(dirname(dirname(pathof(Franklin)))))

println("HTML validation")
include("html/closep.jl")
include("html/closep_lx.jl")
include("html/pdiv.jl")

println("COVERAGE")
include("coverage/extras1.jl")
include("coverage/paths.jl")

println("😅 😅 😅 😅")

# check quickly if the IPs in IP_CHECK are still ok
println("Verifying ip addresses, if online these should succeed.")
for (addr, name) in F.IP_CHECK
    println(rpad("Ping $name:", 13), ifelse(F.check_ping(addr, 64), "✓", "✗"), ".")
end


Pkg.activate()
cd(INIT_DIR)
