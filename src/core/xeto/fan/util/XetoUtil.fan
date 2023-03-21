//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Feb 2023  Brian Frank  Creation
//

using util
using data
using haystack::UnknownNameErr

**
** Utility functions
**
@Js
internal const class XetoUtil
{

//////////////////////////////////////////////////////////////////////////
// Naming
//////////////////////////////////////////////////////////////////////////

  ** Return if valid spec name
  static Bool isSpecName(Str n)
  {
    if (n.isEmpty) return false
    ch := n[0]

    // _123
    if (ch == '_') return n.all |c, i| { i == 0 || c.isDigit }

    // Foo_Bar_123
    if (!ch.isAlpha) return false
    return n.all |c| { c.isAlphaNum || c == '_' }
  }

//////////////////////////////////////////////////////////////////////////
// Opts
//////////////////////////////////////////////////////////////////////////

  ** Get logging function from options
  static |DataLogRec|? optLog(DataDict? opts, Str name)
  {
    if (opts == null) return null
    x := opts.get(name, null)
    if (x == null) return null
    if (x is Unsafe) x = ((Unsafe)x).val
    if (x is Func) return x
    throw Err("Expecting |DataLogRec| func for $name.toCode [$x.typeof]")
  }

//////////////////////////////////////////////////////////////////////////
// Inherit Meta
//////////////////////////////////////////////////////////////////////////

  ** Inherit spec meta data
  static DataDict inheritMeta(MSpec spec)
  {
    own := spec.own

    base := spec.base as XetoSpec
    if (base == null) return own

    // walk thru base tags and map tags we inherit
    acc := Str:Obj[:]
    baseSize := 0
    base.m.meta.each |v, n|
    {
      baseSize++
      if (isMetaInherited(n)) acc[n] = v
    }

    // if we inherited all of the base tags and
    // I have none of my own, then reuse base meta
    if (acc.size == baseSize && own.isEmpty)
      return base.m.meta

    // merge in my own tags
    if (!own.isEmpty)
      own.each |v, n| { acc[n] = v }

    return spec.env.dictMap(acc)
  }

  static Bool isMetaInherited(Str name)
  {
    // we need to make this use reflection at some point
    if (name == "abstract") return false
    if (name == "sealed") return false
    if (name == "maybe") return false
    return true
  }

//////////////////////////////////////////////////////////////////////////
// Inherit Slots
//////////////////////////////////////////////////////////////////////////

  ** Inherit spec slots
  static MSlots inheritSlots(MSpec spec)
  {
    own := spec.slotsOwn
    supertype := spec.base

    if (supertype == null) return own

    [Str:XetoSpec]? acc := null
    if (supertype === spec.env.sys.and)
    {
      acc = Str:XetoSpec[:]
      acc.ordered = true

      ofs := spec.get("ofs", null) as DataSpec[]
      if (ofs != null) ofs.each |x|
      {
        x.slots.each |s|
        {
          // TODO: need to handle conflicts in compiler checks
          acc[s.name] = s
        }
      }
    }
    else
    {
      if (own.isEmpty) return supertype.slots

      // add supertype slots
      acc = Str:XetoSpec[:]
      acc.ordered = true
      supertype.slots.each |s|
      {
        acc[s.name] = s
      }
    }

    // add in my own slots
    own.each |s|
    {
      n := s.name
      inherit := acc[n]
      if (inherit != null) s = overrideSlot(inherit, s)
      acc[n] = s
    }

    return MSlots(acc)
  }

  ** Merge inherited slot 'a' with override slot 'b'
  static XetoSpec overrideSlot(XetoSpec a, XetoSpec b)
  {
    XetoSpec(MSpec(b.loc, b.parent, b.name, a, b.type, b.own, b.slotsOwn, b.m.flags))
  }

//////////////////////////////////////////////////////////////////////////
// Is-A
//////////////////////////////////////////////////////////////////////////

  ** Return if a is-a b
  static Bool isa(XetoSpec a, XetoSpec b, Bool isTop)
  {
    // check if a and b are the same
    if (a === b) return true

    // if A is "maybe" type, then it also matches None
    if (b.isNone && a.isMaybe && isTop) return true

    // if A is sys::And type, then check any of A.ofs is B
    if (isAnd(a))
    {
      ofs := ofs(a, false)
      if (ofs != null && ofs.any |x| { x.isa(b) }) return true
    }

    // if A is sys::Or type, then check all of A.ofs is B
    if (isOr(a))
    {
      ofs := ofs(a, false)
      if (ofs != null && ofs.all |x| { x.isa(b) }) return true
    }

    // if B is sys::Or type, then check if A is any of B.ofs
    if (isOr(b))
    {
      ofs := ofs(b, false)
      if (ofs != null && ofs.any |x| { a.isa(x) }) return true
    }

    // check a's base type
    if (a.base != null) return isa(a.base, b, false)

    return false
  }

  static Bool isNone(XetoSpec x)  { x === x.m.env.sys.none }

  static Bool isAnd(XetoSpec x) { x.base === x.m.env.sys.and }

  static Bool isOr(XetoSpec x) { x.base === x.m.env.sys.or  }

  static Bool isCompound(XetoSpec x) { (isAnd(x) || isOr(x)) && ofs(x, false) != null }

  static DataSpec[]? ofs(XetoSpec x, Bool checked)
  {
    val := x.m.own.get("ofs", null) as DataSpec[]
    if (val != null) return val
    if (checked) throw UnknownNameErr("Missing 'ofs' meta: $x.qname")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Derive
//////////////////////////////////////////////////////////////////////////

  ** Dervice a new spec from the given base, meta, and map
  static DataSpec derive(XetoEnv env, Str name, XetoSpec base, DataDict meta, [Str:DataSpec]? slots)
  {
    // sanity checking
    if (!isSpecName(name)) throw ArgErr("Invalid spec name: $name")
    if (!base.isDict)
    {
      if (slots != null && !slots.isEmpty) throw ArgErr("Cannot add slots to non-dict type: $base")
    }

    spec := XetoSpec()
    m := MDerivedSpec(env, name, base, meta, deriveSlots(env, spec, slots), deriveFlags(base, meta))
    XetoSpec#m->setConst(spec, m)
    return spec
  }

  private static Int deriveFlags(XetoSpec base, DataDict meta)
  {
    flags := base.m.flags
    if (meta.has("maybe")) flags = flags.or(MSpecFlags.maybe)
    return flags
  }

  private static MSlots deriveSlots(XetoEnv env, XetoSpec parent, [Str:DataSpec]? slotsMap)
  {
    if (slotsMap == null || slotsMap.isEmpty) return MSlots.empty

    derivedMap := slotsMap.map |XetoSpec base, Str name->XetoSpec|
    {
      XetoSpec(MSpec(FileLoc.synthetic, parent, name, base, base.type, env.dict0, MSlots.empty, base.m.flags))
    }

    return MSlots(derivedMap)
  }

//////////////////////////////////////////////////////////////////////////
// Instantiate
//////////////////////////////////////////////////////////////////////////

  ** Instantiate default value of spec
  static Obj? instantiate(XetoEnv env, XetoSpec spec)
  {
    meta := spec.m.meta
    if (meta.has("abstract")) throw Err("Spec is abstract: $spec.qname")

    if (spec.isNone) return null
    if (spec.isScalar) return meta->val
    if (spec === env.sys.dict) return env.dict0
    if (spec.isList) return env.list0

    acc := Str:Obj[:]
    spec.slots.each |slot|
    {
      if (slot.isMaybe) return
      if (slot.isQuery) return
      acc[slot.name] = instantiate(env, slot)
    }
    return env.dictMap(acc)
  }

}

