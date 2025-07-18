//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using concurrent
using web
using util
using xeto
using haystack
using folio
using hx
using hxm
using hxFolio

class NewHxdBoot : HxBoot
{
  new make(File dir) : super("sys", dir)
  {
  }

  override Log log := Log.get("hxd")

  override Version version := typeof.pod.version

  **
  ** Misc configuration tags used to customize the system.
  ** This dict is available via Proj.config.
  ** Standard keys:
  **   - noAuth: Marker to disable authentication and use superuser
  **   - test: Marker for HxTest runtime
  **   - platformSpi: Str qname for hxPlatform::PlatformSpi class
  **   - platformSerialSpi: Str qname for hxPlatformSerial::PlatformSerialSpi class
  **   - hxLic: license Str or load from lic/xxx.trio
  **
  Str:Obj? config := [:]

  override Folio initFolio()
  {
    config := FolioConfig
    {
      it.name = "haxall"
      it.dir  = this.dir + `db/`
      it.pool = ActorPool { it.name = "Hxd-Folio" }
    }
    return HxFolio.open(config)
  }

  ** Initialize and kick off the runtime
  Int run()
  {
    // initialize project
    proj := init

    // install shutdown handler
// TODO
//    Env.cur.addShutdownHook(proj.shutdownHook)

    // startup proj
    proj.start
    Actor.sleep(Duration.maxVal)
    return 0
  }

  override HxProj initProj()
  {
    HxdSys(this)
  }
}

**
** Bootstrap loader for Haxall daemon
**
class HxdBoot
{

//////////////////////////////////////////////////////////////////////////
// Configuration
//////////////////////////////////////////////////////////////////////////

  ** Runtime version
  Version version := typeof.pod.version

  ** Name of the runtime, if omitted it defaults to dir.name
  Str? name

  ** Runtime database dir (must set before booting)
  File? dir

  ** Flag to create a new database if it doesn't already exist
  Bool create := false

  ** Logger to use for bootstrap
  Log log := Log.get("hxd")

  **
  ** Platform meta:
  **   - logoUri: URI to an SVG logo image
  **   - productName: Str name for about op
  **   - productVersion: Str version for about op
  **   - productUri: Uri to product home page
  **   - vendorName: Str name for about op
  **   - vendorUri: Uri to vendor home page
  **
  Str:Obj? platform := [:]

  **
  ** Misc configuration tags used to customize the system.
  ** This dict is available via Proj.config.
  ** Standard keys:
  **   - noAuth: Marker to disable authentication and use superuser
  **   - test: Marker for HxTest runtime
  **   - platformSpi: Str qname for hxPlatform::PlatformSpi class
  **   - platformSerialSpi: Str qname for hxPlatformSerial::PlatformSerialSpi class
  **   - hxLic: license Str or load from lic/xxx.trio
  **
  Str:Obj? config := [:]

  **
  ** Tags define in the projMeta singleton record
  **
  Dict projMeta := Etc.emptyDict

  **
  ** List of lib names which are required to be installed.
  **
  Str[] requiredLibs := [
    "ph",
    "phScience",
    "phIoT",
    "phIct",
    "hx",
    "obs",
    "axon",
    "xeto",
    "crypto",
    "http",
    "hxApi",
    "hxShell",
    "hxUser",
    "io",
    "task",
    "point",
  ]

  **
  ** This flag will remove any lib not installed from the local database
  ** during bootstrap.
  **
  Bool removeUnknownLibs := false

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Initialize an instance of HxProj but do not start it
  HxProj init()
  {
    if (rt != null) return rt
    initArgs
    initWebMode
    initLic
    openDatabase
    initMeta
    initLibs
    rt = initRuntime
    return rt
  }

  ** Initialize and kick off the runtime
  Int run()
  {
    // initialize runtime instance
    init

    // install shutdown handler
    Env.cur.addShutdownHook(rt.shutdownHook)

    // startup runtime
    rt.start
    Actor.sleep(Duration.maxVal)
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Internals
//////////////////////////////////////////////////////////////////////////

  private Void initArgs()
  {
    // validate and normalize dir
    if (dir == null) throw ArgErr("Must set 'dir' field")
    if (!dir.isDir) dir = dir.uri.plusSlash.toFile
    dir = dir.normalize
    if (!create)
    {
      if (!dir.exists) throw ArgErr("Dir does not exist: $dir")
      if (!dir.plus(`db/folio.index`).exists) throw ArgErr("Dir missing database files: $dir")
    }

    if (config.containsKey("noAuth"))
    {
      echo("##")
      echo("## NO AUTH - authentication is disabled!!!!")
      echo("##")
    }
  }

  private Void initWebMode()
  {
    WebJsMode.setCur(WebJsMode.es)
  }

  private Void initLic()
  {
    // try to load license file from lic/ if not explicitly configured
    if (config["hxLic"] != null) return
    file := dir.plus(`lic/`).listFiles.find |x| { x.ext == "trio" }
    if (file != null) config["hxLic"] = file.readAllStr
  }

  private Void openDatabase()
  {
    config := FolioConfig
    {
      it.name = "haxall"
      it.dir  = this.dir + `db/`
      it.pool = ActorPool { it.name = "Hxd-Folio" }
    }
    this.db = HxFolio.open(config)
  }

  private Void initMeta()
  {
    // setup the tags we want for projMeta
    tags := ["projMeta": Marker.val, "version": version.toStr]
    projMeta.each |v, n| { tags[n] = v }

    // update rec and set back to projMeta field so HxProj can init itself
    projMeta = initRec("projMeta", db.read(Filter.has("projMeta"), false), tags)
  }

  private Void initLibs()
  {
    requiredLibs.each |libName| { initLib(libName) }
  }

  private Void initLib(Str name)
  {
    tags := ["ext":name, "dis":"lib:$name"]
    initRec("lib [$name]", db.read(Filter.eq("ext", name), false), tags)
  }

  private Dict initRec(Str summary, Dict? rec, Str:Obj changes := [:])
  {
    if (rec == null)
    {
      log.info("Create $summary")
      return db.commit(Diff(null, changes, Diff.add.or(Diff.bypassRestricted))).newRec
    }
    else
    {
      changes = changes.findAll |v, n| { rec[n] != v }
      if (changes.isEmpty) return rec
      log.info("Update $summary")
      return db.commit(Diff(rec, changes)).newRec
    }
  }

  virtual HxProj initRuntime()
  {
//    HxProj(this).init(this)
throw Err("TODO")
  }

//////////////////////////////////////////////////////////////////////////
// Internal Fields
//////////////////////////////////////////////////////////////////////////

  internal Folio? db
  internal HxProj? rt
  internal Platform? platformRef
}

**************************************************************************
** RunCli
**************************************************************************

** Run command
internal class RunCli : HxCli
{
  override Str name() { "run" }

  override Str summary() { "Run the daemon server" }

  @Opt { help = "Disable authentication and use superuser for all access" }
  Bool noAuth

  @Arg { help = "Runtime database directory" }
  File? dir

  override Int run()
  {
    boot := NewHxdBoot(dir)
    if (noAuth) boot.config["noAuth"] = Marker.val
    return boot.run
  }
}

