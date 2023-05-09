using auth
using concurrent
using haystack
using haystack::Client
using hx
using web

**
** HaystackClient
**
const class HaystackClient {
  const Uri uri
  const Str username
  const Log log
  const ActorPool pool
  
  private const |->HaystackClientAuth| makeAuth
  private static const Field:Field authCxFields := Field:Field[:].addList(AuthClientContext#.fields.findAll { !isStatic })
  private static const |Func->AuthClientContext| authCxMake := AuthClientContext#.method("make").func.retype(|Func->AuthClientContext|#).toImmutable
  
  static HaystackClient open(Uri uri, Str username, Str password, [Str:Obj]? opts, ActorPool pool) {
    HaystackClient(Client.open(uri, username, password, opts), pool)
  }

  private new make(Client client, ActorPool pool) {
    auth := (AuthClientContext) client.auth
    uri = client.uri
    username = auth.user
    log = client.log
    this.pool = pool
    // Have to use an Unsafe due to `https://fantom.org/forum/topic/2857`
    setFunc := Unsafe(Field.makeSetFunc(authCxFields.map { it.get(client.auth) }.toImmutable))
    makeAuth = |->haystack::HaystackClientAuth| { authCxMake(setFunc.val) }.toImmutable
  }
  
  override Str toStr() {
    uri.toStr
  }

  **
  ** Close the session by sending the 'close' op.
  **
  Void close()
  {
    call("close", Etc.emptyGrid)
  }
  
  Future about() {
    call("about", Etc.makeEmptyGrid, true, null, Grid#first.func)
  }
  
  Future readById(Obj id, Bool checked := true) {
    call("read", Etc.makeListGrid(null, "id", null, [id]), true, null) |g| {
      if (!g.isEmpty && g.first.has("id"))
        return g.first
      if (checked)
        throw UnknownRecErr(id.toStr)
      return null
    }
  }
  
  Future readByIds(Obj[] ids, Bool checked := true) {
    call("read", Etc.makeListGrid(null, "id", null, ids), true, null) |g| {
      if (checked) g.each |r, i| {
        if (r.missing("id"))
          throw UnknownRecErr(ids[i].toStr)
      }
      return g
    }
  }
  
  Future read(Str filter, Bool checked := true) {
    call("read", Etc.makeListsGrid(null, ["filter", "limit"], null, [[filter, Number.one]]), true, null) |g| {
      if (!g.isEmpty)
        return g.first
      if (checked)
        throw UnknownRecErr(filter)
      return null
    }
  }
  
  Future readAll(Str filter) {
    call("read", Etc.makeListGrid(null, "filter", null, [filter]))
  }
  
  Future eval(Str expr) {
    call("eval", Etc.makeListGrid(null, "expr", null, [expr]))
  }
  
  Future evalAll(Obj req, Bool checked := true) {
    reqGrid := req as Grid
    if (reqGrid == null) {
      if (req isnot List)
        throw ArgErr("Expected Grid or Str[]")
      reqGrid = Etc.makeListGrid(null, "expr", null, req)
    }
    return doCall("evalAll", gridToStr(reqGrid), null) |resStr| {
      res := ZincReader(resStr.in).readGrids
      if (checked)
        res.each { if (isErr) throw CallErr(it) }
      return res
    }
  }
  
  Future commit(Grid req) {
    if (req.meta.missing("commit"))
      throw ArgErr("Must specified grid.meta commit tag")
    return call("commit", req)
  }
  
  Future call(Str op, Grid? req := null, Bool checked := true, |Err|? errFn := null, |Grid->Obj?|? thenFn := null) {
    doCall(op, gridToStr(req ?: Etc.makeEmptyGrid), errFn) |resStr| {
      res := ZincReader(resStr.in).readGrid
      if (checked && res.isErr)
        throw CallErr(res)
      return thenFn == null ? Unsafe(res) : thenFn(res)
    }
  }
  
  private Future doCall(Str op, Str req, |Err->Obj?|? errFn := null, |Str->Obj?|? thenFn := null) {
    return Actor(pool, doCallFn(op, req, errFn, thenFn)).send(null)
  }
  
  internal |->Obj?| doCallFn(Str op, Str req, |Err->Obj?|? errFn := null, |Str->Obj?|? thenFn := null) {
    |->Obj?| {
      try {
        body := Buf().print(req).flip
        c := toWebClient(op.toUri)
        c.reqMethod = "POST"
        c.reqHeaders["Content-Type"] = "text/zinc; charset=utf-8"
        c.reqHeaders["Content-Length"] = body.size.toStr
        debugCount := Client.debugReq(log, c, req)
        c.writeReq
        c.reqOut.writeBuf(body).close
        c.readRes
        if (c.resCode == 100)
          c.readRes
        resOK := c.resCode == 200
        res := resOK ? c.resIn.readAllStr : null
        c.close
        if (!resOK)
          throw IOErr("Bad HTTP response $c.resCode $c.resPhrase")
        Client.debugRes(log, debugCount, c, res)
        return thenFn == null ? res : thenFn(res)
      } catch (Err e) {
        if (errFn == null) throw e
        return errFn(e)
      }
    }.toImmutable
  }
  
  Future doWith(|HaystackClient->Obj?| f) {
    return Actor(pool, f.toImmutable).send(this)
  }
  
  WebClient toWebClient(Uri path) {
    makeAuth().prepare(WebClient(uri + path))
  }
  
  internal static Str gridToStr(Grid grid) {
    buf := StrBuf()
    out := ZincWriter(buf.out)
    out.ver = 2
    out.writeGrid(grid).flush
    return buf.toStr
  }
}
