using concurrent
using hxConn
using haystack
using hx

const class HaystackActor {
  const Conn base
  
  new make(Conn base) { this.base = base }
  
  Future send(Obj? msg) { CascadingFuture(base.send(msg)) }
  
  Future clientWith(|HaystackClient->Obj?| fn) { send(HxMsg("clientWith", fn.toImmutable)) }
  
  override Str toStr() { base.toStr }
  Ref id() { base.id }
  Dict rec() { base.rec }
  Future ping() { CascadingFuture(base.ping) }
  Future close() { CascadingFuture(base.close) }
  Void sync(Duration timeout) { send(HxMsg("sync")).get(timeout) }
  Grid learn(Obj? arg) { send(HxMsg("learn", arg)).get(null)->val }
  Obj? sendSync(HxMsg msg) { send(msg).get(base.timeout) }
  
  internal static |Obj?->Future| makeThenFn(Conn actor, Method method, Obj?[] args) {
    |Obj? res->Future| { actor.send(HxMsg("thenFn", method, args, res)) }.toImmutable
  }
}

const class CascadingFuture : Future {
  override const Future? wraps
  
  new make(Future wraps) { this.wraps = wraps }
  
  override Void cancel() { wraps.cancel }
  override This complete(Obj? val) { wraps.complete(val) }
  override This completeErr(Err err) { wraps.completeErr(err) }
  override Obj? get(Duration? timeout := null) {
    if (timeout != null)
      timeout = Duration.now + timeout
    result := (Obj?) wraps
    while (true) {
      if (result is Future)
        result = ((Future) result).get(timeout == null ? null : timeout - Duration.now)
      else if (result is Unsafe)
        result = ((Unsafe) result).val
      else break
    }
    return result
  }
  override FutureState state() { wraps.state }
  override This waitFor(Duration? timeout := null) { wraps.waitFor(timeout) }
}

internal const class GridOrErr {
  const Unsafe? grid
  const Err? err
  
  new makeGrid(Grid grid) { this.grid = Unsafe(grid)}
  new makeErr(Err err) { this.err = err }
  
  Grid get() { err == null ? grid.val : throw err }
}

internal const class HaystackCallRes {
  internal const |GridOrErr, HaystackDispatchBase->Obj?| fn
  new make(HaystackDispatchBase conn, |GridOrErr, HaystackDispatchBase->Obj?| fn) { this.fn = fn.toImmutable }
}