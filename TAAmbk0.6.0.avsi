
FUNCTION TAAmbk( clip input,
\             int "aatype",   int "preaa", float "dark", int "thin",
\             float "sharp",  bool "postaa",
\             val "mtype",    int "mthr",
\             clip "src",     int "cycle", bool "limit", bool "averagemask", int "eedi3mask",
\             bool "predown", int "aarepair", int "stablize", bool "useOpenCL", bool "preferSangNom2",
\             float "p1",     float "p2",     float "p3",
\             float "p4",     float "p5",     float "p6", bool "showmask", int "mtype2", int "mthr2", float "auxmthr") {

  w       = width(input)
  h       = height(input)
  upw4    = Round(w*0.375)*4     # m4(w*1.5)
  uph4    = Round(h*0.375)*4     # m4(h*1.5)
  downw4  = Round(w*0.1875)*4    # m4(w*0.75)
  downh4  = Round(h*0.1875)*4    # m4(h*0.75)

  aatype  = Default(aatype, 1)
  averagemask = Default(averagemask, false)
  dark    = Default(dark, 0)
  thin    = Default(thin, 0)
  cycle   = Default(cycle, 0)
  limit   = Default(limit, false)
  eedi3mask = Default(eedi3mask, 0)
  useOpenCL  = Default(useOpenCL, false)
  showmask = Default(showmask, false)
  stablize = Default(stablize, 0)
  preferSangNom2 = Default(preferSangNom2, true)
  preaa   = Default(preaa,  0)
  mtype   = ( preaa == 0 && aatype == 0 ) ? Default(mtype, 0) : Default(mtype, 1)
  mtype2 = Default(mtype2, 0)
  mthr    = Default(mthr,  32)
  mthr2    = Default(mthr2,  32)
  auxmthr    = (mtype == 1 ) ? Default(auxmthr,  1.2) : (mtype == 3) ? Default(auxmthr, 8.0) : Default(auxmthr, 0)
  sharp   = ( preaa == -1 ) ? Default(sharp,  -1) :
  \         ( preaa !=  0 ) ? Default(sharp, 0.3) :
  \         ( aatype == 0 ) ? Default(sharp,   0) :
  \         ( aatype > 0 && aatype <= 3 ) ? Default(sharp, 0.2) :
  \                                         Default(sharp,  70)
  predown = Default(predown, false)
  absSh   = Abs(sharp)
  postaa  = ( (absSh > 70) || (absSh > 0.4 && absSh < 1) ) ? Default(postaa, true) : Default(postaa, false)
  src     = predown ? Default(src, input.Spline36Resize(downw4, downh4).nnedi3_rpow2(rfactor=2, qual=2, cshift="Spline36Resize", fwidth=w, fheight=h))
  \                 : Default(src, input)
  aarepair= predown ? Default(aarepair, 2) : Default(aarepair, 0)
  


  Assert( isYV12(input),                       """TAA: "input" is not an YV12 clip!"""                  )
  Assert( isYV12(src),                         """TAA: "src" is not an YV12 clip!"""                    )
  Assert( isFrameBased(input),                 """TAA: input clip must be Frame Based!"""               )
  Assert( (aatype>=-3 && aatype<=6),           """TAA: "aatype"(int: -3~6) invalid!"""                  )
  Assert( (preaa>=-1 && preaa<=2),             """TAA: "preaa"(int: -1~2) invalid!"""                   )
  IsInt(mtype) ? Assert( (mtype>=0 && mtype<=6),              """TAA: "mtype"(int: 0~6) invalid!"""                    ) : IsClip(mtype) ? Assert( (mtype.width==w && mtype.height==h), """TAA: resolution of "input" and "mclip" must match!""" ) : nop()
  Assert( (mthr>=0 && mthr<=255),              """TAA: "mthr"(int: 0~255) invalid!"""                   )
  Assert( (aarepair>=0 && aarepair<=24),       """TAA: "aarepair"(int: 0~24) invalid!"""                )
  Assert( (src.width==w && src.height==h),     """TAA: resolution of "input" and "src" must match!"""   )
  Assert( (cycle>=0 && cycle<= 6),             """TAA: You cycle it too many times which will crash your computer!""")
  Assert( (stablize>=0 && stablize<= 3),       """TAA: The Stablize value can't greater than 3 """)
  IsInt(mtype) ? Assert( (mtype!=0 || showmask!=true),        """TAA: You cannot show the mask when mtype=0!""") : nop()




  pindex = aatype + 3
  rp     = IsClip(mtype) ? 20 : ( mtype==5 ) ? 0 : 20
### ---------------------- aatype =   -3,    -2,    -1,    0,    1,     2,    3,    4,    5,    6 ------ ###
  p1 = Default( p1, Select(pindex,    48,    48,    48,    0,   10,   0.5,    3,   48,   48,   48) )
  p2 = Default( p2, Select(pindex,     3,   0.5,    10,    0,   20,   0.2,    1,    1,    0,   rp) )
  p3 = Default( p3, Select(pindex,     1,   0.2,    20,    0,   20,    20,    2,    3,    0,    0) )
  p4 = Default( p4, Select(pindex,     2,    20,    20,    0,   24,     3,    0,    2,    0,    0) )
  p5 = Default( p5, Select(pindex,     0,     3,    24,    0,   50,    30,    0,    0,    0,    0) )
  p6 = Default( p6, Select(pindex,     0,    30,    50,    0,    0,     0,    0,    0,    0,    0) )
### ---------------------- aatype =   -3,    -2,    -1,    0,    1,     2,    3,    4,    5,    6 ------ ###


  preaaC = input.TAAmbk_prepass(predown, downw4, downh4, thin, dark, preaa)

  aa_clip = PreaaC.TAAmbk_mainpass(aatype, cycle, useOpenCL, preferSangNom2, p1, p2, p3, p4, p5, p6, w, h, uph4, upw4, eedi3mask)
  

  aalimited = aa_clip.TAAmbk_postpass(input, absSh, src, postaa, stablize, limit, mtype, mthr, showmask, sharp, w, mtype2, mthr2, auxmthr, averagemask)
  
  return (showmask == true) ? aalimited : ( aarepair==0 ) ? aalimited.AssumeFrameBased() : aalimited.Repair(input, mode=aarepair).AssumeFrameBased()

}

###
Function TAAmbk_mainpass(clip preaaC, int "aatype", int "cycle", bool "useOpenCL", bool "preferSangNom2", float "p1", float "p2", float "p3", float "p4", float "p5", float "p6", int "w", int "h", int "uph4", int "upw4", int "eedi3mask") {
    nnedi3type = (useOpenCL == true) ? "nnedi3ocl" : "nnedi3"
	sangnomtype = (preferSangNom2 == true) ? "SangNom2" : "SangNom"
	nnedi3_rpow2_type = (useOpenCL == true) ? "nnedi3x_rpow2" : "nnedi3_rpow2"
	eedi3mclip = (eedi3mask == 0 ) ? nop() : preaaC.MSharpen(threshold=eedi3mask/5, strength=0, mask=true, highq=false)
	eedi3mclip_r = (eedi3mask == 0 ) ? nop() : eedi3mclip.Spline36Resize(w,uph4).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
  Eval("""
    aa_clip =
    \ (aatype == -3) ? preaaC."""+nnedi3type+"""(dh=true, field=1, nsize=int(p2), nns=int(p3), qual=int(p4)).Spline36Resize(w, uph4, 0, -0.5).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
    \                        ."""+nnedi3type+"""(dh=true, field=1, nsize=int(p2), nns=int(p3), qual=int(p4)).Spline36Resize(uph4, upw4, 0, -0.5)
    \                        ."""+sangnomtype+"""(aa=int(p1)).Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ")."""+sangnomtype+"""(aa=int(p1)).Spline36Resize(w, h)                                                                      :
    \ (aatype == -2) ? (eedi3mask == 0) ? preaaC.eedi3(dh=true, field=1, alpha=p2, beta=p3, gamma=p4, nrad=int(p5), mdis=int(p6)).Spline36Resize(w, uph4, 0, -0.5).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
    \                                     .eedi3(dh=true, field=1, alpha=p2, beta=p3, gamma=p4, nrad=int(p5), mdis=int(p6)).Spline36Resize(uph4, upw4, 0, -0.5)."""+sangnomtype+"""(aa=int(p1)).Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ")."""+sangnomtype+"""(aa=int(p1)).Spline36Resize(w, h)     	:
	\                                      preaaC.eedi3(dh=true, field=1, alpha=p2, beta=p3, gamma=p4, nrad=int(p5), mdis=int(p6), mclip=eedi3mclip).Spline36Resize(w, uph4, 0, -0.5).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
    \                                     .eedi3(dh=true, field=1, alpha=p2, beta=p3, gamma=p4, nrad=int(p5), mdis=int(p6),mclip=eedi3mclip_r).Spline36Resize(uph4, upw4, 0, -0.5)."""+sangnomtype+"""(aa=int(p1)).Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ")."""+sangnomtype+"""(aa=int(p1)).Spline36Resize(w, h)     	:        
    \ (aatype == -1) ? preaaC.eedi2(field=1, mthresh=int(p2), lthresh=int(p3), vthresh=int(p4), maxd=int(p5), nt=int(p6)).Spline36Resize(w, uph4, 0, -0.5).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
    \                        .eedi2(field=1, mthresh=int(p2), lthresh=int(p3), vthresh=int(p4), maxd=int(p5), nt=int(p6)).Spline36Resize(uph4, upw4, 0, -0.5)
    \                        ."""+sangnomtype+"""(aa=int(p1)).Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ")."""+sangnomtype+"""(aa=int(p1)).Spline36Resize(w, h)                                                                      :
    \ (aatype ==  1) ? preaaC.eedi2(field=1, mthresh=int(p1), lthresh=int(p2), vthresh=int(p3), maxd=int(p4), nt=int(p5)).Spline36Resize(w, h, 0, -0.5).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
    \                        .eedi2(field=1, mthresh=int(p1), lthresh=int(p2), vthresh=int(p3), maxd=int(p4), nt=int(p5)).Spline36Resize(h, w, 0, -0.5).Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ")         :
    \ (aatype ==  2) ? (eedi3mask == 0) ? preaaC.eedi3(dh=true, field=1, alpha=p1, beta=p2, gamma=p3, nrad=int(p4), mdis=int(p5)).Spline36Resize(w, h, 0, -0.5).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
    \                                     .eedi3(dh=true, field=1, alpha=p1, beta=p2, gamma=p3, nrad=int(p4), mdis=int(p5)).Spline36Resize(h, w, 0, -0.5).Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ")                    :
	\                                     preaaC.eedi3(dh=true, field=1, alpha=p1, beta=p2, gamma=p3, nrad=int(p4), mdis=int(p5),mclip=eedi3mclip).Spline36Resize(w, h, 0, -0.5).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
    \                                     .eedi3(dh=true, field=1, alpha=p1, beta=p2, gamma=p3, nrad=int(p4), mdis=int(p5),mclip=eedi3mclip.Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")).Spline36Resize(h, w, 0, -0.5).Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ")   :
    \ (aatype ==  3) ? preaaC."""+nnedi3type+"""(dh=true, field=1, nsize=int(p1), nns=int(p2), qual=int(p3)).Spline36Resize(w, h, 0, -0.5).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
    \                                     ."""+nnedi3type+"""(dh=true, field=1, nsize=int(p1), nns=int(p2), qual=int(p3)).Spline36Resize(h, w, 0, -0.5).Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ")                                  :
    \ (aatype ==  4) ? preaaC."""+nnedi3_rpow2_type+"""(rfactor=2, fwidth=upw4, fheight=upw4, nsize=int(p2), nns=int(p3), qual=int(p4), cshift="Spline36Resize")
    \                        ."""+sangnomtype+"""(aa=int(p1)).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
    \                        ."""+sangnomtype+"""(aa=int(p1)).Spline36Resize(h, w).Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ")                                                                               :
    \ (aatype ==  5) ? preaaC.Spline64Resize(upw4, uph4).Repair(preaaC.GaussResize(upw4, uph4, p=100), 1)
    \                        ."""+sangnomtype+"""(aa=int(p1)).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
    \                        ."""+sangnomtype+"""(aa=int(p1)).Spline36Resize(h, w).Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ")                                                                                          :
    \ (aatype ==  6) ? preaaC.Spline64Resize(w, uph4)."""+sangnomtype+"""(aa=int(p1)).Spline36Resize(w, h).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")                                 
    \                        .Spline64Resize(h, upw4)."""+sangnomtype+"""(aa=int(p1)).Spline36Resize(h, w).Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ").Repair(preaaC, mode=int(p2))                                     :
    \ predown        ? preaaC."""+nnedi3_rpow2_type+"""(rfactor=2, qual=2, cshift="Spline36Resize", fwidth=w, fheight=h)                                                              :
    \                  preaaC
   """)
   
   return (cycle == 0 ) ? aa_clip : aa_clip.TAAmbk_mainpass(aatype, cycle - 1, useOpenCL, preferSangNom2, p1, p2, p3, p4, p5, p6, w, h, uph4, upw4, eedi3mask)
 }
 
###
Function TAAmbk_prepass(clip input, bool "predown", int "downw4", int "downh4", int "thin", float "dark", int "preaa") {


  pdclip = predown ? input.Spline36Resize(downw4, downh4) : input
  nn   = pdclip.nnedi3(field=-2)
  nnt  = pdclip.Eval(" try { fturnleft() } catch(error_msg) { TurnLeft() } ").nnedi3(field=-2).Eval(" try { fturnright() } catch(error_msg) { TurnRight() } ")
  clph = mt_average(selecteven(nn), selectodd(nn), U=3, V=3)
  clpv = mt_average(selecteven(nnt), selectodd(nnt), U=3, V=3)
  clp  = mt_average(clph, clpv, U=3, V=3)


  preaaB =
  \ (preaa == -1) ? clp :
  \ (preaa == 1) ? clph :
  \ (preaa == 2) ? clpv :
  \                pdclip
  
  preaaC =
  \ (thin == 0 && dark == 0) ? preaaB :
  \ (dark == 0) ? preaaB.aWarpSharp2(depth=thin) :
  \ (thin == 0) ? preaaB.Toon(dark) :
  \ preaaB.aWarpSharp2(depth=thin).Toon(dark)
 
 return preaaC
}

###
Function TAAmbk_postpass(clip aa_clip, clip "input", float "absSh", clip "src", bool "postaa", int "stablize", bool "limit", val "mtype", int "mthr", bool "showmask", float "sharp", int "w", int "mtype2", int "mthr2", float "auxmthr", bool "averagemask") {

  postaaC =
  \ (sharp ==  0) ? aa_clip :
  \ (sharp >=  1) ? aa_clip.lsfmod(strength=Int(absSh), defaults="old", source=src) :
  \ (sharp >   0) ? aa_clip.Sharpen(absSh).MergeChroma(src) :
  \ (sharp >  -1) ? aa_clip.lsfmod(strength=Round(absSh*100), defaults="fast", source=src) :
  \ (sharp == -1) ? aa_clip.mt_adddiff(mt_makediff(aa_clip, aa_clip.RemoveGrain((w>1100) ? 20 : 11), U=3, V=3).Repair(mt_makediff(src, aa_clip, U=3, V=3), 13), U=3,V=3) :
  \                 aa_clip.lsfmod(strength=Int(absSh), defaults="slow", source=src)



  postaaC = (postaa == false) ? postaaC : Soothe(postaaC, aa_clip, keep=48)


  edge_mask = IsClip(mtype) ? mtype : (mtype == 0) ? nop() : (averagemask == false) ? input.TAAmbk_mask(mtype, mthr, w, mtype2, mthr2, auxmthr) : mt_average(input,postaaC).TAAmbk_mask(mtype, mthr, w, mtype2, mthr2, auxmthr)
  aaed = IsClip(mtype) ? mt_merge(input, postaaC, edge_mask, U=3, V=3) : (mtype == 0) ? postaaC : mt_merge(input, postaaC, edge_mask, U=3, V=3)


  aadiff = (stablize == 0) ? nop() : mt_makediff(input, aaed)
  inputsuper = (stablize == 0) ? nop() : input.MSuper(pel=1)
  diffsuper = (stablize == 0) ? nop() : aadiff.MSuper(pel=1, levels=1)
  fv3 = (stablize == 3) ? inputsuper.MAnalyse(isb=false,delta=3,overlap=8,blksize=16) : nop()
  fv2 = (stablize >= 2) ? inputsuper.MAnalyse(isb=false,delta=2,overlap=8,blksize=16) : nop()
  fv1 = (stablize >= 1) ? inputsuper.MAnalyse(isb=false,delta=1,overlap=8,blksize=16) : nop()
  bv1 = (stablize >= 1) ? inputsuper.MAnalyse(isb=true,delta=1,overlap=8,blksize=16) : nop()
  bv2 = (stablize >= 2) ? inputsuper.MAnalyse(isb=true,delta=2,overlap=8,blksize=16) : nop()
  bv3 = (stablize == 3) ? inputsuper.MAnalyse(isb=true,delta=3,overlap=8,blksize=16) : nop()
  stablized_diff = (stablize == 1) ? aadiff.MDegrain1(diffsuper,bv1,fv1) : (stablize == 2) ? aadiff.MDegrain2(diffsuper,bv1,fv1,bv2,fv2) : (stablize == 3) ? aadiff.MDegrain3(diffsuper,bv1,fv1,bv2,fv2,bv3,fv3) : nop()
  stablized_diff2 = (stablize == 0) ? nop() : mt_lutxy(aadiff, stablized_diff, "x 128 - abs y 128 - abs < x y ?").mergeluma(stablized_diff, 0.6)
  
  aafinal = (stablize == 0) ? aaed : input.mt_makediff(stablized_diff2,U=2,V=2)


  aadiff2 = (limit == false) ? nop() : mt_makediff(input, aafinal)
  aasuper = (limit == false) ? nop() : aadiff2.MSuper(pel=1)
  bv = (limit == false) ? nop() : aasuper.MAnalyse(isb=true, overlap=8, blksize=16)
  fv = (limit == false) ? nop() : aasuper.MAnalyse(isb=false, overlap=8, blksize=16)
  bc = (limit == false) ? nop() : aadiff2.MCompensate(aasuper, bv)
  fc = (limit == false) ? nop() : aadiff2.MCompensate(aasuper, fv)
  max_limit = (limit == false) ? nop() : mt_logic(aadiff2, bc, "max").mt_logic(fc, "max")
  min_limit = (limit == false) ? nop() : mt_logic(aadiff2, bc, "min").mt_logic(fc, "min")
  diffclamp =  (limit == false) ? nop() : mt_clamp(aadiff2, max_limit, min_limit, U=2, V=2)
  aalimited = (limit == false) ? aafinal : mt_makediff(input, diffclamp, U=2, V=2)
  
return (showmask == true) ? edge_mask : aalimited
}
###

Function TAAmbk_mask(clip input, val "mtype", int "mthr", int "w", int "mtype2", int "mthr2", float "auxmthr") {
  edge_mask_1 =
  \ (mtype == 1) ? input.Tcannymod(sigma=auxmthr, mode=1, sobel=true).mt_lut("x "+string(mthr)+" <= x 1 >> x 1 << ?", U=1, V=1).RemoveGrain((w>1100) ? 20 : 11, -1).mt_inflate() :
  \ (mtype == 3) ? input.TEdgeMask(threshY=auxmthr, link=2, preblur=false, valon=-1).mt_lut("x "+string(mthr/5)+" <= x 1 >> x 4 << ?", U=1, V=1).mt_deflate().RemoveGrain( (w>1100) ? 20 : 11, -1 ) :
  \ (mtype == 2) ? input.MSharpen(threshold=mthr/5, strength=0, mask=true, highq=false) :
  \ (mtype == 4) ? input.mt_edge("sobel",7,7,5,5).mt_inflate() :
  \ (mtype == 5) ? input.mt_edge("roberts",0,4,0,4).mt_inflate() :
  \ (mtype == 6) ? input.mt_edge("prewitt",0,255,0,0).mt_lut("x "+string(mthr)+" <= x 1 >> x 1.4 ^ ?").RemoveGrain(4,-1).mt_inflate() : nop()
  edge_mask_2 = (mtype2 == 0) ? nop() :
  \ (mtype2 == 1) ? input.Tcannymod(sigma=1.2, mode=1, sobel=false).mt_lut("x "+string(mthr2)+" <= x 1 >> x 1 << ?", U=1, V=1).RemoveGrain((w>1100) ? 20 : 11, -1).mt_inflate() :
  \ (mtype2 == 3) ? input.TEdgeMask(link=2, preblur=false, valon=-1).mt_lut("x "+string(mthr2/5)+" <= x 1 >> x 4 << ?", U=1, V=1).mt_deflate().RemoveGrain( (w>1100) ? 20 : 11, -1 ) :
  \ (mtype2 == 2) ? input.MSharpen(threshold=mthr2/5, strength=0, mask=true, highq=false) :
  \ (mtype2 == 4) ? input.mt_edge("sobel",7,7,5,5).mt_inflate() :
  \ (mtype2 == 5) ? input.mt_edge("roberts",0,4,0,4).mt_inflate() :
  \ (mtype2 == 6) ? input.mt_edge("prewitt",0,255,0,0).mt_lut("x "+string(mthr2)+" <= x 1 >> x 1.4 ^ ?").RemoveGrain(4,-1).mt_inflate() : nop()
  final_mask = (mtype2 == 0) ? edge_mask_1 : mt_logic(edge_mask_1, edge_mask_2, "max")
return final_mask
}
