###### Contra-Sharpen mod 16 1.3 ###### by mawen1250 ###### 2012.09.21 ###### uMod r1 2015.05.05 ######
###### Requirements: masktools v2.0a48/v2.0b1, mvtools v2.5.11.3/v2.6.0.5, dither v1.26.5  ######
###### RemoveGrain v1.0pre / RgTools v0.92.1, nnedi3 v0.9.4, TEMmod v0.2.0, TCannyMod v0.1.1, MSharpen v1.10/v0.9@tp7 ######

Function CSmod16(clip filtered, clip "source", clip "pclip", bool "lsb_in", bool "lsb", int "dither", bool "chroma",
\ int "edgemode", val "edgemask", float "edgethr", float "tcannysigma", bool "tcannysobel", bool "mergesrc",
\ float "ss_w", float "ss_h", bool "ss_hq", string "ssmethod", string "filter_ss", bool "ssrep", bool "ssout", bool "ssoutc",
\ int "preblur", bool "prec", bool "usepasf",
\ int "Smethod", val "kernel", float "secure", string "filter_nr",
\ val "Smode", float "strength", float "divisor", float "index", float "Szrp", float "Spwr", float "SdmpLo", float "SdmpHi",
\ bool "Slimit", bool "Tlimit", float "Sovershoot", float "Sundershoot", float "Tovershoot", float "Tundershoot",
\ float "Soft",
\ bool "limit", int "Repmode", int "RepmodeU", float "thr", float "thrc",
\ bool "chromamv", int "blksize", int "overlap", int "thSAD", int "thSCD1", int "thSCD2",
\ bool "truemotion", bool "MVglobal", int "pel", int "pelsearch", int "search", int "searchparam", int "MVsharp", int "DCT")
{

lsb_in   = Default(lsb_in,  true   )
lsb      = Default(lsb,     true   )
dither   = Default(dither,  6      )

defsrc   = Defined(source   )
defpclp  = Defined(pclip    )
deffss   = Defined(filter_ss)
deffnr   = Defined(filter_nr)
filtered8=           !lsb_in ? filtered : filtered.DitherPost(mode=dither)
source8  = defsrc  ? !lsb_in ? source   : source  .DitherPost(mode=dither)  : NOP()
pclip8   = defpclp ? !lsb_in ? pclip    : pclip   .DitherPost(mode=dither)  : NOP()
filtered =            lsb_in ? filtered : filtered.Dither_convert_8_to_16()
source   = defsrc  ?  lsb_in ? source   : source  .Dither_convert_8_to_16() : NOP()
pclip    = defpclp ?  lsb_in ? pclip    : pclip   .Dither_convert_8_to_16() : NOP()
sw       = filtered.width()
sh       = filtered.height()/2
HD       = (sw > 1024 || sh > 576) ? true : false

chroma   = Default(chroma,  false  )

edgemode    = Default(edgemode,    0           )
# 0 = Sharpening all, 1 = Sharpening only edge, 2 = Sharpening only non-edge.
# By default, edgemode=2 is tuned for enhancing noise/small detail.
# It will automatically set [edgemask=-2, ss_w=1, ss_h=1, preblur=0, kernel=5, Slimit=false, Tlimit=true(when limit=false)].
edgemask    = Default(edgemask,    edgemode==2?-2:2)
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
ss_hq    = Default(ss_hq,   false  )   #True using nnedi3_rpow2 in super sampling, false using non-ringing Spline64Resize.
ssout    = Default(ssout,   false  )   #Output in super sampling resolution.
ssoutc   = Default(ssoutc,  true   )   #Whether to output correct chroma when (chroma==false && ssout==true).
ssrep    = Default(ssrep,   false  )   #When limiting sharpening to source clip, whether to repair in super sampling resolution.
ssout    = (ss_w > 1.0 || ss_h > 1.0) ? ssout : false
ssrep    = (ss_w > 1.0 || ss_h > 1.0) ? ssrep : false
ssoutc   = (!chroma && ssout) ? ssoutc : false
ssrep    = ssout ? true : ssrep

preblur  = Default(preblur, edgemode>=2?0:ss_w*ss_h>=9?-3:ss_w*ss_h>=4?-2:-1)
# Pre-filtering, 0 = disable, -1 = Gaussian Blur radius=1(RG11), -2 = Gaussian Blur radius=2(RG11+RG20),
# -3 = Gaussian Blur radius=3(RG11+RG20+RG20), -4 = Median Blur radius=1(RG4),
# 1 = MinBlur16(mode=1)(RG11|RG4), 2 = MinBlur16(mode=2)(RG20|RG4), 3 = MinBlur16(mode=3)(SBR|RG4), 
# 4 = MinBlur16(mode=4)(Gaussian|Median radius=2), 5 = MinBlur16(mode=5)(Gaussian|Median radius=3).
# Now Dither_median16 is very slow without optimization, if you want stronger pre-filter you can use other method such as MDegrain.
# "preblur" is ignored when pclip is defined.
prec     = Default(prec,    true   )   #Whether to process chroma plane in preblur.
usepasf  = Default(usepasf, false  )
# Whether to use pre-filtered clip as input(filtered) clip, which will reduce noise/halo/ring from input clip.
usepasf  = (preblur==0 && !defpclp) ? false : usepasf

Smethod  = Default(Smethod, ss_w*ss_h>=4?3:1)   #Sharpen Method - 1: 3x3 kernel, 2: Min/Max, 3: Min/Max + 3x3 kernel.
kernel   = Default(kernel,  edgemode>=2 ? 5 : Smethod>=3 ? ss_w*ss_h>=9?4:ss_w*ss_h>=4?3:ss_w*ss_h>=2.25?2:1
\                                                        : ss_w*ss_h>=4?4:ss_w*ss_h>=2.25?3:ss_w*ss_h> 1?2:1)
# 1: Gaussian Blur radius=1(RG11), 2: Average Blur(RG20), 3: Gaussian Blur radius=2(RG11+RG20), 
# 4: Gaussian Blur radius=3(RG11+RG20+RG20), 5: for noise/detail enhance(RG19+RG4), default for edgemode==2,
# Otherwise define a custom kernel in string such as kernel="Dither_removegrain16(20, 11)".
secure   = Default(secure,  0.50   )
# Threshold(on an 8-bit scale) to avoid banding & oil painting (or face wax) effect of sharpening, set 0 to disable it.(from LSFmod)
Smode    = Default(Smode,   3      )
# Sharpen Mode - 0: None, 1: Linear, 2: Non-linear 1, 3:Non-linear 2(from LSFmod Smode=5), Otherwise define a custom Smode in string.
divisor  = Default(divisor, 1.5    )
index    = Default(index,   0.8    )
#strength = Default(strength,80.0   )
Szrp     = Default(Szrp,    16.0   )
Spwr     = Default(Spwr,    4.0    )
SdmpLo   = Default(SdmpLo,  4.0    )
SdmpHi   = Default(SdmpHi,  48.0   )
miSpwr   = 1.0/Spwr
Szrp16   = Szrp*256
divisor16= divisor*256

limit    = Default(limit,   true   )
# Whether to limit sharpening to source clip, only takes effect when (Defined(source) || Defined(filter_ss) || usepasf) == true.
thr      = Default(thr ,    0      )
thrc     = Default(thrc,    thr    )
# Allow sharpening more than the source pixel in [thr/thrc](luma/chroma)(on an 8-bit scale).
Repmode  = Default(Repmode, 1      )
RepmodeU = Default(RepmodeU,Repmode)
thrc     = chroma ? thrc : 0
limit    = defsrc || deffss || usepasf || deffnr ? limit : false

Slimit      = Default(Slimit,      edgemode>=2?false:!limit)
# Spatial limit with overshoot and undershoot. Disabled when (limit==true && thr==0 && thrc==0).
Tlimit      = Default(Tlimit,      edgemode>=2&&!limit?true:false)
# Use MC Temporal limit at the end of sharpening(only process luma).(from MCTD)
strength    = Default(strength,    Tlimit?120:80)
Sovershoot  = Default(Sovershoot,  strength/120)   #(on an 8-bit scale)
Sundershoot = Default(Sundershoot, Sovershoot  )   #(on an 8-bit scale)
Tovershoot  = Default(Tovershoot,  edgemode>=2?strength/48:strength/24)   #(on an 8-bit scale)
Tundershoot = Default(Tundershoot, Tovershoot  )   #(on an 8-bit scale)
Soft        = Default(Soft,        limit?  0:-2)
# Soft the sharpening effect (-1 = old autocalculate, -2 = new autocalculate, 0 = disable, (0, 100] = enable).
# Disabled when (limit==true && thr==0 && thrc==0).(from LSFmod)
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
ssmethod = Defined(ssmethod) ? ssmethod
\        :             ss_hq ? "nnedi3_rpow2(rfactor=2, qual=2).Dither_convert_8_to_16().CSmod16_nrSpline64Resize16(wss, hss, -0.5, -0.5, chroma=chroma||ssoutc, nr=true, hpgauss=false)"
\        :                     "CSmod16_nrSpline64Resize16(wss, hss, chroma=chroma||ssoutc, nr=true, hpgauss=false)"
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


# super sampling, filtering in ss clip
source      = defsrc ? source  : filtered
source8     = defsrc ? source8 : source.DitherPost(mode=dither)
filtered_os = filtered
filtered_ss = (ss_w > 1.0 || ss_h > 1.0) ? Eval((ss_hq ? "filtered8." : "filtered.")+ssmethod) : filtered
source_ss   = (ss_w > 1.0 || ss_h > 1.0) ? defsrc ? Eval((ss_hq ? "source8." : "source.")+ssmethod) : filtered_ss : source
filtered    = deffss ? Eval("filtered_ss."+filter_ss) : filtered_ss
filtered_ds = (ss_w > 1.0 || ss_h > 1.0) ? deffss ? filtered.CSmod16_nrSpline64Resize16(sw, sh, chroma=chroma, nr=0) : filtered_os : filtered
filtered_ss8= filtered_ss.DitherPost(mode=0)

Assert( (isFrameBased(filtered_os)),                              """CSmod16: input clip "filtered" must be Frame Based!""" )
Assert( (isFrameBased(source)),                                     """CSmod16: input clip "source" must be Frame Based!""" )
Assert( (source.width() == sw && source.height()/2 == sh), """CSmod16: resolution of "filtered" and "source" must match!""" )


# pre-filtering before sharpening
pre         = defpclp     ? pclip
\           : preblur<=-4 ? filtered.Dither_removegrain16(4 , chroma?prec?4 :0:-1)
\           : preblur==-3 ? filtered.Dither_removegrain16(11, chroma?prec?11:0:-1).Dither_removegrain16(20, chroma?prec?20:0:-1)
\                                   .Dither_removegrain16(20, chroma?prec?20:0:-1)
\           : preblur==-2 ? filtered.Dither_removegrain16(11, chroma?prec?11:0:-1).Dither_removegrain16(20, chroma?prec?20:0:-1)
\           : preblur==-1 ? filtered.Dither_removegrain16(11, chroma?prec?11:0:-1)
\           : preblur>= 1 ? filtered.MinBlur16(preblur, chroma ? (prec ? 3 : 2) : 1)
\           :               filtered
# You can define your own pre-filter clip with pclip.
pre_ds      = (pre.width() == sw && pre.height()/2 == sh) ? pre : pre.CSmod16_nrSpline64Resize16(sw, sh, chroma=chroma, nr=0)
pre         = (ss_w > 1.0 || ss_h > 1.0) ? (pre.width() == wss && pre.height()/2 == hss) ? pre : Eval((ss_hq ? "pclip8." : "pclip.")+ssmethod) : pre_ds
pre_ds8     = defpclp ? pclip8 : pre_ds.DitherPost(mode=-1)
pre8        = pre.DitherPost(mode=-1)

# whether to use pre-filtered clip as main clip
filtered    = usepasf ? pre    : filtered
filtered_ds = usepasf ? pre_ds : filtered_ds


# generate edge mask
prefinal  = ssout ? Tlimit&&!chroma&&chromamv ? pre8.MergeChroma(filtered_ss8) : pre8 : Tlimit&&!chroma&&chromamv ? pre_ds8.MergeChroma(filtered8) : pre_ds8
srcfinal  = ssout ? source_ss.DitherPost(mode=dither)                                 : source8
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
\                             .mt_inflate(U=1, V=1).mt_inflate(U=1, V=1).Removegrain(11, -1)
\         : edgemask == 3    ? mt_edge(prefinal, "prewitt", 0, 255, 0, 0, V=1, U=1)
\                             .mt_lut("x 1.8 ^", U=1, V=1).Removegrain(4, -1).mt_inflate(U=1, V=1).Removegrain(20,-1)
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
\         :                    Assert(false, """CSmod16: "edgemask" should be int or clip!""")


# unsharp
dark_limit   = pre.CSmod16_inpand16(U=ch31, V=ch31)
bright_limit = pre.CSmod16_expand16(U=ch31, V=ch31)
minmaxavg    = CSmod16_average16(dark_limit, bright_limit, U=ch31, V=ch31)

method     = Smethod <= 1     ? pre : minmaxavg

method     = Smethod == 2     ? method
\          : IsString(kernel) ? Eval("method."+kernel)
\          : IsInt   (kernel) ?
\            kernel <= 1      ? method.Dither_removegrain16(11, chroma?11:-1)
\          : kernel == 2      ? method.Dither_removegrain16(20, chroma?20:-1)
\          : kernel == 3      ? method.Dither_removegrain16(11, chroma?11:-1).Dither_removegrain16(20, chroma?20:-1)
\          : kernel == 4      ? method.Dither_removegrain16(11, chroma?11:-1).Dither_removegrain16(20, chroma?20:-1)
\                                     .Dither_removegrain16(20, chroma?20:-1)
\          :                    method.Dither_removegrain16(19, chroma?19:-1).Dither_removegrain16(4 , chroma?4 :-1)
\          :                    Assert(false, """CSmod16: "kernel" should be int or string!""")

method     = secure>0         ? pre.Dither_limit_dif16(method, thr=secure, elast=3.0, U=ch31, V=ch31) : method


# making difference clip for sharpening
sharpdiff  = Dither_sub16(pre, method, U=ch31, V=ch31, dif=true)


# filtering in nr clip
filtered   = deffnr ? Eval("method." + filter_nr).Dither_add16(sharpdiff, U=ch31, V=ch31, dif=true) : filtered
filtered_ds= (ss_w > 1.0 || ss_h > 1.0) ? deffnr      ? filtered.CSmod16_nrSpline64Resize16(sw, sh, chroma=chroma, nr=0)
\                                       : filtered_ds : filtered


# sharpening diff generate mode
sharpdiff  = IsString(Smode)  ? sharpdiff.Dither_lut16(Smode, U=ch31, V=ch31)
\          : IsInt   (Smode)  ?
\            Smode <= 0       ? sharpdiff
\          : Smode == 1       ? sharpdiff.Dither_lut16("x 32768 == x x 32768 - "+string(strength/50.0)+" * 32768 + ?", U=ch31, V=ch31)
\          : Smode == 2       ? sharpdiff.Dither_lut16("x 32768 == x x 32768 - "+String(divisor16)+" / Abs "+String(index)+" ^ "+String(strength*12.8)+" * x 32768 > 1 -1 ? * 32768 + ?", U=ch31, V=ch31)
\          :                    sharpdiff.Dither_lut16("x 32768 == x x 32768 - abs "+string(Szrp16)+" / "+string(miSpwr)+" ^ "+string(Szrp)+" * "+string(strength*2.56)+" * x 32768 > 1 -1 ? * x 32768 - 256 / 2 ^ "+string(Szrp)+" 2 ^ "+string(SdmpLo)+" + * x 32768 - 256 / 2 ^ "+string(SdmpLo)+" + "+string(Szrp)+" 2 ^ * / * 1 "+string(SdmpHi)+" 0 == 0 "+string(Szrp)+" "+string(SdmpHi)+" / 4 ^ ? + 1 "+string(SdmpHi)+" 0 == 0 x 32768 - 256 / abs "+string(SdmpHi)+" / 4 ^ ? + / * 32768 + ?", U=ch31, V=ch31)
\          :                    Assert(false,  """CSmod16: "Smode" should be int or string!""")

# x==32768 ? x : (abs(x-32768)/Szrp16)^(miSpwr)*Szrp*(strength*2.56)*(x>32768 ? 1 : -1) * (((x-32768)/256)^2*(Szrp^2+SdmpLo) / (((x-32768)/256)^2+SdmpLo)*Szrp^2) * ((1+ SdmpHi==0 ? 0 : (Szrp/SdmpHi)^4) / (1+ SdmpHi==0 ? 0 : (abs((x-32768)/256)/SdmpHi)^4)) + 32768


# spatial limit
DlimitF    = usepasf || (preblur==0 && !defpclp) ?   dark_limit : filtered.CSmod16_inpand16(U=ch31, V=ch31)
BlimitF    = usepasf || (preblur==0 && !defpclp) ? bright_limit : filtered.CSmod16_expand16(U=ch31, V=ch31)
sclp       = Slimit ? Dither_add16(filtered, sharpdiff, U=ch31, V=ch31, dif=true) : NOP()
sclp       = Slimit ? sclp.CSmod16_clamp16(BlimitF, DlimitF, Sovershoot, Sundershoot, U=ch31, V=ch31) : NOP()


# Soft
sharpdiff  = Slimit ? Dither_sub16(sclp, filtered, U=ch31, V=ch31, dif=true) : sharpdiff
sharpdiffS = sharpdiff.Dither_removegrain16(19, chroma ? 19 : -1)
wmask      = sharpdiff.Dither_lut16(Y=Round(-655.35*Soft), U=chroma?Round(-655.35*Soft):1, V=chroma?Round(-655.35*Soft):1)
sharpdiffW = Soft == 100 ? sharpdiffS : Dither_merge16(sharpdiff, sharpdiffS, wmask, luma=false, U=ch31, V=ch31)
sharpdiff  = Soft ==   0 ? sharpdiff  : CSmod16_limitdiff16(sharpdiff, sharpdiffW, U=ch31, V=ch31)


# the difference achieved by filtering
allD       = limit  ? ssrep && (ss_w > 1.0 || ss_h > 1.0) ? Dither_sub16(source_ss, filtered, U=ch31, V=ch31, dif=true)
\                                                         : Dither_sub16(source, filtered_ds, U=ch31, V=ch31, dif=true) : NOP()

# limiting sharpening to source clip
sharpdiff  = !ssrep && (ss_w > 1.0 || ss_h > 1.0) ? sharpdiff.CSmod16_nrSpline64Resize16(sw, sh, chroma=chroma, nr=0) : sharpdiff
ssDD       = limit ? sharpdiff.Dither_repair16(allD, mode=Repmode, modeU=chroma ? RepmodeU : -1) : sharpdiff
ssDD       = limit ? ssDD.CSmod16_limitdiff16(sharpdiff, U=ch31, V=ch31) : ssDD
ssDDl      = thr  > 0 ? sharpdiff.Dither_limit_dif16(limit ? ssDD : sharpdiff.CSmod16_gen_null_diff(), thr=thr , elast=3.0, Y=3, U=1, V=1) : ssDD
ssDDc      = thrc > 0 ? sharpdiff.Dither_limit_dif16(limit ? ssDD : sharpdiff.CSmod16_gen_null_diff(), thr=thrc, elast=3.0, Y=1, U=3, V=3) : ssDD
ssDD       = thr  > 0 || thrc > 0 ? thr == thrc ?
\                       sharpdiff.Dither_limit_dif16(limit ? ssDD : sharpdiff.CSmod16_gen_null_diff(), thr=thr , elast=3.0, Y=3, U=3, V=3) : ssDDl.MergeChroma(ssDDc) : ssDD
ssDD       = ssrep && (ss_w > 1.0 || ss_h > 1.0) && !ssout ? ssDD.CSmod16_nrSpline64Resize16(sw, sh, chroma=chroma, nr=0) : ssDD

# add difference clip to clip "filtered" of ss/original resolution
sclp       = ssout ? Dither_add16(filtered, ssDD, U=ch31, V=ch31, dif=true) : Dither_add16(filtered_ds, ssDD, U=ch31, V=ch31, dif=true)


# temporal limit
srcfinal16 = ssout ? source_ss : source

sMVS       = prefinal.MSuper(hpad=0, vpad=0, pel=pel, levels=0, sharp=MVsharp, chroma=chromamv)
rMVS       = usepasf || (preblur==0 && !defpclp) ? sMVS
\                                                : srcfinal.MSuper(hpad=0, vpad=0, pel=pel, levels=1, sharp=MVsharp, chroma=chroma)
f1v        = MAnalyse(sMVS, isb=false, delta=1, truemotion=truemotion, blksize=blksize, overlap=overlap, pelsearch=pelsearch, search=search, searchparam=searchparam, DCT=DCT, global=MVglobal, chroma=chromamv)
b1v        = MAnalyse(sMVS, isb=true,  delta=1, truemotion=truemotion, blksize=blksize, overlap=overlap, pelsearch=pelsearch, search=search, searchparam=searchparam, DCT=DCT, global=MVglobal, chroma=chromamv)
f1c        = MCompensate(srcfinal, rMVS, f1v, thSAD=thSAD, thSCD1=thSCD1, thSCD2=thSCD2)
b1c        = MCompensate(srcfinal, rMVS, b1v, thSAD=thSAD, thSCD1=thSCD1, thSCD2=thSCD2)
Tmax       = srcfinal.mt_logic(f1c, "max", U=ch31, V=ch31).mt_logic(b1c, "max", U=ch31, V=ch31).Dither_convert_8_to_16()
Tmin       = srcfinal.mt_logic(f1c, "min", U=ch31, V=ch31).mt_logic(b1c, "min", U=ch31, V=ch31).Dither_convert_8_to_16()
Tmax       = lsb_in ? srcfinal16.Dither_limit_dif16(Tmax, thr=0.50, elast=3.0, U=ch31, V=ch31) : Tmax
Tmin       = lsb_in ? srcfinal16.Dither_limit_dif16(Tmin, thr=0.50, elast=3.0, U=ch31, V=ch31) : Tmin
sclp       = Tlimit ? sclp.CSmod16_clamp16(Tmax, Tmin, Tovershoot, Tundershoot, U=ch32, V=ch32) : sclp


# merge with edge mask and output correct chroma
merged_ss  = mergesrc ? source_ss : filtered_ss
merged_os  = mergesrc ? source    : filtered_os

end        = edgemode <= 0 ? chroma ? sclp
\                                   : ssout ? ssoutc ? sclp.MergeChroma(merged_ss)
\                                                    : sclp
\                                           : sclp.MergeChroma(merged_os)
\          : edgemode == 1 ? ssout ? Dither_merge16_8(merged_ss, sclp, edgemask,
\                                    luma=chroma, Y=3, U=ssoutc?ch32:ch31, V=ssoutc?ch32:ch31)
\                                  : Dither_merge16_8(merged_os, sclp, edgemask,
\                                    luma=chroma, Y=3, U=ch32,             V=ch32            )
\                          : ssout ? Dither_merge16_8(sclp, merged_ss, edgemask,
\                                    luma=chroma, Y=3, U=ssoutc?ch34:ch31, V=ssoutc?ch34:ch31)
\                                  : Dither_merge16_8(sclp, merged_os, edgemask,
\                                    luma=chroma, Y=3, U=ch34,             V=ch34            )

return lsb ? end : end.DitherPost(mode=dither)
}


Function MinBlur16(clip clp, int "mode", int "uv"){

mode  = Default(mode, 1)
uv    = Default(uv,   3)

uv2   = (uv==2) ? 1  : uv
rg4   = (uv==3) ? 4  : -1
rg11  = (uv==3) ? 11 : -1
rg20  = (uv==3) ? 20 : -1

RG11D = (mode<=1) ? Dither_sub16(clp, clp.Dither_removegrain16(11, rg11), U=uv2, V=uv2, dif=true)
\     : (mode==2) ? Dither_sub16(clp, clp.Dither_removegrain16(20, rg20), U=uv2, V=uv2, dif=true)
\     : (mode==3) ? Dither_sub16(clp, clp.sbr16(uv=uv2), U=uv2, V=uv2, dif=true)
\     : (mode==4) ? Dither_sub16(clp, clp.Dither_removegrain16(11, rg11).Dither_removegrain16(20, rg20), U=uv2, V=uv2, dif=true)
\     :             Dither_sub16(clp, clp.Dither_removegrain16(11, rg11).Dither_removegrain16(20, rg20)
\                                        .Dither_removegrain16(20, rg20), U=uv2, V=uv2, dif=true)
RG4D  = (mode<=3) ? Dither_sub16(clp, clp.Dither_removegrain16(4,  rg4 ), U=uv2, V=uv2, dif=true)
\     : (mode==4) ? Dither_sub16(clp, clp.Dither_median16(2, 2, 0, U=uv2, V=uv2), U=uv2, V=uv2, dif=true)
\     :             Dither_sub16(clp, clp.Dither_median16(3, 3, 0, U=uv2, V=uv2), U=uv2, V=uv2, dif=true)

DD    = CSmod16_limitdiff16(RG11D, RG4D, U=uv2, V=uv2)

return clp.Dither_sub16(DD, U=uv, V=uv, dif=true)
}


Function sbr16(clip clp, int "uv") {
uv       = Default(uv, 1)
uv2      = (uv==2) ? 1  : uv
rg11     = (uv==3) ? 11 : -1

rg11D    = Dither_sub16(clp, clp.Dither_removegrain16(11, rg11), U=uv2, V=uv2, dif=true)
rg11Dr   = rg11D.Dither_removegrain16(11, rg11)

abrg11D  = rg11D.Dither_lut16("x 32768 - abs", U=uv2, V=uv2)
Ddiff    = Dither_sub16(rg11D, rg11Dr, U=uv2, V=uv2, dif=true)
abDdiff  = Ddiff.Dither_lut16("x 32768 - abs", U=uv2, V=uv2)
abDDD    = Dither_sub16(abDdiff, abrg11D, U=uv2, V=uv2, dif=true)

Dmask1   = abDDD.Dither_lut16("x 32768 < 65535 0 ?", U=uv2, V=uv2)
Ddiffg   = Ddiff.Dither_lut16("x 32768 == x x 32768 < 0 65535 ? ?", U=uv2, V=uv2).Crop(0, 0, 0, -Ddiff.height()/2)
rg11Dg   = rg11D.Dither_lut16("x 32768 == x x 32768 < 0 65535 ? ?", U=uv2, V=uv2).Crop(0, 0, 0, -rg11D.height()/2)
Dmask2   = mt_lutxy(Ddiffg, rg11Dg, "x 128 - y 128 - * 0 < 0 255 ?", U=uv2, V=uv2)

DD1      = Dither_merge16(rg11D, Ddiff, Dmask1, luma=false, U=uv2, V=uv2)
DD2      = Dither_merge16_8(DD1.CSmod16_gen_null_diff(), DD1, Dmask2, luma=false, U=uv2, V=uv2)

return clp.Dither_sub16(DD2, U=uv, V=uv, dif=true)
}


Function CSmod16_nrSpline64Resize16(clip input, int "target_width", int "target_height", float "src_left", float "src_top", float "src_width", float "src_height", bool "chroma", val "nr", bool "hpgauss") {

  w             = input.width()
  h             = input.height()/2
  
  target_width  = Default(target_width,      w)
  target_height = Default(target_height,     h)
  src_left      = Default(src_left,          0)
  src_top       = Default(src_top,           0)
  src_width     = Default(src_width,         w)
  src_height    = Default(src_height,        h)
  chroma        = Default(chroma,         true)
  nr            = Default(nr,             true)
  hpgauss       = Default(hpgauss,       false)

  nr        = IsInt(nr) ? Float(nr) : nr
  Assert( IsFloat(nr) || IsBool(nr), """CSmod16_nrSpline64Resize16: "nr" should be either bool or float!""" )

  res_mul   = Float( target_width * target_height ) / Float( w * h )
  res_mul   = min( max( res_mul, 1 ), 2.25 )
  nr_weight = IsFloat(nr)       ? nr
  \         : nr /* == True  */ ? Spline( res_mul, 1, 0, 2.25, 1, 3.5, 0, true )
  \         :    /* == False */   0
  nr_weight = min( max( nr_weight, 0 ), 1 )
  wmaskv    = Round(-65535*nr_weight)

    try {
    inputp = chroma ? input
	\               : input.ConvertToY8
	conv   = true
  } catch ( error_msg ) {
    inputp = input
	conv   = false
  }
  
  resize = input.Dither_resize16(target_width, target_height, src_left, src_top, src_width, src_height, kernel="Spline64", Y=3, U=chroma?3:1, V=chroma?3:1)
  nrres  = hpgauss ? input.Dither_resize16(target_width, target_height, src_left, src_top, src_width, src_height, kernel="Gaussian", a1=100, Y=3, U=chroma?3:1, V=chroma?3:1) : inputp.DitherPost(mode=0, Y=3, U=chroma?3:1, V=chroma?3:1).GaussResize(target_width, target_height, src_left, src_top, src_width, src_height, p=100).Dither_convert_8_to_16()
  nrres  = hpgauss||chroma||!conv ? nrres : Eval("nrres.ConvertTo"+input.CSmod16_GetCSP())
  wmask  = resize.Dither_lut16(Y=wmaskv, U=chroma?wmaskv:1, V=chroma?wmaskv:1)

  resize = nr_weight == 0 ? resize
  \      : nr_weight == 1 ? resize.Dither_repair16(nrres, 1, chroma ? 1 : -1)
  \      :                  Dither_merge16(resize, resize.Dither_repair16(nrres, 1, chroma ? 1 : -1), wmask, luma=false, Y=3, U=chroma?3:1, V=chroma?3:1)
  
  return resize
}


Function CSmod16_GetCSP(clip c) {
  return c.IsPlanar ? c.IsYV12 ? "YV12" :
  \                   c.IsYV16 ? "YV16" :
  \                   c.IsYV24 ? "YV24" : c.CSmod16_Y8_YV411 :
  \      c.IsYUY2   ? "YUY2"   :
  \      c.IsRGB32  ? "RGB32"  :
  \      c.IsRGB24  ? "RGB24"  : "Unknown"
}


Function CSmod16_Y8_YV411(clip c) {
  try {
    c.UtoY
    csp = "YV411"
  } catch ( error_msg ) {
    csp = "Y8"
  }
  return csp
}


Function CSmod16_inpand16(clip input, int "Y", int "U", int "V")
{
Y          = Default(Y,        3)
U          = Default(U,        1)
V          = Default(V,        1)

input_msb  = input.Crop(0, 0, 0, -input.height()/2)
inpand_msb = input_msb.mt_inpand(Y=Y, U=U, V=V)
inpand_16  = inpand_msb.Dither_convert_8_to_16()

return inpand_16.Dither_repair16(input, Y==3?1:Y==2?0:-1, U==3?1:U==2?0:-1, V==3?1:V==2?0:-1)
}


Function CSmod16_expand16(clip input, int "Y", int "U", int "V")
{
Y          = Default(Y,        3)
U          = Default(U,        1)
V          = Default(V,        1)

input_msb  = input.Crop(0, 0, 0, -input.height()/2)
expand_msb = input_msb.mt_lut("x 1 +", Y=Y, U=U, V=V).mt_expand(Y=Y, U=U, V=V)
expand_16  = expand_msb.Dither_convert_8_to_16()

return expand_16.Dither_repair16(input, Y==3?1:Y==2?0:-1, U==3?1:U==2?0:-1, V==3?1:V==2?0:-1)
}


Function CSmod16_average16(clip input1, clip input2, int "Y", int "U", int "V")
{
Y          = Default(Y,        3)
U          = Default(U,        3)
V          = Default(V,        3)

hmask = input1.CSmod16_gen_null_diff()

return Dither_merge16(input1, input2, hmask, luma=false, Y=Y, U=U, V=V)
}

Function CSmod16_limitdiff16(clip diff1, clip diff2, int "Y", int "U", int "V")
{
Y          = Default(Y,        3)
U          = Default(U,        3)
V          = Default(V,        3)

abdiff1    = Dither_lut16(diff1, "x 32768 - abs", Y=Y==3?3:1, U=U==3?3:1, V=V==3?3:1)
abdiff2    = Dither_lut16(diff2, "x 32768 - abs", Y=Y==3?3:1, U=U==3?3:1, V=V==3?3:1)
abdiffdiff = Dither_sub16(abdiff1, abdiff2, Y=Y==3?3:1, U=U==3?3:1, V=V==3?3:1, dif=true)
bin        = Dither_lut16(abdiffdiff, "x 32768 <= 0 65535 ?", Y=Y==3?3:1, U=U==3?3:1, V=V==3?3:1)

return Dither_merge16(diff1, diff2, bin, luma=false, Y=Y, U=U, V=V)
}


Function CSmod16_clamp16(clip c, clip bright_limit, clip dark_limit, float "overshoot", float "undershoot", int "Y", int "U", int "V")
{
Y          = Default(Y,          3)
U          = Default(U,          1)
V          = Default(V,          1)
overshoot  = Default(overshoot,  0)
undershoot = Default(undershoot, 0)
os16       = string(overshoot *256)
us16       = string(undershoot*256)

brightdiff = Dither_sub16(c, bright_limit, Y=Y==3?3:1, U=U==3?3:1, V=V==3?3:1, dif=true)
darkdiff   = Dither_sub16(c,   dark_limit, Y=Y==3?3:1, U=U==3?3:1, V=V==3?3:1, dif=true)

brightDdec = brightdiff.Dither_lut16("x " + os16 + " - 32768 > x " + os16 + " - 32768 ?", Y=Y==3?3:1, U=U==3?3:1, V=V==3?3:1)
darkDdec   = darkdiff  .Dither_lut16("x " + us16 + " + 32768 < x " + us16 + " + 32768 ?", Y=Y==3?3:1, U=U==3?3:1, V=V==3?3:1)

return c.Dither_sub16(brightDdec, Y=Y, U=U, V=V, dif=true).Dither_sub16(darkDdec, Y=Y, U=U, V=V, dif=true)
}


Function CSmod16_gen_null_diff(clip input, bool "lsb_in")
{
    lsb_in = Default(lsb_in, true)
	
	vers   = VersionNumber ()
	p_t    = (vers < 2.60) ? "YV12" : Dither_undef ()
	
	input    = lsb_in ? input.Crop(0, 0, 0, -input.height/2) : input
	
	StackVertical(BlankClip(input, pixel_type=p_t, color_yuv=8421504), BlankClip(input, pixel_type=p_t, color_yuv=0))
}