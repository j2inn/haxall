//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using concurrent
using web
using haystack
using folio
using hx

**
** Haxall daemon implementation of HxRuntime
**
const class HxdRuntime : HxRuntime
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Boot constructor
  internal new make(HxdBoot boot)
  {
    this.version       = boot.version
    this.db            = boot.db
    this.log           = boot.log
    this.installedRef  = AtomicRef(HxdInstalled.build)
    this.libsActorPool = ActorPool { it.name = "Hxd-Lib" }
    this.libs          = HxdRuntimeLibs(this, boot.requiredLibs)
    this.users         = (HxRuntimeUsers)libs.getType(HxRuntimeUsers#)
  }

//////////////////////////////////////////////////////////////////////////
// HxRuntime
//////////////////////////////////////////////////////////////////////////

  ** Runtime version
  override const Version version

  ** Namespace of definitions
  override Namespace ns()
  {
    // lazily compile as needed
    ns := nsRef.val as Namespace
    if (ns == null) nsRef.val = ns = HxdDefCompiler(this).compileNamespace
    return ns
  }
  internal Void nsRecompile() { this.nsRef.val = null }
  private const AtomicRef nsRef := AtomicRef()

  ** Database for this runtime
  override const Folio db

  ** Lookup a library by name
  override HxLib? lib(Str name, Bool checked := true) { libs.get(name, checked) }

  ** Library managment
  override const HxRuntimeLibs libs

  ** Actor pool to use for HxRuntimeLibs.actorPool
  const ActorPool libsActorPool

  ** User and authentication managment
  override const HxRuntimeUsers users

  ** Construct a runtime specific context for the given user account
  override HxContext makeContext(HxUser user) { HxdContext(this, user) }

  ** Installed lib pods on the host system
  HxdInstalled installed() { installedRef.val }
  private const AtomicRef installedRef

  ** Logging
  const Log log

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Start runtime (blocks until all libs fully started)
  This start()
  {
    // this method can only be called once
    if (isStarted.getAndSet(true)) return this

    // onStart callback
    futures := libs.list.map |lib->Future| { ((HxdLibSpi)lib.spi).start }
    Future.waitForAll(futures)


    // onReady callback
    futures = libs.list.map |lib->Future| { ((HxdLibSpi)lib.spi).ready }
    Future.waitForAll(futures)

    return this
  }

  ** Shutdown the system (blocks until all modules stop)
  Void stop()
  {
    // this method can only be called once
    if (isStopped.getAndSet(true)) return this

    // onUnready callback
    futures := libs.list.map |lib->Future| { ((HxdLibSpi)lib.spi).unready }
    Future.waitForAll(futures)

    // onStop callback
    futures = libs.list.map |lib->Future| { ((HxdLibSpi)lib.spi).stop }
    Future.waitForAll(futures)
  }

  ** Function that calls stop
  const |->| shutdownHook := |->| { stop }

  private const AtomicBool isStarted := AtomicBool()
  private const AtomicBool isStopped  := AtomicBool()

}

