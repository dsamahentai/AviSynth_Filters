############################################################################
###                                                                      ###
### Use any anti-aliasing filter with motion-compensated post processing ###
###                                                                      ###
###            Modified by 06_taro(astrataro@gmail.com)                  ###
###                                                                      ###
###                     v1.3 - 28 November 2011                          ###
###                                                                      ###
############################################################################
###
### Based on Didée's MC script, Mystery Keeper's SharpAAMC and thetoof's SharpAAMCmod (in his AnimeIVTC)
### (http://forum.doom9.org/showthread.php?t=140031)
###
### +-----------+
### | CHANGELOG |
### +-----------+
###
### v1.3 - 28 November 2011:
###      - Add parameter "predown" and "predownMC" to combat with ugly upconverted videos
###      - Add parameter "aarepair" to choose repair mode
###
### v1.2 - 18 November 2011:
###      - Replace DEdgeMask with mt_edge, and remove MaskTools requirement
###      - Add "shM" to change lsfmod's internal edgemode setting, default is 0
###
### v1.1 - 17 November 2011:
###      - Change default settings of "sharp" from 150 to 80 as the original one is too strong.
###      - Change default settings of "thin" from 10 to 0 as aWarpSharp2 is not needed in most cases with MCAA's default aafilter "taa".
###      - Change "sharptype" meanings to lsfmod's "defaults". Now only use lsfmod, and LimitedSharpenFaster is not needed. If you want the same result and speed as LimitedSharpenFaster, set "sharptype" to "old".
###      - Fix an issue that FrameBased clip being treated as FieldBased after filtered by Sangnom, as well as Sangnom based aafilter like older taa(v1.3 and before), AAA and so on.
###      - Fix fps overflow caused by MVTools
###      - Fix documents: MVTools2 is required, not MVTools
###
### v1.0 - 22 March 2011:
###      - First scipt with "aafilter" and "sharptype" added to sharpaamcmod, and aatype removed.
###      - Use sharptype="lsf" (LimitedSharpenFaster) by default for speed.
###
### +---------+
### |  USAGE  |
### +---------+
###
### Use it in the same way as SharpAAMCmod, except for
### 1. use aafilter="yourAAFilters" instead of aatype
###       aafilter[String, Default="taa(aatype=1, preaa=-1, sharp=0, mtype=0, postaa=false)"]:
### 2. add "sharptype" which allows you to change lsfmod's "defaults" argument
###       sharptype[String: "old"/"fast"/"slow", Default="fast"]
### 3. default value of "thin" is changed to 0, as aWarpSharp2 is usually not needed for pre-processing and skippking it can be faster
### 4. default value of "sharp" is changed to 80, as the original 150 is too strong
### 5. add "shM" to allow changing lsfmod's internal "edgemode" argument, default is changed to 0
### 6. add "predown" to downscale input clip first, in order to combat with ugly upscaled videos, default is false
### 7. add "predownMC" to use with "predown" to prevent downscaled non-aliasing clip overrided by aliasing source when stabilize=true,
###    only affects when stabilize=true, can be used only when predown=true. default is false
### 8. add "aarepair" to choose repair mode to prevent details loss, means the same as "mode" parameter in Repair, off when set to 0
###       aarepair[Int: 0-24, Default=0 (when predownMC=false) / 24 (otherwise)]
###
### MCAA(aafilter="Sangnom().TurnLeft().Sangnom().TurnRight()", sharptype="old", predown=true, predownMC=true, stabilize=true)
### or
### MCAA(aafilter="AAA()", sharptype="slow", shM=1, aarepair=24)
###
### +----------------+
### |  REQUIREMENTS  |
### +----------------+
###
### -> Toon					[for dark>0]
### -> aWarpSharp2	[for thin>0]
### -> MaskTools2
### -> MVTools2
### -> lsfmod
### -> taa					[or any other anti-aliasing filters matching your "aafilter" setting]
###

function MCAA(clip orig, float "dark", int "thin", int "sharp", int "smooth", bool "stabilize", int "tradius", int "aapel", int "aaov", int "aablk", string "aafilter", string "sharptype", int "shM", bool "predown", bool "predownMC", int "aarepair")
{
dark	= default ( dark,     0.2 ) # strokes darkening strength
thin	= default ( thin,       0 ) # Presharpening
sharp	= default ( sharp,     80 ) # Postsharpening
smooth	= default ( smooth,    -1 ) # Postsmoothing
stabilize= default ( stabilize,false ) # Use post stabilization with Motion Compensation
Tradius	= default ( Tradius,    2 ) # 2 = MDegrain2 / 3 = MDegrain3 
aapel	= default ( aapel,      1 ) # accuracy of the motion estimation (Value can only be 1, 2 or 4. 1 means a precision to the pixel. 2 means a precision to half a pixel, 4 means a precision to quarter a pixel, produced by spatial interpolation (better but slower).)
aaov	= default ( aaov,       (orig.width>1100) ? 8 : 4 ) # block overlap value (horizontal). Must be even and less than block size. (Higher = more precise & slower)
aablk	= default ( aablk,      (orig.width>1100) ? 16 : 8 ) # Size of a block (horizontal). It's either 4, 8 or 16 ( default is 8 ). Larger blocks are less sensitive to noise, are faster, but also less accurate.
aafilter	= default ( aafilter, "taa(aatype=1, preaa=-1, sharp=0, mtype=0, postaa=false)" )
sharptype	= default ( sharptype, "fast" ) # Value of "defaults" in lsfmod
shM = default ( shM, 0 ) # lsfmod's internal edge process mode
predown = Default(predown, false)
predownMC = Default(predownMC, false)
aarepair = predownMC ? Default(aarepair, 24) : Default(aarepair, 0)

Assert( (aarepair>=0 && aarepair<=24), """MCAA: "aarepair"(int: 0-24) invalid"""                 )
Assert( (predown || !predownMC),       """MCAA: predownMC can be used only when predown=true!""" )
Assert( isYV12(orig),                  """MCAA: input clip is not an YV12 clip !"""              )
Assert( isFrameBased(orig),            """MCAA: input clip must be Frame Based"""                )

w=width(orig)
h=height(orig)
downw4  = Round(w*0.1875)*4    # m4(w*0.75)
downh4  = Round(h*0.1875)*4    # m4(h*0.75)

pclip = predown ? orig.Spline36Resize(downw4, downh4) : orig

m=mt_logic( pclip.mt_edge("5 10 5 0 0 0 -5 -10 -5 4",0,255,0,255,U=3,V=3)
 \       ,pclip.mt_edge("5 0 -5 10 0 -10 5 0 -5 4",0,255,0,255,U=3,V=3)
 \       ,"max").mt_lut("x 128 / 0.86 ^ 255 *")
preaa=(thin==0 && dark==0) ? pclip :
      \ (thin==0) ? pclip.Toon(dark) :
      \ (dark==0) ? pclip.awarpsharp2(depth=thin) :
      \ pclip.Toon(dark).awarpsharp2(depth=thin)
aa = Eval("preaa."+aafilter)
postsh=(sharp==0 && smooth==0) ? aa : aa.lsfmod(edgemode=shM,strength=sharp,overshoot=1,soft=smooth,defaults=sharptype)
merged=mt_merge(pclip,postsh,m,Y=3,U=3,V=3)

mergeo = predown ? merged.nnedi3_rpow2(rfactor=2, qual=2, cshift="Spline36Resize", fwidth=w, fheight=h) : merged

sD = predownMC ? mt_makediff(pclip,merged) : mt_makediff(orig,mergeo)

origsuper = predownMC ? pclip.MSuper(pel=aapel) : orig.MSuper(pel=aapel)
sDsuper   = sD.  MSuper(pel=aapel, levels=1)


fv3 = tradius==3 ? origsuper.MAnalyse(isb=false,delta=3,overlap=aaov,blksize=aablk) : nop()
fv2 = tradius>=2 ? origsuper.MAnalyse(isb=false,delta=2,overlap=aaov,blksize=aablk) : nop()
fv1 = tradius>=1 ? origsuper.MAnalyse(isb=false,delta=1,overlap=aaov,blksize=aablk) : nop()
bv1 = tradius>=1 ? origsuper.MAnalyse(isb=true, delta=1,overlap=aaov,blksize=aablk) : nop()
bv2 = tradius>=2 ? origsuper.MAnalyse(isb=true, delta=2,overlap=aaov,blksize=aablk) : nop()
bv3 = tradius==3 ? origsuper.MAnalyse(isb=true, delta=3,overlap=aaov,blksize=aablk) : nop()
sDD = tradius==1 ? sD.MDegrain1(sDsuper,bv1,fv1) : tradius==2 ? sD.MDegrain2(sDsuper,bv1,fv1,bv2,fv2) : sD.MDegrain3(sDsuper,bv1,fv1,bv2,fv2,bv3,fv3)

reduc = 0.4
sDD = mt_lutxy(sD,sDD,"x 128 - abs y 128 - abs < x y ?").mergeluma(sDD,1.0-reduc)

result = stabilize ? predownMC ? pclip.mt_makediff(sDD,U=2,V=2).nnedi3_rpow2(rfactor=2, qual=2, cshift="Spline36Resize", fwidth=w, fheight=h)
       \                       : orig.mt_makediff(sDD,U=2,V=2)
       \           : mergeo

return result.AssumeFrameBased().AssumeFPS(orig.frameratenumerator, orig.frameratedenominator)
}
