--!The Make-like install Utility based on Lua
--
-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2018, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        install.lua
--

-- imports
import("core.base.option")
import("core.project.target")
import("build")
import("test")
import("filter")

-- make package 
function _make_package(package)

    -- the package name
    local name = package:name()

    -- the package directory
    local packagedir = path.join(package:directory(), name .. ".pkg")

    -- the linkdir
    local linkdir = path.join(packagedir, "lib/$(mode)/$(plat)/$(arch)")

    -- the includedir 
    local includedir = path.join(packagedir, "include/$(mode)/$(plat)/$(arch)")

    -- install the library files and ignore hidden files (.xxx)
    os.tryrm(linkdir)
    os.cp(package:installdir("lib"), linkdir)

    -- install the header files
    os.cp(package:installdir("include"), includedir)

    -- get links
    local links = {}
    for _, filename in ipairs(os.files(path.join(linkdir, target.filename("*", "static"))), path.filename) do
        local link = target.linkname(filename)
        if link then
            table.insert(links, link)
        end
    end
    if #links == 0 then
        for _, filename in ipairs(os.files(path.join(linkdir, target.filename("*", "shared"))), path.filename) do
            local link = target.linkname(filename)
            if link then
                table.insert(links, link)
            end
        end
    end
    assert(#links > 0, "the library files not found in package %s", name)

    -- make xmake.lua 
    local file = io.open(path.join(packagedir, "xmake.lua"), "w")
    if file then

        -- the xmake.lua content
        local content = [[ 
-- the %s package
option("%s")

    -- show menu
    set_showmenu(true)

    -- set category
    set_category("package")

    -- set description
    set_description("The %s package")

    -- add defines to config.h if checking ok
    add_defines_h("$(prefix)_PACKAGE_HAVE_%s")

    -- add links for checking
    add_links("%s")

    -- add link directories
    add_linkdirs("lib/$(mode)/$(plat)/$(arch)")

    -- add include directories
    add_includedirs("include/$(mode)/$(plat)/$(arch)")
]]

        -- save file
        file:writef(content, name, name, name, name:upper(), table.concat(links, "\", \""))

        -- exit file
        file:close()
    end
end

-- install the given package
function main(package)

    -- get working directory of this package
    local workdir = package:cachedir()

    -- enter the working directory
    local oldir = nil
    if #package:urls() > 0 then
        for _, srcdir in ipairs(os.dirs(path.join(workdir, "source", "*"))) do
            oldir = os.cd(srcdir)
            break
        end
    end
    if not oldir then
        os.mkdir(workdir)
        oldir = os.cd(workdir) 
    end

    -- init tipname 
    local tipname = package:name()
    if package:version_str() then
        tipname = tipname .. "-" .. package:version_str()
    end

    -- trace
    cprintf("${yellow}  => ${clear}installing %s .. ", tipname)
    if option.get("verbose") then
        print("")
    end

    -- install it
    try
    {
        function ()

            -- the package scripts
            local scripts =
            {
                package:script("install_before") 
            ,   package:script("install")
            ,   package:script("install_after") 
            }

            -- create the install task
            local installtask = function () 

                -- clean the install directory first
                os.tryrm(package:installdir())

                -- build it
                build(package)

                -- install it
                for i = 1, 3 do
                    local script = scripts[i]
                    if script ~= nil then
                        filter.call(script, package)
                    end
                end

                -- add search path for program
                if package:kind() == "binary" then
                    os.addenv("PATH", package:installdir("bin"))
                else
                    -- make package from the install directory
                    _make_package(package)
                end

                -- test it
                test(package)
            end

            -- install package
            if option.get("verbose") then
                installtask()
            else
                process.asyncrun(installtask)
            end

            -- fetch package and force to flush the cache
            assert(package:fetch({force = true}), "fetch %s failed!", tipname)

            -- trace
            cprint("${green}ok")
        end,

        catch
        {
            function (errors)

                -- verbose?
                if option.get("verbose") and errors then
                    cprint("${bright red}error: ${clear}%s", errors)
                end

                -- trace
                cprint("${red}failed")

                -- failed
                if not package:requireinfo().optional then
                    raise("install failed!")
                end
            end
        }
    }

    -- leave source codes directory
    os.cd(oldir)
end
