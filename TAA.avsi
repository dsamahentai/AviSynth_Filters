###################################################
###                                             ###
###             Taro's Anti-Aliasing            ###
###                                             ###
###       by 06_taro - astrataro@gmail.com      ###
###                                             ###
###          v1.6.2 - 16 February 2012          ###
###                                             ###
###################################################
###
###
### 3-pass anti aliasing method based on eedi2, eedi3, nnedi3 and Sangnom.
### Use Contra-sharpening, LimitedSharpenFaster, lsfmod, HighQualitySharpen for post-sharpening,
### Soothe for combating aliasing caused by post-sharpeners,
### and edge masking and repair for last step post process.
### You can use it in MCAA if other pre/post process is needed.
### Requires YV12 input
###
###
### +-----------+
### | CHANGELOG |
### +-----------+
###
### v1.6.2 - 16 February 2012:
###      - Add "mclip" to define custom edge mask
###      - Add "mthr" to change threshold of edge mask
###
### v1.6.1 - 12 February 2012:
###      - Add aatype=6, ~65% faster in main pass aa than aatype=5, overall speeding up varies on other parameters
###        With mtype=5 and default p2 setting, the quality is nearly the same as aatype=5
###        But with other mtype value, the effect is reduced unless you tune "p2", which may cause some tiny artifacts around intensive lines
###      - Fix a bug in parameters checking
###
### v1.6 - 10 February 2012:
###      - Add eedi3 mode, useful for some aggressive aliasing which need eedi3 for edge linking
###      - Add p1~p6 for customizing parameters in main aa processing
###      - Add prewitt/tcanny/MSharpen edge mask mode
###      - Improved performance for most aatype
###        except for Sangnom with Spline64 enlargement ( previous aatype=4, current aatype=5 ), in which case improvement is not significant
###        e.g., with aatype=1, it is now ~60% faster in main pass aa than v1.5, overall speeding up varies on other parameters
###        the processed result might be slightly different from previous version
###      - Tweak some default settings, now edge mask and post-sharpen is always used by default, except when preaa=aatype=0
###
### v1.5 - 28 November 2011:
###      - Add parameter "predown" to combat with ugly upconverted videos
###      - Add parameter "aarepair" to choose repair mode
###
### v1.4 - 17 November 2011:
###      - Use lsfmod(defaults="old") instead of LimitedSharpenFaster, and therefore LimitedSharpenFaster is not required
###      - Use lsfmod(defaults="fast") when -1<sharp<0, and HQSharpen only applies when 0<sharp<1
###      - Add TEdgeMask to make mask as mtype=3
###      - Change default settings of "mtype", "sharp" and "postaa" to make it faster
###      - Change performance when aatype=4, less ringing, faster and maybe slightly stronger
###      - Fix an issue that FrameBased clip be treated as FieldBased after processing caused by Sangnom
###
### v1.3 - 22 March 2011:
###      - Add LimitedSharpenFaster, HightQualitySharpen to faster post sharpening
###      - Add parameter "src"
###      - Add parameter "postaa" and use Soothe for postaa
###      - Add error messages
###      - Completely change "aatype", use eedi2 for default
###      - Change parameter names, "drc"->"preaa"
###      - Change some default settings
###      - Improve preaa method for efficiency
###      - Rewrite documents
###
### v1.2 - 25 February 2011:
###      - Add "aatype" 3 and 4
###      - Remove "postsh" and use "sharp=-1" instead
###      - Use lsfmod for post-sharpening when sharp>0
###      - Change default setting for "drc" and "sharp"
###
### v1.1 - 22 February 2011:
###      - Add parameter "drc" to specify the direction of preaa process and "postsh" for contra-sharpening
###
### v1.0 - 21 February 2011:
###      - First script
###
###
### +----------------+
### |  REQUIREMENTS  |
### +----------------+
###
### -> eedi2				(v0.9.2)			[for aatype=±1]
### -> eedi3				(v0.9.1)			[for aatype=±2]
### -> nnedi3				(v0.9.4)			[for aatype=±3/4, or preaa!=0, or predown=true & aatype=0]
### -> Masktools2		(v2a48)
### -> Sangnom			(2004.01.18)	[for aatype=-1,-2,-3,4,5,6]
### -> TEdgeMask	  (v0.9)				[for mtype=4]
### -> tcanny       (v1.0)        [for mtype=5]
### -> MSharpen 	  (v1.10)				[for mtype=6]
### -> RemoveGrain	(v1.0)				[for sharp<0 or sharp>1]
### -> Repair				(v1.0)				[for sharp=-1 or aatype=4 or aarepair>0]
### -> lsfmod				(v1.9)				[for sharp>=1 or sharp<0]
### -> Soothe				(2007.07.14)	[for postaa=true]
###
###
### +-------+
### | USAGE |
### +-------+
###
### taa(aatype, preaa, sharp, postaa, mtype, mthr, src, mclip, predown, aarepair, p1, p2, p3, p4, p5, p6)
###
###
### +---------+
### | EXAMPLE |
### +---------+
###
### AVISource("video.avi")
### sharpen(0.8).taa(aatype=2, preaa=-1, sharp=80, postaa=true, mtype=2, src=last, predown=true, aarepair=23)
###
###
### +---------+
### | GENERAL |
### +---------+
###
###
### aatype [int: -3~6, Default=1]
### ----------------------
### Main pass anti-aliasing type:
### = -3 : Vertical and horizontal anti alisasing using nnedi3 and Sangnom
### = -2 : Vertical and horizontal anti alisasing using eedi3 and Sangnom, best for edge linking and with blind anti alisasing, intolerantly slow for HD content
### = -1 : Vertical and horizontal anti alisasing using eedi2 and Sangnom
### =  0 : No second pass anti aliasing
### =  1 : Vertical and horizontal anti alisasing using eedi2, same as ediaa
### =  2 : Vertical and horizontal anti alisasing using eedi3, best for edge linking, intolerantly slow for HD content
### =  3 : Vertical and horizontal anti alisasing using nnedi3
### =  4 : Vertical and horizontal anti alisasing using Sangnom with nnedi3 enlargement
### =  5 : Vertical and horizontal anti alisasing using Sangnom with non-ringing Spline64Resize enlargement
### =  6 : Same as 5, but trade quality for speed, with Repair to fix some artifacts introduced by this particular aatype, recommended to be used with mtype=5
###
###
### p1~p6 [float]
### ----------------------
### Extra parameters in main pass anti-aliasing ( meaning and default value ) :
### +-------------+--------------------+------------------------+----------------------+-----------------------+-----------------+-----------------+
### |   aatype    |         p1         |           p2           |          p3          |          p4           |        p5       |       p6        |
### |-------------+--------------------+------------------------+----------------------+-----------------------+-----------------+-----------------|
### | aatype = -3 | aa=48    (SangNom) | nsize=3       (nnedi3) | nns=1       (nnedi3) | qual=2       (nnedi3) |                 |                 |
### | aatype = -2 | aa=48    (SangNom) | alpha=0.5      (eedi3) | beta=0.2     (eedi3) | gamma=20.0    (eedi3) | nrad=3  (eedi3) | mdis=30 (eedi3) |
### | aatype = -1 | aa=48    (SangNom) | mthresh=10     (eedi2) | lthresh=20   (eedi2) | vthresh=20    (eedi2) | maxd=24 (eedi2) | nt=50   (eedi2) |
### | aatype =  0 |                    |                        |                      |                       |                 |                 |
### | aatype =  1 | mthresh=10 (eedi2) | lthresh=20     (eedi2) | vthresh=20   (eedi2) | maxd=24       (eedi2) | nt=50   (eedi2) |                 |
### | aatype =  2 | alpha=0.5  (eedi3) | beta=0.2       (eedi3) | gamma=20.0   (eedi3) | nrad=3        (eedi3) | mdis=30 (eedi3) |                 |
### | aatype =  3 | nsize=3   (nnedi3) | nns=1         (nnedi3) | qual=2      (nnedi3) |                       |                 |                 |
### | aatype =  4 | aa=48    (SangNom) | nsize=1 (nnedi3_rpow2) | nns=3 (nnedi3_rpow2) | qual=2 (nnedi3_rpow2) |                 |                 |
### | aatype =  5 | aa=48    (SangNom) |                        |                      |                       |                 |                 |
### | aatype =  6 | aa=48    (SangNom) | mode          (repair) |                      |                       |                 |                 |
### |             |                    |   = 0 if mtype==5      |                      |                       |                 |                 |
### |             |                    |   =20 if mtype!=5      |                      |                       |                 |                 |
### +-------------+--------------------+------------------------+----------------------+-----------------------+-----------------+-----------------+
### Although these parameters are provided, there is usually no need to tweak them except for quite aggressive aliasing samples.
###
###
### preaa [int: -1~2, Default=1]
### ----------------------
### Directions for first pass preaa process, the preaa method is based on daa
### = -1 : Horizontally and Vertically
### =  0 : No preaa process
### =  1 : Horizontally
### =  2 : Vertically
###
###
### mtype [int: 0~6, Default=0 (aatype=0 and preaa=0) / 5 (otherwise)]
### ----------------------
### Post-masking type:
### = 0 : No mask
### = 1 : Sobel method edge masking (from maa/shaarp)
### = 2 : Roberts method edge masking (from shaarp)
### = 3 : Prewitt method edge masking (from MCTD)
### = 4 : TEdgeMask method masking, masking with gradient vector magnitude, need TEdgeMask
### = 5 : Canny method edge masking, need tcanny
### = 6 : MSharpen masking, need MSharpen
###
###
### mthr [int: 0~255, Default=32]
### ----------------------
### Threshold for mask (the higher, the less "small edges" are processed), only used when mtype>=3
###
###
### mclip [clip, Default=not set]
### ----------------------
### Custom edge mask clip, only luma is taken to merge all three planes. "mclip" should have the same resolution as "input" clip
###
###
### sharp [int, Default=0.3 (preaa=1 or 2) / -1 (preaa=-1) / 0 (preaa=0 and aatype=0) / 0.2 (preaa=0 and 0<aatype<=3) / 70 (otherwise)]
### --------------
### Method / strength of the post-sharpening
### < -1 : lsfmod's "strength" with defaults="slow", using absolute value, slowest
###        e.g., sharp=-50 means using lsfmod(strength=50, defaults="slow", source=src)
### = -1 : Contra-sharpening after preaa, slow, best for repair details but worst for strong aliasing source
### in (-1,0): lsfmod's "strength" with defaults="fast", using absolute value multiplies 100,
###            e.g., sharp=-0.5 means using lsfmod(strength=50, defaults="fast", source=src)
### =  0 : No postaa sharpening
### in (0,1) : Internal Sharpen's "amount",
###            fastest with moderate quality,
###            using absolute value,
###            method based on HighQualitySharpen by Didée,
###            not recommanded to use value higher or lower than ±0.6
###            e.g., sharp=0.5 means using Sharpen(0.5).MergeChroma(src)
### >  1 : lsfmod's "strength" with defaults="old", the result as well as the speed equals to LimitedSharpenFaster
###        e.g., sharp=50 means using lsfmod(strength=50, defaults="old", source=src)
###
###
### postaa [bool, Default=true (0.4<|sharp|<1 or |sharp|>70) / false (otherwise)]
### ----------------------
### Use Didée's Soothe to combat aliasing introduced by post-sharpeners
###
###
### src [clip, Default=input]
### ----------------------
### Source clip, used for post processing, i.e. lsfmod. "src" clip should have the same resolution as "input" clip
###
###
### predown [bool, Default=false]
### ----------------------
### Whether to downscale input clip or not, gives stronger aa-ed result as well as more loss in details
###
###
### aarepair [int, Default=0 (predown=false) / 24 (otherwise)]
### ----------------------
### "mode" paramter in Repair. TAA can use Repair to merge aa-ed neighbour pixels onto source center pixels to prevent loss in details
### = 0, no repair
### > 0, choose repair mode. Repair works as "input.Repair(aaed_clip, mode=aarepair)"
###      very fast but effective in details retention around edges, which may be covered by the edge masks by mistake with some mtype settings
###
###

FUNCTION taa( clip input,
\             int "aatype",   int "preaa",
\             float "sharp",  bool "postaa",
\             int "mtype",    int "mthr",
\             clip "src",     clip "mclip",
\             bool "predown", int "aarepair",
\             float "p1",     float "p2",     float "p3",
\             float "p4",     float "p5",     float "p6" ) {

  w       = width(input)
  h       = height(input)
  upw4    = Round(w*0.375)*4     # m4(w*1.5)
  uph4    = Round(h*0.375)*4     # m4(h*1.5)
  downw4  = Round(w*0.1875)*4    # m4(w*0.75)
  downh4  = Round(h*0.1875)*4    # m4(h*0.75)

  aatype  = Default(aatype, 1)
  preaa   = Default(preaa,  1)
  mtype   = ( preaa == 0 && aatype == 0 ) ? Default(mtype, 0) : Default(mtype, 5)
  mthr    = Default(mthr,  32)
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
  aarepair= predown ? Default(aarepair, 24) : Default(aarepair, 0)

###

  Assert( isYV12(input),                       """TAA: "input" is not an YV12 clip!"""                  )
  Assert( isYV12(src),                         """TAA: "src" is not an YV12 clip!"""                    )
  Assert( isFrameBased(input),                 """TAA: input clip must be Frame Based!"""               )
  Assert( (aatype>=-3 && aatype<=6),           """TAA: "aatype"(int: -3~6) invalid!"""                  )
  Assert( (preaa>=-1 && preaa<=2),             """TAA: "preaa"(int: -1~2) invalid!"""                   )
  Assert( (mtype>=0 && mtype<=6),              """TAA: "mtype"(int: 0~6) invalid!"""                    )
  Assert( (mthr>=0 && mthr<=255),              """TAA: "mthr"(int: 0~255) invalid!"""                   )
  Assert( (aarepair>=0 && aarepair<=24),       """TAA: "aarepair"(int: 0~24) invalid!"""                )
  Assert( (src.width==w && src.height==h),     """TAA: resolution of "input" and "src" must match!"""   )
  Defined(mclip) ? Assert( (mclip.width==w && mclip.height==h), """TAA: resolution of "input" and "mclip" must match!""" )
  \              : nop()

###

  pindex = aatype + 3
  rp     = ( mtype==5 ) ? 0 : 20
### ---------------------- aatype =   -3,    -2,    -1,    0,    1,     2,    3,    4,    5,    6 ------ ###
  p1 = Default( p1, Select(pindex,    48,    48,    48,    0,   10,   0.5,    3,   48,   48,   48) )
  p2 = Default( p2, Select(pindex,     3,   0.5,    10,    0,   20,   0.2,    1,    1,    0,   rp) )
  p3 = Default( p3, Select(pindex,     1,   0.2,    20,    0,   20,    20,    2,    3,    0,    0) )
  p4 = Default( p4, Select(pindex,     2,    20,    20,    0,   24,     3,    0,    2,    0,    0) )
  p5 = Default( p5, Select(pindex,     0,     3,    24,    0,   50,    30,    0,    0,    0,    0) )
  p6 = Default( p6, Select(pindex,     0,    30,    50,    0,    0,     0,    0,    0,    0,    0) )
### ---------------------- aatype =   -3,    -2,    -1,    0,    1,     2,    3,    4,    5,    6 ------ ###

###

  pdclip = predown ? input.Spline36Resize(downw4, downh4) : input

###

  nn   = pdclip.nnedi3(field=-2)
  nnt  = pdclip.TurnLeft().nnedi3(field=-2).TurnRight()
  clph = mt_average(selecteven(nn), selectodd(nn), U=3, V=3)
  clpv = mt_average(selecteven(nnt), selectodd(nnt), U=3, V=3)
  clp  = mt_average(clph, clpv, U=3, V=3)

###

  preaaC =
  \ (preaa == -1) ? clp :
  \ (preaa == 1) ? clph :
  \ (preaa == 2) ? clpv :
  \                pdclip

###

  aa_clip =
  \ (aatype == -3) ? preaaC.nnedi3(dh=true, field=1, nsize=p2, nns=p3, qual=p4).Spline36Resize(w, uph4, 0, -0.5).TurnRight().nnedi3(dh=true, field=1, nsize=p2, nns=p3, qual=p4).Spline36Resize(uph4, upw4, 0, -0.5).SangNom(aa=p1).TurnLeft().SangNom(aa=p1).Spline36Resize(w, h) :
  \ (aatype == -2) ? preaaC.eedi3(dh=true, field=1, alpha=p2, beta=p3, gamma=p4, nrad=p5, mdis=p6).Spline36Resize(w, uph4, 0, -0.5).TurnRight().eedi3(dh=true, field=1, alpha=p2, beta=p3, gamma=p4, nrad=p5, mdis=p6).Spline36Resize(uph4, upw4, 0, -0.5).SangNom(aa=p1).TurnLeft().SangNom(aa=p1).Spline36Resize(w, h) :
  \ (aatype == -1) ? preaaC.eedi2(field=1, mthresh=p2, lthresh=p3, vthresh=p4, maxd=p5, nt=p6).Spline36Resize(w, uph4, 0, -0.5).TurnRight().eedi2(field=1, mthresh=p2, lthresh=p3, vthresh=p4, maxd=p5, nt=p6).Spline36Resize(uph4, upw4, 0, -0.5).SangNom(aa=p1).TurnLeft().SangNom(aa=p1).Spline36Resize(w, h) :
  \ (aatype ==  1) ? preaaC.eedi2(field=1, mthresh=p1, lthresh=p2, vthresh=p3, maxd=p4, nt=p5).Spline36Resize(w, h, 0, -0.5).TurnRight().eedi2(field=1, mthresh=p1, lthresh=p2, vthresh=p3, maxd=p4, nt=p5).Spline36Resize(h, w, 0, -0.5).TurnLeft() :
  \ (aatype ==  2) ? preaaC.eedi3(dh=true, field=1, alpha=p1, beta=p2, gamma=p3, nrad=p4, mdis=p5).Spline36Resize(w, h, 0, -0.5).TurnRight().eedi3(dh=true, field=1, alpha=p1, beta=p2, gamma=p3, nrad=p4, mdis=p5).Spline36Resize(h, w, 0, -0.5).TurnLeft() :
  \ (aatype ==  3) ? preaaC.nnedi3(dh=true, field=1, nsize=p1, nns=p2, qual=p3).Spline36Resize(w, h, 0, -0.5).TurnRight().nnedi3(dh=true, field=1, nsize=p1, nns=p2, qual=p3).Spline36Resize(h, w, 0, -0.5).TurnLeft() :
  \ (aatype ==  4) ? preaaC.nnedi3_rpow2(rfactor=2, fwidth=upw4, fheight=upw4, nsize=p2, nns=p3, qual=p4).SangNom(aa=p1).TurnRight().SangNom(aa=p1).Spline36Resize(h, w, 0.5, -0.5).TurnLeft() :
  \ (aatype ==  5) ? preaaC.Spline64Resize(upw4, uph4).Repair(preaaC.GaussResize(upw4, uph4, p=100), 1).SangNom(aa=p1).TurnRight().SangNom(aa=p1).Spline36Resize(h, w).TurnLeft() :
  \ (aatype ==  6) ? preaaC.Spline64Resize(w, uph4).SangNom(aa=p1).Spline36Resize(w, h).TurnRight().Spline64Resize(h, upw4).SangNom(aa=p1).Spline36Resize(h, w).TurnLeft().Repair(preaaC, mode=p2) :
  \ predown        ? preaaC.nnedi3_rpow2(rfactor=2, qual=2, cshift="Spline36Resize", fwidth=w, fheight=h) :
  \                  preaaC

###

  postaaC =
  \ (sharp ==  0) ? aa_clip :
  \ (sharp >=  1) ? aa_clip.lsfmod(strength=Int(absSh), defaults="old", source=src) :
  \ (sharp >   0) ? aa_clip.Sharpen(absSh).MergeChroma(src) :
  \ (sharp >  -1) ? aa_clip.lsfmod(strength=Round(absSh*100), defaults="fast", source=src) :
  \ (sharp == -1) ? aa_clip.mt_adddiff(mt_makediff(aa_clip, aa_clip.RemoveGrain((w>1100) ? 20 : 11), U=3, V=3).Repair(mt_makediff(src, aa_clip, U=3, V=3), 13), U=3,V=3) :
  \                 aa_clip.lsfmod(strength=Int(absSh), defaults="slow", source=src)

###

  postaaC = (postaa == false) ? postaaC : Soothe(postaaC, aa_clip, keep=48)

###

  aaed =
  \ Defined(mclip) ? mt_merge(src, postaaC, mclip, luma=true, U=3, V=3) :
  \ (mtype == 1) ? mt_merge(src, postaaC, src.mt_edge("sobel",7,7,5,5).mt_inflate(), luma=true, U=3, V=3 ) :
  \ (mtype == 2) ? mt_merge(src, postaaC, src.mt_edge("roberts",0,4,0,4).mt_inflate(), luma=true, U=3, V=3 ) :
  \ (mtype == 3) ? mt_merge(src, postaaC, src.mt_edge("prewitt",0,255,0,0).mt_lut("x "+string(mthr)+" <= x 1 >> x 1.4 ^ ?").RemoveGrain(4,-1).mt_inflate(), luma=true, U=3, V=3 ) :
  \ (mtype == 4) ? mt_merge(src, postaaC, src.TEdgeMask(link=2, preblur=false, valon=-1).mt_lut("x "+string(mthr/5)+" <= x 1 >> x 4 << ?", U=1, V=1).mt_deflate().RemoveGrain( (w>1100) ? 20 : 11, -1 ), luma=true, U=3, V=3 ) :
  \ (mtype == 5) ? mt_merge(src, postaaC, src.tcanny(sigma=1.2, mode=1).mt_lut("x "+string(mthr)+" <= x 1 >> x 1 << ?", U=1, V=1).RemoveGrain((w>1100) ? 20 : 11, -1).mt_inflate(), luma=true, U=3, V=3 ) :
  \ (mtype == 6) ? mt_merge(src, postaaC, src.MSharpen(threshold=mthr/5, strength=0, mask=true, highq=false), luma=true, U=3, V=3 ) :
  \                postaaC

  return ( aarepair==0 ) ? aaed.AssumeFrameBased() : input.Repair(aaed, mode=aarepair).AssumeFrameBased()

}
