using concurrent
using connExt
using haystack
using hx
using hxConn
using skyarcd

const class HaystackLib : HaystackLibBase {

//////////////////////////////////////////////////////////////////////////
// Current
//////////////////////////////////////////////////////////////////////////

  **
  ** Get Haystackfor the current context.
  **
  static HaystackLibProxy? cur(Bool checked := true)
  {
    (HxContext.curHx.rt.lib("haystack", checked) as HaystackLib)?.proxy
  }
  
  const HaystackLibProxy proxy := HaystackLibProxy(this)
  
  private const AtomicRef haystackActorsByIdRef := AtomicRef(Ref:HaystackActor[:].toImmutable)
  
  @NoDoc new make() : super() 
  {
    this.proj = HxContext.curHx.rt->proj
  }
  
  override Void onStart() {
    filter := Filter.has(model.connTag)
    ((AtomicRef) this->connConcernRef).val = proj.concernOpen(filter, Etc.emptyDict, #onConnConcernEventHaystack.func.bind([this]))
    if (model.pollMode.isEnabled)
      this->poller->onStart
  }
  
  HaystackActor? haystackActor(Obj conn, Bool checked := true) {
    id := conn as Ref ?: ((Dict) conn).id
    actor := haystackActorsById[id]
    if (actor != null)
      return actor
    if (checked)
      throw Err("Conn not found: ${id}")
    return null
  }
  
  internal Ref:HaystackActor haystackActorsById() { haystackActorsByIdRef.val }
  
  private Void onConnConcernEventHaystack(ConcernEvent event) {
    onConnConcernEventOrig(event)
    if (event.isAdded) {
      actor := HaystackActor(conn(event.newRec.id))
      temp := haystackActorsById.dup
      temp.add(actor.id, actor)
      haystackActorsByIdRef.val = temp.toImmutable
    }
  }
  private const |ConcernEvent| onConnConcernEventOrig := ConnImplExt#.method("onConnConcernEvent").func.bind([this])
  const Proj proj
}

const class HaystackLibProxy {
  const HaystackLib base
  new make(HaystackLib base) { this.base = base }
  HaystackActor? connActor(Obj conn, Bool checked := true) { base.haystackActor(conn, checked) }
  Obj? syncCur(Obj points) { ConnFwFuncs.connSyncCur(points) }
  Obj? syncHis(Obj points, Obj? dates) { ConnFwFuncs.connSyncHis(points, dates) }
}