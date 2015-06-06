function DeHalo_alpha(clip clp, float "rx", float "ry", float "darkstr", float "brightstr", float "lowsens", float "highsens", float "ss")
{
rx        = default( rx,        2.0 )
ry        = default( ry,        2.0 )
darkstr   = default( darkstr,   1.0 )
brightstr = default( brightstr, 1.0 )
lowsens   = default( lowsens,    50 )
highsens  = default( highsens,   50 )
ss        = default( ss,        1.5 )

LOS = string(lowsens)
HIS = string(highsens/100.0)
DRK = string(darkstr)
BRT = string(brightstr)
ox  = clp.width()
oy  = clp.height()
uv  = 1
uv2 = (uv==3) ? 3 : 2

halos  = clp.bicubicresize(m4(ox/rx),m4(oy/ry)).bicubicresize(ox,oy,1,0)
are    = mt_lutxy(clp.mt_expand(U=uv,V=uv),clp.mt_inpand(U=uv,V=uv),"x y -","x y -","x y -",U=uv,V=uv)
ugly   = mt_lutxy(halos.mt_expand(U=uv,V=uv),halos.mt_inpand(U=uv,V=uv),"x y -","x y -","x y -",U=uv,V=uv)
so     = mt_lutxy( ugly, are, "y x - y 0.001 + / 255 * "+LOS+" - y 256 + 512 / "+HIS+" + *" )
lets   = mt_merge(halos,clp,so,U=uv,V=uv)
remove = (ss==1.0) ? clp.repair(lets,1,0) 
          \        : clp.lanczosresize(m4(ox*ss),m4(oy*ss))
          \             .mt_logic(lets.mt_expand(U=uv,V=uv).bicubicresize(m4(ox*ss),m4(oy*ss)),"min",U=uv2,V=uv2)
          \             .mt_logic(lets.mt_inpand(U=uv,V=uv).bicubicresize(m4(ox*ss),m4(oy*ss)),"max",U=uv2,V=uv2)
          \             .lanczosresize(ox,oy)
them   = mt_lutxy(clp,remove,"x y < x x y - "+DRK+" * - x x y - "+BRT+" * - ?",U=2,V=2)

return( them )
}

function m4(float x) {return(x<16?16:int(round(x/4.0)*4))}