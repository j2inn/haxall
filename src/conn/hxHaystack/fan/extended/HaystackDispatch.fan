using hxConn
using concurrent
using haystack
using hx

**
** HaystackConn
**
class HaystackDispatch : HaystackDispatchBase {
  new make(Obj arg) : super(arg) {}
  
  override Obj? onReceive(HxMsg msg) {
    try {
      if (msg.id == "clientWith") {
        return openClient.doWith(msg.a)
      }
      return super.onReceive(msg)
    } catch (Err e) {
      return Future.makeCompletable.completeErr(e)
      // TODO There may be some message types we want to instead throw the error?
    }
  }
}
