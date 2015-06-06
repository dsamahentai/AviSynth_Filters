###################################################
###                                             ###
###                   LumaDB                    ###
###                                             ###
###       by 06_taro - astrataro@gmail.com      ###
###                                             ###
###             v0.7 - 06 April 2012            ###
###                                             ###
###################################################
###
### Fast debanding filter with luma-adaptive grain and mask
###
### Used to process on luma only, so named LumaDB
###
### Original used by tp7, scripted by 06_taro
###
###
### +---------+
### |  USAGE  |
### +---------+
###
### LumaDB()
### 
### See below for explanation of parameters
###
### +----------------+
### |  REQUIREMENTS  |
### +----------------+
###
### -> AddGrainC       [v1.6.1]
### -> MaskTools2     [v2.0a48]
### -> dither         [v1.14.1]
### -> RemoveGrain    [v1.0pre]
### -> TEdgeMask         [v0.9]
### -> GrainFactory3mod  [v1.2]
### -> f3kdb           [v1.5.0]
###
### +-----------+
### | CHANGELOG |
### +-----------+
###
### v0.7 - 06 April 2012
###      - Doc: added support for generating f3kdb based grain ( set negative value for g*str to use f3kdb based grain )
###
### v0.6 - 13 March 2012
###      - Add "mclip" to define custom edge mask
###      - Add chroma grain support
###      - Change default "g*const" from true to false
###      - Change "none" to "none" or "nop", the latter is general AviSynth style
###
### v0.5 - 21 Nov 2011
###      - Disable GradFun3's internal mask by default to improve speed, add "gf3mask" to turn it on if needed
###      - Add "mask" to turn LumaDB's edge mask on/off, useful when using LumaDB in other pre-masked scripts like MCTD_PP
###
### v0.4 - 26 Sep 2011
###      - Add "th*" in LumaDB
###
### v0.3 - 28 May 2011
###      - Remove "seed"
###      - Default value of "radius" now varies according to video resolusion
###      - Split "constant" into "g*const"
###
### v0.2 - 27 May 2011
###      - Add some GrainFactory3mod parameters, use float for "g*str" instead of int
###
### v0.1 - 22 May 2011
###      - First release
###

Function LumaDB( clip   input,
               \ float  "thr",     int    "radius",  float  "ampn",
               \ float  "g1str",   float  "g2str",   float  "g3str",
               \ float  "g1cstr",  float  "g2cstr",  float  "g3cstr",
               \ int    "g1shrp",  int    "g2shrp",  int    "g3shrp",
               \ float  "g1size",  float  "g2size",  float  "g3size",
               \ int    "g1tex",   int    "g2tex",   int    "g3tex",
               \ int    "gth1",    int    "gth2",    int    "gth3",    int   "gth4",
               \ bool   "g1const", bool   "g2const", bool   "g3const", int   "temp_avg",
               \ bool   "mask",    int    "gf3mask",
               \ bool   "preblur", bool  "deflate",  bool   "blur",
               \ bool   "chroma",  bool   "mluma",
               \ string "dither",  string "grain",   clip   "mclip"   )
{  
  last     = input
  res      = width * height
  
#############################################################
  
  radius   = ( res <= 589824 ) ? Default( radius, 12 ) :
           \ ( res <= 921600 ) ? Default( radius, 14 ) :
           \                     Default( radius, 16 )  # GradFun3 "radius" parameter
  
  thr      = Default( thr,      0.35 )  # GradFun3 "thr" parameter
  ampn     = Default( ampn,        0 )  # GradFun3 "ampn" parameter
  
  g1str    = Default( g1str,     0.8 )  # [ 0 - ???] strength of luma grain / for dark areas
                                        # positive value for AddGrainC strength, negative value for f3kdb grain strength
  g2str    = Default( g2str,     0.4 )  # [ 0 - ???] strength of luma grain / for midtone areas
                                        # positive value for AddGrainC strength, negative value for f3kdb grain strength
  g3str    = Default( g3str,       0 )  # [ 0 - ???] strength of luma grain / for bright areas
                                        # positive value for AddGrainC strength, negative value for f3kdb grain strength
  
  g1cstr   = Default( g1cstr,      0 )  # [ 0 - ???] strength of chroma grain / for dark areas
                                        # positive value for AddGrainC strength, negative value for f3kdb grain strength
  g2cstr   = Default( g2cstr,      0 )  # [ 0 - ???] strength of chroma grain / for midtone areas
                                        # positive value for AddGrainC strength, negative value for f3kdb grain strength
  g3cstr   = Default( g3cstr,      0 )  # [ 0 - ???] strength of chroma grain / for bright areas
                                        # positive value for AddGrainC strength, negative value for f3kdb grain strength
  
  g1shrp   = Default( g1shrp,     60 )  # [ 0 - 100] sharpness of grain / for dark areas (NO EFFECT when g1size=1.0 !!)
  g2shrp   = Default( g2shrp,     66 )  # [ 0 - 100] sharpness of grain / for midtone areas (NO EFFECT when g2size=1.0 !!)
  g3shrp   = Default( g3shrp,     80 )  # [ 0 - 100] sharpness of grain / for bright areas (NO EFFECT when g3size=1.0 !!)
  
  g1size   = Default( g1size,   0.90 )  # [0.5 - 4.0] size of grain / for dark areas
  g2size   = Default( g2size,   0.70 )  # [0.5 - 4.0] size of grain / for mid-tone areas
  g3size   = Default( g3size,   0.60 )  # [0.5 - 4.0] size of grain / for bright areas
  
  g1tex    = Default( g1tex,       0 )  # [ 0 - 100] strength of "material texture" appearance
  g2tex    = Default( g2tex,       0 )  # [ 0 - 100] (in fact: 'bump' effect)
  g3tex    = Default( g3tex,       0 )  # [ 0 - 100] for dark / midtone / bright grain
  
  gth1     = Default( gth1,       24 )  # start of dark->midtone  mixing zone
  gth2     = Default( gth2,       56 )  # end  of  dark->midtone  mixing zone
  gth3     = Default( gth3,      128 )  # start of midtone->bright  mixing zone
  gth4     = Default( gth4,      160 )  # end  of  midtone->bright  mixing zone

  g1const  = Default( g1const, false )  # AddGrainC "constant" parameter of grain / for dark areas
  g2const  = Default( g2const, false )  # AddGrainC "constant" parameter of grain / for midtone areas
  g3const  = Default( g3const, false )  # AddGrainC "constant" parameter of grain / for bright areas
  
  temp_avg = Default( temp_avg,   50 )  # [ 0 - 100] percentage of noise's temporal averaging (NO EFFECT when g1const=g2const=g3const=true !!)
  
  mask     = Default( mask,     true )  # Indicates whether to use edge mask to protect edges
  gf3mask  = Default( gf3mask,     0 )  # Indicates whether to use GradFun3's internal mask
  
  preblur  = Default( preblur,  true )  # Indicates whether to apply a 3x3 guassian blur to the input image prior to generating the edge map
  deflate  = Default( deflate,  true )  # Indicates whether to apply a deflation to the mask clip
  blur     = Default( blur,     true )  # Indicates whether to apply a blur using RemoveGrain to the mask clip
  
  chroma   = ( g1cstr == 0 ) && ( g2cstr == 0 ) && ( g3cstr == 0 ) ? Default( chroma, false )
  \                                                                : Default( chroma,  true ) # Indicates whether to process chroma or not
  mluma    = Default( mluma,   false )  # Indicate whether to use luma edge mask to process uv plane (read mt_merge's doc of "luma" for more details)
  
  ######  dither: custom gradient smoothing filter  ######
  ######  grain:  custom grain generating filter    ######
  ######  mclip:  custom mask clip                  ######
  
#############################################################
  
  chroma_pre = chroma && !mluma
  
  msk = TEdgeMask( link=2, preblur=preblur, valon=-1, u=chroma_pre?1:0, v=chroma_pre?1:0 ).mt_lut( "x 255 *", u=chroma_pre?3:1, v=chroma_pre?3:1 )
  msk = deflate ? msk.mt_deflate( u=chroma_pre?3:1, v=chroma_pre?3:1 ) : msk
  msk = blur ? msk.RemoveGrain( 20, chroma_pre?20:-1 ) : msk
  
  gf   = !Defined(dither) ? GradFun3( thr=thr, elast=2.5, ampn=ampn, radius=radius, ampo=0.8, dthr=0.011, mask=gf3mask )
  \                       : ( dither=="nop" || dither=="none" || dither=="nop()" || dither=="none()" ) ? last
  \                       : Eval(dither)
  last = gf
  gf   = !Defined(grain)  ? gf.GrainFactory3mod	( g1str=g1str,       g2str=g2str,     g3str=g3str,
  \                                               g1cstr=g1cstr,     g2cstr=g2cstr,   g3cstr=g3cstr,
  \                                               g1shrp=g1shrp,     g2shrp=g2shrp,   g3shrp=g3shrp,
  \                                               g1size=g1size,     g2size=g3size,   g3size=g3size, 
  \                                               g1tex=g1tex,       g2tex=g2tex,     g3tex=g3tex,
  \                                               th1=gth1,          th2=gth3,        th3=gth3,        th4=gth4,
  \                                               g1const=g1const,   g2const=g2const, g3const=g3const,
  \                                               temp_avg=temp_avg, ontop_grain=0,   ontop_cgrain=0 )
  \                        : ( grain=="nop" || grain=="none" || grain=="nop()" || grain=="none()" ) ? last
  \                        : Eval(grain)
  
  return mask ? Defined(mclip) ? mt_merge( gf, input, mclip, luma=mluma, u=chroma?3:4, v=chroma?3:4 )
  \                            : mt_merge( gf, input, msk, luma=mluma, u=chroma?3:4, v=chroma?3:4 )
  \           : gf
}
