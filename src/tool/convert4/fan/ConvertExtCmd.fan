//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util
using haystack
using haystack::Macro

internal class ConvertExtCmd : ConvertCmd
{
  override Str name() { "ext" }

  override Str summary() { "Convert hx::HxLib to Ext" }

  @Arg Str[] commandName := [,]

  override Int run()
  {
    ast = Ast().scanWorkDir
    ast.exts.each |ext|
    {
      genExt(ext)
    }
    return 0
  }

  Void genExt(AExt ext)
  {
    if (ast.config.ignore.contains(ext.oldName)) return

    con.group("- Generating [$ext.libName]...")
    genLibXeto(ext)
    con.groupEnd
  }

//////////////////////////////////////////////////////////////////////////
// Gen lib.xeto
//////////////////////////////////////////////////////////////////////////

  Void genLibXeto(AExt ext)
  {
    // file
    f := ext.xetoSrcDir + `lib.xeto`
    con.info("Lib xeto [$f.osPath]")

    // build source from template
    macro := Macro(ast.config.templateLibXeto)
    vars := Str:Str[:]
    macro.vars.each |var|
    {
      vars[var] = resolveLibXetoVar(ext, var)
    }
    src := macro.apply |var| { vars[var] }

    // write out
    f.out.print(src).close
  }

  Str resolveLibXetoVar(AExt ext, Str var)
  {
    switch (var)
    {
      case "date":    return Date.today.toLocale("D MMM YYYY")
      case "year":    return Date.today.toLocale("YYYY")
      case "doc":     return ext.meta["doc"] ?: "todo"
      case "depends": return resolveDepends(ext)
    }
    throw Err("Unknown lib.xeto template var: $var")
  }

  private Str resolveDepends(AExt ext)
  {
    s := StrBuf().add("{\n")
    addDepend(s, "sys")
    if (ext.libName != "hx") addDepend(s, "hx")
    s.add("  }")
    return s.toStr
  }

  private Void addDepend(StrBuf s, Str name)
  {
    prefix := name.split('.').first
    versions := ast.config.dependVersions[prefix]
    s.add("    { lib: $name.toCode")
    if (versions != null) s.add(", versions: $versions")
    s.add(" }\n")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Ast? ast
  private Console con := Console.cur
}

