//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Aug 2021  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx
using hxm
using hxFolio
using util

**
** HxdHisService provides simple wrapper around Folio as the
** implementation of the HxHisService.  Unlike SkySpark is does
** not currently support totalization, computed histories, etc.
**
/* TODO
internal const class HxdFileService : HxFileService
{
  new make(HxProj rt) { this.rt = rt }

  const HxProj rt

  override File resolve(Uri uri)
  {
    // pathing check
    if (uri.toStr.contains(".."))
      throw UnsupportedErr("Uri must not contain '..' path: $uri")

    // we only support {dir}/io/xxxxx paths right now
    if (!uri.toStr.startsWith("io/"))
      throw UnsupportedErr("Only io/ paths supportted")

    // extra directory check to ensure we don't escape out of safe io/ directory
    file := rt.dir + uri
    if (!file.normalize.pathStr.startsWith(rt.dir.normalize.pathStr))
      throw UnsupportedErr("Uri not under ${rt.dir} dir: $uri")

    // use a wrapper which routes everything back to here for security checks
    return HxdFile(this, uri, file)
  }
}

**************************************************************************
** HxdFile
**************************************************************************

internal const class HxdFile : SyntheticFile
{
  new makeNew(HxdFileService service, Uri uri, File file) : super.make(uri)
  {
    this.service = service
    this.file = file
  }

  const HxdFileService service

  const File file

  override DateTime? modified
  {
    get { file.modified }
    set { file.modified = it }
  }

  override Bool exists() { file.exists }

  override Int? size() { file.size }

  override Bool isEmpty() { file.isEmpty }

  override Bool isHidden() { file.isHidden }

  override Bool isReadable() { file.isReadable }

  override Bool isWritable() { file.isWritable }

  override Bool isExecutable() { file.isExecutable }

  override Str? osPath() { null }

  override File normalize() { return this }

  override File? parent()
  {
    try
    {
      parentUri := uri.parent
     if (parentUri != null) return service.resolve(parentUri)
    }
    catch (Err e) {}
    return null
  }

  override File[] list(Regex? pattern := null)
  {
    if (!uri.isDir) return File[,]
    return file.list(pattern).mapNotNull |kid->File?|
    {
      kidUri := this.uri.plusName(kid.name)
      if (kid.isDir) kidUri = kidUri.plusSlash
      kidWrap := service.resolve(kidUri)
      return kidWrap.exists ? kidWrap : null
    }
  }

  @Operator override File plus(Uri path, Bool checkSlash := true)
  {
    service.resolve(uri.plus(path))
  }

  File toLocal()
  {
    if (file.typeof.name == "LocalFile") return file
    throw Err("Not a local file: $uri")
  }

  override File create() { file.create }

  override File moveTo(File to)
  {
    file.moveTo((to as HxdFile)?.toLocal ?: to)
  }

  override Void delete()
  {
    if (!exists) return
    file.delete
  }

  override File deleteOnExit() { throw IOErr("Unsupported") }

  override Buf open(Str mode := "rw") { throw UnsupportedErr() }

  override Buf mmap(Str mode := "rw", Int pos := 0, Int? size := null) { throw UnsupportedErr() }

  override InStream in(Int? bufferSize := 4096) { file.in(bufferSize) }

  override OutStream out(Bool append := false, Int? bufferSize := 4096) { file.out(append, bufferSize) }
}
*/

