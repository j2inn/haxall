#! /usr/bin/env fan
//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Nov 2010  Brian Frank  Creation
//

using build

**
** Build: hxHaystack
**
class Build : BuildPod
{
  static const Str buildVer := Env.cur.vars.get("SKY_SPARK_VERSION", /*default*/"3.1.5")

  new make()
  {
    podName = "hxHaystack"
    summary = "Haystack HTTP API connector"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               ]
    version = Version(buildVer)
    depends  = ["sys @{fan.depend}",
                "concurrent @{fan.depend}",
                "haystack @{hx.depend}",
                "axon @{hx.depend}",
                "folio @{hx.depend}",
                "hx @{hx.depend}",
                "hxConn @{hx.depend}",
                "web @{fan.depend}",
                "auth @{hx.depend}",
                "skyarcd @{hx.depend}",
                "connExt @{hx.depend}"
                ]
    srcDirs = [`fan/`, `fan/extended/`, `test/`]
    resDirs = [`lib/`]
    index   = ["ph.lib": "haystack"]
  }
}