###### Contra-Sharpen mod 3.4 ###### by mawen1250 ###### 2012.09.21 ###### uMod r1 2015.05.05 ######
###### Requirements: masktools v2.0a48/v2.0b1, mvtools v2.5.11.3/v2.6.0.5, RemoveGrain + Repair v1.0pre / RgTools v0.92.1, RemoveGrainHD v0.5  ######
###### FluxSmooth v1.1b, nnedi3 v0.9.4, SangNom2 v0.35 + FTurn v1.4 (filter_ss="AA"), TEMmod v0.2.0, TCannyMod v0.1.1, MSharpen v1.10/v0.9@tp7 ######

Function CSmod(clip filtered, clip "source", clip "pclip", bool "chroma",
\ int "edgemode", val "edgemask", float "edgethr", float "tcannysigma", bool "tcannysobel", bool "mergesrc",
\ float "ss_w", float "ss_h", bool "ss_hq", string "ssmethod", string "filter_ss", bool "ssrep", bool "ssout", bool "ssoutc",
\ int "preblur", bool "prec", int "preR", bool "usepasf",
\ int "Smethod", val "kernel", bool "secure", string "filter_nr",
\ val "Smode", float "strength", float "divisor", float "index", float "Szrp", float "Spwr", float "SdmpLo", float "SdmpHi",
\ bool "Slimit", bool "Tlimit", int "Sovershoot", int "Sundershoot", int "Tovershoot", int "Tundershoot",
\ float "Soft", int "Soothe",
\ bool "limit", int "Repmode", int "RepmodeU", int "thr", int "thrc",
\ bool "chromamv", int "blksize", int "overlap", int "thSAD", int "thSCD1", int "thSCD2",
\ bool "truemotion", bool "MVglobal", int "pel", int "pelsearch", int "search", int "searchparam", int "MVsharp", int "DCT")
{

defsrc   = Defined(source   )
defpclp  = Defined(pclip    )
deffss   = Defined(filter_ss)
deffnr   = Defined(filter_nr)
AA       = deffss ? filter_ss=="AA" : false
sw       = filtered.width()
sh       = filtered.height()
HD       = (sw > 1024 || sh > 576) ? true : false

chroma   = Default(chroma,  false  )

edgemode    = Default(edgemode,    AA ? 1 : 0  )
# 0 = Sharpening all, 1 = Sharpening only edge, 2 = Sharpening only non-edge.
# By default, edgemode=2 is tuned for enhancing noise/small detail.
# It will automatically set [edgemask=-2, ss_w=1, ss_h=1, preblur=0, kernel=5, Slimit=false, Tlimit=true(when limit=false)].
edgemask    = Default(edgemask,    edgemode==2?-2:AA?7:2)
# -1: Similar to 1 and tweaking for edgemode=2,   -2: Similar to 2 and tweaking for edgemode=2,
#  1: Same as edgemaskHQ=false in LSFmod(min/max), 2: Same as edgemaskHQ=true in LSFmod,
#  3: Same as sharpening mask in MCTD(prewitt),    4: Same as mtype=1 in TAA(sobel),
#  5: Same as mtype=2 in TAA(roberts),             6: Same as mtype=3 in TAA(prewitt),
#  7: Same as mtype=4 in TAA(TEdgeMask),           8: Same as mtype=5 in TAA(tcanny),
#  9: Same as mtype=6 in TAA(MSharpen),           10: (or any other numbers) My own method of tcanny usage.
#     Otherwise define a custom edge mask clip, only luma is taken to merge all planes.
edgethr     = Default(edgethr,     32.0        )   #Tweak edge mask thr in edgemask mode -2/-1/1/2/6/7/8/9/10.
tcannysigma = Default(tcannysigma, 1.2         )   #Tweak tcanny's sigma in edgemask mode 8/10.
tcannysobel = Default(tcannysobel, false       )   #If set to true, Tcanny edge detection will use a Sobel operator instead of [1, 0, -1].
mergesrc    = Default(mergesrc,    false       )   #Whether to merge clip "source" instead of clip "filtered" at the end of processing.

ss_w     = Default(ss_w,    edgemode>=2?1.00:1.50)   #Super sampling multiplier of width.
ss_h     = Default(ss_h,    edgemode>=2?1.00:1.50)   #Super sampling multiplier of height.
ss_w     = max    (ss_w,    1.00   )
ss_h     = max    (ss_h,    1.00   )
ss_hq    = Default(ss_hq,   ss_w*ss_h>=3.0625)   #True using nnedi3_rpow2 in super sampling, false using non-ringing Spline64Resize.
ssout    = Default(ssout,   false  )   #Output in super sampling resolution.
ssoutc   = Default(ssoutc,  true   )   #Whether to output correct chroma when (chroma==false && ss_hq==false && ssout==true).
ssrep    = Default(ssrep,   false  )   #When limiting sharpening to source clip, whether to Repair in super sampling resolution.
ssout    = (ss_w > 1.0 || ss_h > 1.0) ? ssout : false
ssrep    = (ss_w > 1.0 || ss_h > 1.0) ? ssrep : false
ssoutc   = (!chroma && ssout) ? ssoutc : false
ssrep    = ssout ? true : ssrep
filter_ss= deffss ? AA ? "SangNom2(aa=48).FTurnRight().SangNom2(aa=48).FTurnLeft()" : filter_ss : NOP()
# When defining filter_ss="AA", it will automatically use SangNom2 for anti-aliasing in super sampling clip, and it will automatically set [Repmode=13, edgemode=1, edgemask=7].

preblur  = Default(preblur, AA?0:edgemode>=2?0:ss_w*ss_h>=9?-3:ss_w*ss_h>=4?-2:-1)
# Pre-filtering, 0 = disable, -1 = Gaussian Blur radius=1(RG11), -2 = Gaussian Blur radius=2(RG11+RG20),
# -3 = Gaussian Blur radius=3(RG11+RG20+RG20), -4 = Median Blur radius=1(RG4),
# 1 = MinBlur, 2 = MinBlur(Uses SBR by default) mixed with MinBlur+FluxSmoothT,
# 3 = MinBlur(Uses SBR by default)+FluxSmoothT.
# "preblur" is ignored when pclip is defined.
prec     = Default(prec,    true   )   #Whether to process chroma plane in preblur.
preR     = Default(preR,    preblur>=2?0:ss_w*ss_h>6.25?3:ss_w*ss_h>2.25?2:1)
# MinBlur setting, 1-3 sets radius of MinBlur(Gaussian|Median), 0 uses SBR instead of normal Gaussian Blur in MinBlur.
usepasf  = Default(usepasf, false  )
# Whether to use pre-filtered clip as input(filtered) clip, which will reduce noise/halo/ring from input clip.
usepasf  = (preblur==0 && !defpclp) ? false : usepasf

Smethod  = Default(Smethod, ss_w*ss_h>1&&!AA?3:1)   #Sharpen Method - 1: 3x3 kernel, 2: Min/Max, 3: Min/Max + 3x3 kernel.
kernel   = Default(kernel,  edgemode>=2 ? 5 : Smethod>=3 ? ss_w*ss_h>=9?4:ss_w*ss_h>=4?3:ss_w*ss_h>=2.25?2:1
\                                                        : ss_w*ss_h>=4?4:ss_w*ss_h>=2.25?3:ss_w*ss_h> 1?2:1)
# 1: Gaussian Blur radius=1(RG11), 2: Average Blur(RG20), 3: Gaussian Blur radius=2(RG11+RG20), 
# 4: Gaussian Blur radius=3(RG11+RG20+RG20), 5: for noise/detail enhance(RG19+RG4), default for edgemode==2,
# Otherwise define a custom kernel in string such as kernel="RemoveGrain(20, 11)".
secure   = Default(secure,  true   )   #Mode to avoid banding & oil painting (or face wax) effect of sharpening.(from LSFmod)
Smode    = Default(Smode,   3      )
# Sharpen Mode - 0: None, 1: Linear, 2: Non-linear 1, 3:Non-linear 2(from LSFmod Smode=5), Otherwise define a custom Smode in string.
divisor  = Default(divisor, 1.5    )
index    = Default(index,   0.8    )
#strength = Default(strength,120.0  )
Szrp     = Default(Szrp,    16     )
Spwr     = Default(Spwr,    4      )
SdmpLo   = Default(SdmpLo,  4      )
SdmpHi   = Default(SdmpHi,  48     )
miSpwr   = 1.0/Spwr

limit    = Default(limit,   true   )
# Whether to limit sharpening to source clip, only takes effect when (Defined(source) || Defined(filter_ss) || usepasf) == true.
thr      = Default(thr,     0      )
thrc     = Default(thrc,    thr    )
# Allow sharpening more than the source pixel in [thr/thrc](luma/chroma).
Repmode  = Default(Repmode, AA?13:1)
RepmodeU = Default(RepmodeU,Repmode)
thrc     = chroma ? thrc : 0
limit    = defsrc || deffss || usepasf || deffnr ? limit : false

Slimit      = Default(Slimit,      edgemode>=2?false:!limit)
# Spatial limit with overshoot and undershoot. Disabled when (limit==true && thr==0 && thrc==0).
Tlimit      = Default(Tlimit,      edgemode>=2&&!limit?true:false)
# Use MC Temporal limit at the end of sharpening(only process luma).(from MCTD)
strength    = Default(strength,    Tlimit?160:120)
Sovershoot  = Default(Sovershoot,  Round(strength/160))
Sundershoot = Default(Sundershoot, Sovershoot  )
Tovershoot  = Default(Tovershoot,  edgemode>=2?Round(strength/80):Round(strength/40))
Tundershoot = Default(Tundershoot, Tovershoot  )
Soft        = Default(Soft,        limit?  0:-2)
# Soft the sharpening effect (-1 = old autocalculate, -2 = new autocalculate, 0 = disable, (0, 100] = enable).
# Disabled when (limit==true && thr==0 && thrc==0).(from LSFmod)
Soothe      = Default(Soothe,      limit? -1:24)
# Soothe temporal stabilization, 0-100 sets minimum percent of the original sharpening to keep, -1 disables Soothe. Disabled when (chroma==true && Tlimit=true).
Sovershoot  = max(Sovershoot,  0)
Sundershoot = max(Sundershoot, 0)
Tovershoot  = max(Tovershoot,  0)
Tundershoot = max(Tundershoot, 0)

chromamv    = Default(chromamv,    chroma      )
blksize     = Default(blksize,     HD ? 16 : 8 )
overlap     = Default(overlap,     blksize/2   )
thSAD       = Default(thSAD,       300         )
thSCD1      = Default(thSCD1,      300         )
thSCD2      = Default(thSCD2,      100         )
truemotion  = Default(truemotion,  false       )
MVglobal    = Default(MVglobal,    true        )
pel         = Default(pel,         2           )
pelsearch   = Default(pelsearch,   2           )
search      = Default(search,      2           )
searchparam = Default(searchparam, 2           )
MVsharp     = Default(MVsharp,     2           )
DCT         = Default(DCT,         0           )


wss      = Round(sw*ss_w/8)*8
hss      = Round(sh*ss_h/8)*8
rfactor  = max(Round(sqrt(ss_w*ss_h)/2)*2, 2)
ssmethod = Defined(ssmethod) ? ssmethod
\        : ss_hq ? """nnedi3_rpow2(rfactor=rfactor, qual=2, cshift="Spline64Resize", fwidth=wss, fheight=hss)"""
\                : "CSmod_nrSpline64Resize(wss, hss, chroma=chroma||ssoutc, nr=true)"
# You can define your own super sampling method with ssmethod.

ch21     = chroma ? 2 : 1
ch31     = chroma ? 3 : 1
ch41     = chroma ? 4 : 1
ch32     = chroma ? 3 : 2
ch34     = chroma ? 3 : 4
Slimit   = limit && thr==0 && thrc==0 ? false : Slimit
Soft     = limit && thr==0 && thrc==0 ? 0
\        : Soft <= -2  ? (1.0+(2.0/(ss_w+ss_h))) * sqrt(strength)
\        : Soft == -1  ? sqrt( (((ss_w+ss_h)/2.0-1.0)*100.0) ) * 10
\        : Soft <= 100 ? Soft : 100
Soothe   = Tlimit ? -1 : Soothe


# super sampling, filtering in ss clip
source      = defsrc ? source : filtered
filtered_os = filtered
filtered_ss = (ss_w > 1.0 || ss_h > 1.0) ? Eval("filtered."+ssmethod) : filtered
source_ss   = (ss_w > 1.0 || ss_h > 1.0) ? defsrc ? Eval("source."+ssmethod) : filtered_ss : source
filtered    = deffss ? Eval("filtered_ss."+filter_ss) : filtered_ss
filtered_ds = (ss_w > 1.0 || ss_h > 1.0) ? deffss ? filtered.CSmod_nrSpline64Resize(sw, sh, chroma=chroma, nr=0) : filtered_os : filtered

Assert( (isFrameBased(filtered_os)),                            """CSmod: input clip "filtered" must be Frame Based!""" )
Assert( (isFrameBased(source)),                                   """CSmod: input clip "source" must be Frame Based!""" )
Assert( (source.width() == sw && source.height() == sh), """CSmod: resolution of "filtered" and "source" must match!""" )


# pre-filtering before sharpening
spatial     = filtered.MinBlur(preR, chroma ? prec ? 3 : 2 : 1)
temporal    = spatial .FluxsmoothT(7).Repair(spatial, 1, prec ? 1 : -1)
temporal    = chroma&&!prec ? temporal.MergeChroma(filtered) : temporal
mixed       = temporal.merge(spatial,0.251)
pre         = defpclp     ? pclip
\           : preblur<=-4 ? filtered.RemoveGrain(4 , chroma?prec?4 :0:-1)
\           : preblur==-3 ? filtered.RemoveGrain(11, chroma?prec?11:0:-1).RemoveGrain(20, chroma?prec?20:0:-1).RemoveGrain(20, chroma?prec?20:0:-1)
\           : preblur==-2 ? filtered.RemoveGrain(11, chroma?prec?11:0:-1).RemoveGrain(20, chroma?prec?20:0:-1)
\           : preblur==-1 ? filtered.RemoveGrain(11, chroma?prec?11:0:-1)
\           : preblur== 1 ? spatial
\           : preblur== 2 ? mixed
\           : preblur>= 3 ? temporal
\           : filtered
# You can define your own pre-filter clip with pclip.
pre_ds      = (pre.width() == sw && pre.height() == sh) ? pre : pre.CSmod_nrSpline64Resize(sw, sh, chroma=chroma, nr=0)
pre         = (ss_w > 1.0 || ss_h > 1.0) ? (pre.width() == wss && pre.height() == hss) ? pre : Eval("pre."+ssmethod) : pre_ds

# whether to use pre-filtered clip as main clip
filtered    = usepasf ? pre    : filtered
filtered_ds = usepasf ? pre_ds : filtered_ds


# generate edge mask
prefinal  = ssout ? Tlimit&&!chroma&&chromamv ? pre.MergeChroma(filtered_ss) : pre : Tlimit&&!chroma&&chromamv ? pre_ds.MergeChroma(filtered_os) : pre_ds
srcfinal  = ssout ? source_ss                                                      : source
edgemask  = IsClip(edgemask) ? edgemask
\         : IsInt (edgemask) ?
\           edgemask <= -2   ? mt_logic(prefinal.mt_edge(thY1=0, thY2=255, "8 16 8 0 0 0 -8 -16 -8 4", U=1, V=1),
\                                       prefinal.mt_edge(thY1=0, thY2=255, "8 0 -8 16 0 -16 8 0 -8 4", U=1, V=1),
\                                       "max", U=1, V=1).mt_lut("x " + string(edgethr*4) + " / 0.86 ^ 255 *", U=1, V=1)
\                             .Removegrain(11, -1)
\         : edgemask == -1   ? prefinal.mt_edge(thY1=0, thY2=255, mode="min/max", U=1, V=1)
\                             .mt_lut("x " + string(edgethr) + " / 0.86 ^ 255 *", U=1, V=1)
\                             .Removegrain(11, -1)
\         : edgemask == 1    ? prefinal.mt_edge(thY1=0, thY2=255, mode="min/max", U=1, V=1)
\                             .mt_lut("x " + string(edgethr) + " / 0.86 ^ 255 *", U=1, V=1)
\                             .mt_inflate(U=1, V=1).mt_inflate(U=1, V=1).Removegrain(11, -1)
\         : edgemask == 2    ? mt_logic(prefinal.mt_edge(thY1=0, thY2=255, "8 16 8 0 0 0 -8 -16 -8 4", U=1, V=1),
\                                       prefinal.mt_edge(thY1=0, thY2=255, "8 0 -8 16 0 -16 8 0 -8 4", U=1, V=1),
\                                       "max", U=1, V=1).mt_lut("x " + string(edgethr*4) + " / 0.86 ^ 255 *", U=1, V=1)
\                             .mt_inflate(U=1, V=1).mt_inflate(U=1, V=1).RemoveGrain(11, -1)
\         : edgemask == 3    ? mt_edge(prefinal, "prewitt", 0, 255, 0, 0, V=1, U=1)
\                             .mt_lut("x 1.8 ^", U=1, V=1).RemoveGrain(4, -1).mt_inflate(U=1, V=1).RemoveGrain(20,-1)
\         : edgemask == 4    ? mt_edge(prefinal, "sobel", 7, 7, 5, 5, U=1, V=1).mt_inflate(U=1, V=1)
\         : edgemask == 5    ? mt_edge(prefinal, "roberts", 0, 4, 0, 4, U=1, V=1).mt_inflate(U=1, V=1)
\         : edgemask == 6    ? mt_edge(prefinal, "prewitt", 0, 255, 0, 0, U=1, V=1)
\                             .mt_lut("x " + string(edgethr) + " <= x 1 >> x 1.4 ^ ?", U=1, V=1)
\                             .RemoveGrain(4, -1).mt_inflate(U=1, V=1)
\         : edgemask == 7    ? TEMmod(prefinal, link=2, preblur=false, scale=0, chroma=0)
\                             .mt_lut("x " + string(edgethr/5) + " <= x 1 >> x 4 << ?", U=1, V=1)
\                             .mt_deflate(U=1, V=1).RemoveGrain(HD ? 20 : 11, -1)
\         : edgemask == 8    ? TCannyMod(srcfinal, sigma=tcannysigma, mode=1, chroma=0, sobel=tcannysobel)
\                             .mt_lut("x " + string(edgethr) + " <= x 1 >> x 1 << ?", U=1, V=1)
\                             .RemoveGrain(HD ? 20 : 11, -1).mt_inflate(U=1, V=1)
\         : edgemask == 9    ? MSharpen(prefinal, threshold=Round(edgethr/5), strength=0, mask=true, highq=false)
\         :                    TCannyMod(srcfinal, sigma=tcannysigma, mode=1, chroma=0, sobel=tcannysobel)
\                             .mt_lut("x " + string(edgethr) + " <= 0 x " + string(edgethr) + " - 6 << ?", U=1, V=1)
\                             .RemoveGrain(HD ? 20 : 11, -1).mt_inflate(U=1, V=1)
\         :                    Assert(false, """CSmod: "edgemask" should be int or clip!""")


# unsharp
dark_limit   = pre.mt_inpand(U=ch31, V=ch31)
bright_limit = pre.mt_expand(U=ch31, V=ch31)
minmaxavg    = mt_average(dark_limit, bright_limit, U=ch31, V=ch31)

method     = Smethod <= 1     ? pre : minmaxavg

method     = Smethod == 2     ? method
\          : IsString(kernel) ? Eval("method."+kernel)
\          : IsInt   (kernel) ?
\            kernel <= 1      ? method.RemoveGrain(11, chroma?11:-1)
\          : kernel == 2      ? method.RemoveGrain(20, chroma?20:-1)
\          : kernel == 3      ? method.RemoveGrain(11, chroma?11:-1).RemoveGrain(20, chroma?20:-1)
\          : kernel == 4      ? method.RemoveGrain(11, chroma?11:-1).RemoveGrain(20, chroma?20:-1).RemoveGrain(20, chroma?20:-1)
\          :                    method.RemoveGrain(19, chroma?19:-1).RemoveGrain(4 , chroma?4 :-1)
\          :                    Assert(false, """CSmod: "kernel" should be int or string!""")

method     = secure           ? method.mt_lutxy(pre, "x y < x 1 + x y > x 1 - x ? ?", U=ch31, V=ch31) : method


# making difference clip for sharpening
sharpdiff  = mt_makediff(pre, method, U=ch31,V=ch31)


# filtering in nr clip
filtered   = deffnr ? Eval("method." + filter_nr).mt_adddiff(sharpdiff, U=ch31, V=ch31) : filtered
filtered_ds= (ss_w > 1.0 || ss_h > 1.0) ? deffnr      ? filtered.CSmod_nrSpline64Resize(sw, sh, chroma=chroma, nr=0)
\                                       : filtered_ds : filtered


# sharpening diff generate mode
sharpdiff  = IsString(Smode)  ? sharpdiff.mt_lut(Smode, U=ch31, V=ch31)
\          : IsInt   (Smode)  ?
\            Smode <= 0       ? sharpdiff
\          : Smode == 1       ? sharpdiff.mt_lut("x 128 == x x 128 - "+string(strength/50.0)+" * 128 + ?", U=ch31, V=ch31)
\          : Smode == 2       ? sharpdiff.mt_lut("x 128 == x x 128 - "+String(divisor)+" / Abs "+String(index)+" ^ "+String(strength/20.0)+" * x 128 > 1 -1 ? * 128 + ?", U=ch31, V=ch31)
\          :                    sharpdiff.mt_lut("x 128 == x x 128 - abs "+string(Szrp)+" / "+string(miSpwr)+" ^ "+string(Szrp)+" * "+string(strength/100.0)+" * x 128 > 1 -1 ? * x 128 - 2 ^ "+string(Szrp)+" 2 ^ "+string(SdmpLo)+" + * x 128 - 2 ^ "+string(SdmpLo)+" + "+string(Szrp)+" 2 ^ * / * 1 "+string(SdmpHi)+" 0 == 0 "+string(Szrp)+" "+string(SdmpHi)+" / 4 ^ ? + 1 "+string(SdmpHi)+" 0 == 0 x 128 - abs "+string(SdmpHi)+" / 4 ^ ? + / * 128 + ?", U=ch31, V=ch31)
\          :                    Assert(false,  """CSmod: "Smode" should be int or string!""")

# x==128 ? x : (abs(x-128)/Szrp)^(miSpwr)*Szrp*(strength/100.0)*(x>128 ? 1 : -1) * ((x-128)^2*(Szrp^2+SdmpLo) / ((x-128)^2+SdmpLo)*Szrp^2) * ((1+ SdmpHi==0 ? 0 : (Szrp/SdmpHi)^4) / (1+ SdmpHi==0 ? 0 : (abs(x-128)/SdmpHi)^4)) + 128


# spatial limit
DlimitF    = usepasf || (preblur==0 && !defpclp) ?   dark_limit : filtered.mt_inpand(U=ch31, V=ch31)
BlimitF    = usepasf || (preblur==0 && !defpclp) ? bright_limit : filtered.mt_expand(U=ch31, V=ch31)
sclp       = Slimit ? mt_adddiff(filtered, sharpdiff, U=ch31, V=ch31) : NOP()
sclp       = Slimit ? sclp.mt_clamp(BlimitF, DlimitF, Sovershoot, Sundershoot, U=ch31, V=ch31) : NOP()


# Soft
sharpdiff  = Slimit ? mt_makediff(sclp, filtered, U=ch31, V=ch31) : sharpdiff
sharpdiff  = Soft == 0 ? sharpdiff : mt_lutxy(sharpdiff, sharpdiff.RemoveGrain(19, chroma ? 19 : -1), "x 128 - abs y 128 - abs > y "+string(Soft)+" * x "+string(100-Soft)+" * + 100 / x ?", U=ch31, V=ch31)


# Soothe
sharpdiff2 = (Soothe >= 0 && Soothe <= 100) ? sharpdiff.temporalsoften(1,255,chroma ? 255 : 0,32,2) : NOP()
sharpdiff  = (Soothe >= 0 && Soothe <= 100) ? mt_lutxy(sharpdiff, sharpdiff2, "x 128 - y 128 - * 0 < x 128 - 100 / "+string(Soothe)+" * 128 + x 128 - abs y 128 - abs > x "+string(Soothe)+" * y 100 "+string(Soothe)+" - * + 100 / x ? ?", U=ch31, V=ch31) : sharpdiff


# the difference achieved by filtering
allD       = limit  ? ssrep && (ss_w > 1.0 || ss_h > 1.0) ? mt_makediff(source_ss, filtered, U=ch31, V=ch31)
\                                                         : mt_makediff(source, filtered_ds, U=ch31, V=ch31) : NOP()

# limiting sharpening to source clip
sharpdiff  = !ssrep && (ss_w > 1.0 || ss_h > 1.0) ? sharpdiff.CSmod_nrSpline64Resize(sw, sh, chroma=chroma, nr=0) : sharpdiff
ssDD       = limit  ? sharpdiff.Repair(allD, mode=Repmode, modeU=chroma ? RepmodeU : -1) : sharpdiff
ssDD       = limit && (thr >  0 || thrc >  0) ? sharpdiff.mt_lutxy(ssDD,
\                                               yexpr="x 128 - abs y 128 - abs " + string(thr ) + " + <= x y 128 < y " + string(thr ) + " - y " + string(thr ) + " + ? ?",
\                                               uexpr="x 128 - abs y 128 - abs " + string(thrc) + " + <= x y 128 < y " + string(thrc) + " - y " + string(thrc) + " + ? ?",
\                                               vexpr="x 128 - abs y 128 - abs " + string(thrc) + " + <= x y 128 < y " + string(thrc) + " - y " + string(thrc) + " + ? ?",
\                                               U=ch31, V=ch31) : ssDD
ssDD      = !limit && (thr >  0 || thrc >  0) ? sharpdiff.mt_lut(
\                                               yexpr="x 128 - abs " + string(thr ) + " <= x x 128 < " + string(128-thr ) + " " + string(128+thr ) + " ? ?",
\                                               uexpr="x 128 - abs " + string(thrc) + " <= x x 128 < " + string(128-thrc) + " " + string(128+thrc) + " ? ?",
\                                               vexpr="x 128 - abs " + string(thrc) + " <= x x 128 < " + string(128-thrc) + " " + string(128+thrc) + " ? ?",
\                                               U=ch31, V=ch31) : ssDD
ssDD       = limit && (thr == 0 && thrc == 0) ? ssDD.mt_lutxy(sharpdiff, "x 128 - abs y 128 - abs <= x y ?", U=ch31, V=ch31) : ssDD
ssDD       = ssrep && (ss_w > 1.0 || ss_h > 1.0) && !ssout ? ssDD.CSmod_nrSpline64Resize(sw, sh, chroma=chroma, nr=0) : ssDD

# add difference clip to clip "filtered" of ss/original resolution
sclp       = ssout ? mt_adddiff(filtered, ssDD, U=ch31, V=ch31) : mt_adddiff(filtered_ds, ssDD, U=ch31, V=ch31)


# temporal limit

sMVS       = prefinal.MSuper(hpad=0, vpad=0, pel=pel, levels=0, sharp=MVsharp, chroma=chromamv)
rMVS       = usepasf || (preblur==0 && !defpclp) ? sMVS
\                                                : srcfinal.MSuper(hpad=0, vpad=0, pel=pel, levels=1, sharp=MVsharp, chroma=chroma)
f1v        = MAnalyse(sMVS, isb=false, delta=1, truemotion=truemotion, blksize=blksize, overlap=overlap, pelsearch=pelsearch, search=search, searchparam=searchparam, DCT=DCT, global=MVglobal, chroma=chromamv)
b1v        = MAnalyse(sMVS, isb=true,  delta=1, truemotion=truemotion, blksize=blksize, overlap=overlap, pelsearch=pelsearch, search=search, searchparam=searchparam, DCT=DCT, global=MVglobal, chroma=chromamv)
f1c        = MCompensate(srcfinal, rMVS, f1v, thSAD=thSAD, thSCD1=thSCD1, thSCD2=thSCD2)
b1c        = MCompensate(srcfinal, rMVS, b1v, thSAD=thSAD, thSCD1=thSCD1, thSCD2=thSCD2)
Tmax       = srcfinal.mt_logic(f1c, "max", U=ch31, V=ch31).mt_logic(b1c, "max", U=ch31, V=ch31)
Tmin       = srcfinal.mt_logic(f1c, "min", U=ch31, V=ch31).mt_logic(b1c, "min", U=ch31, V=ch31)
sclp       = Tlimit ? sclp.mt_clamp(Tmax, Tmin, Tovershoot, Tundershoot, U=ch32, V=ch32) : sclp


# merge with edge mask and output correct chroma
merged_ss  = mergesrc ? source_ss : filtered_ss
merged_os  = mergesrc ? source    : filtered_os

end        = edgemode <= 0 ? chroma ? sclp
\                                   : ssout ? ssoutc ? sclp.MergeChroma(merged_ss)
\                                                    : sclp
\                                           : sclp.MergeChroma(merged_os)
\          : edgemode == 1 ? ssout ? mt_merge(merged_ss, sclp, edgemask, luma=chroma, Y=3, U=ssoutc?ch32:ch31, V=ssoutc?ch32:ch31)
\                                  : mt_merge(merged_os, sclp, edgemask, luma=chroma, Y=3, U=ch32,             V=ch32            )
\                          : ssout ? mt_merge(sclp, merged_ss, edgemask, luma=chroma, Y=3, U=ssoutc?ch34:ch31, V=ssoutc?ch34:ch31)
\                                  : mt_merge(sclp, merged_os, edgemask, luma=chroma, Y=3, U=ch34,             V=ch34            )

return end
}


Function MinBlur(clip clp, int "r", int "uv"){

r     = Default(r,  1)
uv    = Default(uv, 3)

uv2   = (uv==2) ? 1  : uv
rg4   = (uv==3) ? 4  : -1
rg11  = (uv==3) ? 11 : -1
rg20  = (uv==3) ? 20 : -1
medf  = (uv==3) ? 1  : -200
uvm2  = (r==2)  ? (uv==3?3:uv==2?0:-1) : nop()
uvm3  = (r==3)  ? (uv==3?3:uv==2?0:-1) : nop()

RG11D = (r<=0) ? mt_makediff(clp, clp.sbr(uv=uv2), U=uv2, V=uv2)
\     : (r==1) ? mt_makediff(clp, clp.RemoveGrain(11, rg11), U=uv2, V=uv2)
\     : (r==2) ? mt_makediff(clp, clp.RemoveGrain(11, rg11).RemoveGrain(20, rg20), U=uv2, V=uv2)
\     :          mt_makediff(clp, clp.RemoveGrain(11, rg11).RemoveGrain(20, rg20).RemoveGrain(20, rg20), U=uv2, V=uv2)
RG4D  = (r<=1) ? mt_makediff(clp, clp.RemoveGrain(4,  rg4 ), U=uv2, V=uv2)
\     : (r==2) ? mt_makediff(clp, clp.Quantile(radius_y=2, radius_u=uvm2, radius_v=uvm2), U=uv2, V=uv2)
\     :          mt_makediff(clp, clp.Quantile(radius_y=3, radius_u=uvm3, radius_v=uvm3), U=uv2, V=uv2)

DD    = mt_lutxy(RG11D, RG4D, "x 128 - y 128 - * 0 < 128 x 128 - abs y 128 - abs < x y ? ?", U=uv2, V=uv2)

return clp.mt_makediff(DD, U=uv, V=uv)
}


Function sbr(clip c, int "uv") {
uv     = Default(uv, 1)
uv2    = (uv==2) ? 1  : uv
rg11   = (uv==3) ? 11 : -1
rg11D  = mt_makediff(c, c.RemoveGrain(11, rg11), U=uv2, V=uv2)
rg11DD = mt_lutxy(rg11D, rg11D.RemoveGrain(11, rg11), "x y - x 128 - * 0 < 128 x y - abs x 128 - abs < x y - 128 + x ? ?", U=uv2, V=uv2)

return c.mt_makediff(rg11DD, U=uv, V=uv)
}


Function CSmod_nrSpline64Resize(clip input, int "target_width", int "target_height", float "src_left", float "src_top", float "src_width", float "src_height", bool "chroma", val "nr") {

  w             = input.Width
  h             = input.Height
  
  target_width  = Default(target_width,      w)
  target_height = Default(target_height,     h)
  src_left      = Default(src_left,          0)
  src_top       = Default(src_top,           0)
  src_width     = Default(src_width,         w)
  src_height    = Default(src_height,        h)
  chroma        = Default(chroma,         true)
  nr            = Default(nr,             true)

  nr        = IsInt(nr) ? Float(nr) : nr
  Assert( IsFloat(nr) || IsBool(nr), """CSmod_nrSpline64Resize: "nr" should be either bool or float!""" )

  res_mul   = Float( target_width * target_height ) / Float( w * h )
  res_mul   = min( max( res_mul, 1 ), 2.25 )
  nr_weight = IsFloat(nr)       ? nr
  \         : nr /* == True  */ ? Spline( res_mul, 1, 0, 2.25, 1, 3.5, 0, true )
  \         :    /* == False */   0
  nr_weight = min( max( nr_weight, 0 ), 1 )
  
  forceYV12 = input.IsYV12 == false && nr_weight != 0

  try {
    inputp = chroma ? forceYV12 ? input .ConvertToYV12
	\                           : input
	\               : input.ConvertToY8
  } catch ( error_msg ) {
    inputp = forceYV12 ? input.ConvertToYV12
    \                  : input
  }
  
  resize = inputp.Spline64Resize(target_width, target_height, src_left, src_top, src_width, src_height)
  nrres  = inputp.GaussResize(target_width, target_height, src_left, src_top, src_width, src_height, p=100)
  resize = resize.CSmod_GetCSP == "Y8" ? resize.ConvertToYV12 : resize
  nrres  = nrres .CSmod_GetCSP == "Y8" ? nrres .ConvertToYV12 : nrres 

  resize = nr_weight == 0 ? resize
  \      : nr_weight == 1 ? resize.Repair(nrres, 1, chroma ? 1 : -1)
  \      : chroma         ? Merge    (resize, resize.Repair(nrres, 1,  1), nr_weight)
  \                       : MergeLuma(resize, resize.Repair(nrres, 1, -1), nr_weight)
  
  return resize
}


Function CSmod_GetCSP(clip c) {
  return c.IsPlanar ? c.IsYV12 ? "YV12" :
  \                   c.IsYV16 ? "YV16" :
  \                   c.IsYV24 ? "YV24" : c.CSmod_Y8_YV411 :
  \      c.IsYUY2   ? "YUY2"   :
  \      c.IsRGB32  ? "RGB32"  :
  \      c.IsRGB24  ? "RGB24"  : "Unknown"
}


Function CSmod_Y8_YV411(clip c) {
  try {
    c.UtoY
    csp = "YV411"
  } catch ( error_msg ) {
    csp = "Y8"
  }
  return csp
}