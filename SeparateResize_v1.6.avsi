###################################################
###                                             ###
###            SeparateResize.avsi              ###
###                                             ###
###     By 06_taro ( astrataro@gmail.com )      ###
###                                             ###
###            v1.6 - 31 Jul 2012               ###
###                                             ###
###################################################
###
### Resize Luma and Chroma separately
### YUV input only, RGB will be converted to YV24(AviSynth 2.6+) / YV12(AviSynth 2.5) automatically
###
### Many thanks to madshi, Didée & cretindesalpes...
###
### Requires Repair if nr=true:
###     http://home.arcor.de/kassandro/prerelease/RemoveGrain-1.0.rar
### Requires SplineResize(dll ver) for SeparateResize if using SplineResize/Spline100Resize/Spline144Resize:
###     http://forum.doom9.org/showthread.php?t=147117
###
### Requires Dither package for SeparateResize16:
###     http://forum.doom9.org/showthread.php?p=1386559#post1386559
### Requires planar colorspace(YV12, YV16, YV24, YV411, Y8) for SeparateResize16
###
### +-------------+
### |  CHANGELOG  |
### +-------------+
###
### v1.6 - 31 Jul 2012:
###      - Use val instead of bool for "nr", now accepts both bool and float
###        The *NEW* nr=true is an adaptive weight method for ringing-reduction algorithm,
###        in which the weight of non-ringing clip is based on resolution multiple factor
###        When "nr" is float, it indicates the weight of non-ringing clip, i.e., nr=1 equals to *OLD* nr=true, nr=0 equals to nr=false
###      - Faster ringing-reduction process
###      - Add SeparateResize16 for 16-bit resize, only accepts planar color space
###        I'm too lazy to implement parameter parser, so you need to map parameters for some kernels by yourself
###        For example, use ChromaR="Bicubic", ChromaParam="a1=0.75, a2=0.25" if you prefer SoftCubic75 as chroma resizer
###      - SeparateResize now accepts kernel names without "Resize", e.g., LumaR="Spline36" equals to LumaR="Spline36Resize",
###        so you can use same kernel names in SeparateResize and SeparateResize16 ( if exists in Dither_resize16 )
###      - Deprecate madResize and nrLSResize
###        They are still working as before, but won't be updated any more
###
### v1.5 - 27 Jun 2012:
###      - Now supports YUV formats other than YV12 without converting them to YV12
###      - Add four supporting functions: GetCSP, IsY8, IsY411, Separate_Y8_YV411
###        I made them because now SeparateResize needs to know what colorspace is input clip,
###        but Dither_IsY8 could not separate Y8 and YV411 until v1.19.0, i.e., old ConvertToYV411.Dither_IsY8 returns true
###        - GetCSP(clip c): returns a string of colorspace of clip c
###                          e.g., GetCSP(last.ConvertToYV411) returns "YV411", GetCSP(last.ConvertToRGB32) returns "RGB32"
###                          supports YV12, YV16, YV24, Y8, YV411, YUY2, RGB24, RGB32
###                          returns "Unknown" if clip is other colorspace ( if exists )
###        - IsY8(clip c): returns if c is Y8 or not
###        - IsYV411(clip c): returns if c is YV411 or not
###        - Separate_Y8_YV411(clip c): returns "Y8" if c is Y8, otherwise "YV411"
###                                     only used for separate Y8 and YV411, so the input clip c must be either Y8 or YV411
###
### v1.4 - 11 Nov 2011:
###      - Add "nr" to remove ringing artifacts, tweak default Resizer for both Luma and Chroma
###
### v1.3 - 11 Aug 2011:
###      - Remove useless processing to increase speed
###
### v1.2 - 28 May 2011:
###      - Fix: "matrix" is ignored and always use default setting
###
### v1.1 - 08 March 2011:
###      - Add "info" parameter
###
### v1.0 - 07 March 2011:
###      - First script
###
### +-------+
### | USAGE |
### +-------+
###
### SeparateResize(int target_width, int target_height,
###                float src_left, float src_top, float src_width, float src_height,
###                string LumaR, string ChromaR,
###                string LumaPara, string ChromaPara,
###                val nr, string matrix, bool info)
###
### SeparateResize16(int target_width, int target_height,
###                  float src_left, float src_top, float src_width, float src_height,
###                  string LumaR, string ChromaR,
###                  string LumaPara, string ChromaPara,
###                  val nr, bool info)
###
### +-----------+
### |  GENERAL  |
### +-----------+
###
### target_width, target_height [int, default = the resolution of input clip]
### ----------------------
### Same as avisynth internal resize filters
###
### src_left, src_top, src_width, src_height [float, default = 0]
### ----------------------
### Same as avisynth internal resize filters
###
### LumaR [string, default = "Spline64Resize"]
### ----------------------
### Resizer for Luma
###
### ChromaR [string, default = "SoftCubicResize" ("Bicubic" in SeparateResize16)]
### ----------------------
### Resizer for Chroma
###
### LumaPara, ChromaPara [string, default = "" (ChromaParam="a1=1, a2=0", aka SoftCubic100 in SeparateResize16)]
### ----------------------
### Additional parameters for each resizer
###
### nr [bool or float, default = true]
### ----------------------
### Use repair to remove ringing introduced from Luma Resizer
### if nr >= 1          : completely use non-ringing repaired clip
###    0 < nr < 1       : nr is the weight of non-ringing repaired clip for merging with normally upscaled clip
###    nr <= 0 or false : do not use non-ringing repair
###    nr == true       : adapt the weight of non-ringing repaired clip according to input and output resolution
###
### matrix [string, default = "Rec601" for SD resolution input / "Rec709" for HD resolution input]
### ----------------------
### Same as "matrix" of avisynth internal ConvertToYV12 filter, affects only RGB input clip
###
### info [bool, default = false]
### ----------------------
### If set to true, clip properties and resize settings will be drawn on the video frames.
###
### +---------+
### | EXAMPLE |
### +---------+
###
### Apply Crop(8, 0, -8, 0) with resizer's internal crop function,
### and then use GaussResize(p=40) for Luma and BicubicResize(b=0.2, c=0.4) for Chroma to final resolution 704x480,
### use adaptive non-ringing algorithm,
### with clip properties and resize settings drawn on the video frames:
###
### SeparateResize(704, 480, 8, 0, -8, 0, LumaR="GaussResize", ChromaR="BicubicResize", LumaPara="p=40", ChromaPara="b=0.2, c=0.4", nr=true, matrix="Rec601", info=true)
###

# ============ SeparateResize ============

FUNCTION SeparateResize(clip   input,      int    "target_width", int   "target_height",
\                       float  "src_left", float  "src_top",      float "src_width",     float "src_height",
\                       string "LumaR",    string "ChromaR",
\                       string "LumaPara", string "ChromaPara",
\                       val    "nr",       string "matrix",       bool "info") {

  w             = input.Width
  h             = input.Height
  csp_in        = input.GetCSP
  csp_in_rgb    = LeftStr(csp_in, 3) == "RGB"
  csp_out       = csp_in_rgb ? Int(VersionNumber*10) == 26 ? "YV24"
  \                                                        : "YV12"
  \                          : csp_in

  target_width  = Default(target_width,      w)
  target_height = Default(target_height,     h)
  src_left      = Default(src_left,          0)
  src_top       = Default(src_top,           0)
  src_width     = Default(src_width,         0)
  src_height    = Default(src_height,        0)
  LumaR         = Default(LumaR,    "Spline64")
  ChromaR       = Default(ChromaR, "SoftCubic")
  LumaPara      = Default(LumaPara,         "")
  ChromaPara    = Default(ChromaPara,       "")
  nr            = Default(nr,             true)
  info          = Default(info,          false)
  matrix        = ( w > 1024 ) || ( h > 576 ) ? Default( matrix, "Rec709" ) : Default( matrix, "Rec601" )

  LumaR         = RightStr(LumaR,   6) == "Resize" ? LumaR   : LumaR   + "Resize"
  ChromaR       = RightStr(ChromaR, 6) == "Resize" ? ChromaR : ChromaR + "Resize"
  # SplineResize(dll ver) cannot handle chroma correctly except for YV12 and YUY2
  Assert( csp_out == "YV12" || csp_out == "YUY2" || csp_out == "Y8" ||
  \       ChromaR != "SplineResize" && ChromaR != "Spline100Resize" && ChromaR != "Spline144Resize",
  \       "SeparateResize: " + ChromaR + " does not support " + csp_out + "!" )
  Assert( IsFloat(nr) || IsBool(nr), """SeparateResize: "nr" should be either bool or float!""" )

  res_mul   = Float( target_width * target_height ) / Float( w * h )
  res_mul   = min( max( res_mul, 1 ), 2.25 )
  nr_weight = IsFloat(nr)       ? nr
  \         : nr /* == True  */ ? Spline( res_mul, 1, 0, 2.25, 1, 3.5, 0, true )
  \         :    /* == False */   0
  nr_weight = min( max( nr_weight, 0 ), 1 )

  # Convert RGB input to YUV
  try {
    # Try Dither_Convert_RGB_TO_YUV first
    input = csp_in_rgb ? Dither_Convert_RGB_TO_YUV( matrix=RightStr(matrix, 3),
    \                                                     tv_range=LeftStr(matrix, 3)=="Rec" )
    \                        : input
  } catch ( error_msg ) {
    # If failed, fall back to ConvertToYV24/YV12
    input = csp_in_rgb ? Eval("input.ConvertTo" + csp_out + "(matrix=matrix)")
    \                  : input
  }

  # Repair and SplineResize(dll ver) can only handle YV12 directly with correct output
  # They can handle some other formats like YV16/YV24, but chroma is not correct
  # Although chroma does not come from this luma clip, I still don't want to take the risk if luma is not processed correctly
  # Use chromaresample="point" for chroma if possible, as it is fast and chroma is not taken from this clip
  try {
    input_luma = input.IsYV12 ? input
    \                         : input.ConvertToYV12(chromaresample="point")
  } catch ( error_msg ) {
    input_luma = input.IsYV12 ? input
    \                         : input.ConvertToYV12
  }

  # Typos for additional parameters
  LumaPara   = LumaPara   == "" ? ")" : ( ", " + LumaPara   + ")" )
  ChromaPara = ChromaPara == "" ? ")" : ( ", " + ChromaPara + ")" )

  # Generate subtitles for info=true
  InfoSub = csp_in_rgb ? "Input colorspace is " + csp_in +
  \                      ",\n colorspace has been converted to " + csp_out + """ ( Matrix = """" + matrix + """" )"""
  \                    : "Input colorSpace is " + csp_in + ", keep original colorspace"
  InfoSub = InfoSub
  \         + "\n\nSource Resolution:\n" + String(w) + "x" + String(h)
  \         + "\n\nResizer's Internal Crop Setting:\nCrop(" + String(src_left) + ", " + String(src_top) + ", "
  \                                                         + String(src_width) + ", " + String(src_height) + ")"
  \         + "\n\nTarget Resolution:\n" + String(target_width) + "x" + String(target_height)
  \         + "\n\nLumaResizer:\n" + LumaR + "(" + String(target_width) + ", " + String(target_height)
  \         + ", " + String(src_left) + ", " + String(src_top) + ", " + String(src_width) + ", " + String(src_height) + LumaPara
  InfoSub = csp_out == "Y8" ? InfoSub
  \       : InfoSub
  \         + "\n\nChromaResizer:\n" + ChromaR + "(" + String(target_width) + ", " + String(target_height)
  \         + ", " + String(src_left) + ", " + String(src_top) + ", " + String(src_width) + ", " + String(src_height) + ChromaPara
  InfoSub = InfoSub + "\n\nNon-ringing repair: " + ( nr_weight==1 ? "On" : nr_weight == 0 ? "Off" : "On (weight=" + String(nr_weight) + ")" )

  # Generate full parameters for resizer
  LumaPara = LumaR + "(" + String(target_width) + ", " + String(target_height)
  \            + ", src_left=" + String(src_left) + ", src_top=" + String(src_top)
  \            + ", src_width=" + String(src_width) + ", src_height=" + String(src_height)
  \            + LumaPara

  ChromaPara = ChromaR + "(" + String(target_width) + ", " + String(target_height)
  \               + ", src_left=" + String(src_left) + ", src_top=" + String(src_top)
  \               + ", src_width=" + String(src_width) + ", src_height=" + String(src_height)
  \               + ChromaPara

  # Process luma
  Luma = Eval( "input_luma." + LumaPara )
  # Non-ringing algorithm
  Luma = nr_weight == 0 ? Luma
  \    : nr_weight == 1 ? Luma.Repair(input_luma.GaussResize(target_width, target_height, src_left, src_top, src_width, src_height, p=100), 1, -1)
  \    : MergeLuma(Luma, Luma.Repair(input_luma.GaussResize(target_width, target_height, src_left, src_top, src_width, src_height, p=100), 1, -1), nr_weight)
  # Convert luma to output colorspace
  # Use chromaresample="point" for chroma if possible, as it is fast and chroma is not taken from this clip
  try {
    Luma = csp_out == "YV12" ? Luma : Eval( "Luma.ConvertTo" + csp_out + """(chromaresample="point")""" )
  } catch ( error_msg ) {
    Luma = csp_out == "YV12" ? Luma : Eval( "Luma.ConvertTo" + csp_out )
  }

  # Process chroma
  Chroma = Eval( "input." + ChromaPara )

  result = csp_out == "Y8" ? Luma : MergeChroma(Luma, Chroma)

  return info ? result.Subtitle(InfoSub, font="Comic Sans MS",
  \                               x=target_width/64, y=target_height/48,
  \                               size=min(target_width/32, target_height/20), lsp=1)
  \            : result
}



# ============ SeparateResize16 ============

FUNCTION SeparateResize16(clip   input,      int    "target_width", int   "target_height",
\                         float  "src_left", float  "src_top",      float "src_width",     float "src_height",
\                         string "LumaR",    string "ChromaR",
\                         string "LumaPara", string "ChromaPara",
\                         val    "nr",       bool   "info") {

  w             = input.Width
  h             = input.Height / 2
  csp           = input.GetCSP

  target_width  = Default(target_width,          w)
  target_height = Default(target_height,         h)
  src_left      = Default(src_left,              0)
  src_top       = Default(src_top,               0)
  src_width     = Default(src_width,             0)
  src_height    = Default(src_height,            0)
  LumaR         = Default(LumaR,        "Spline64")
  ChromaR       = Default(ChromaR,       "Bicubic")
  LumaPara      = Default(LumaPara,             "")
  ChromaPara    = Default(ChromaPara, "a1=1, a2=0")
  nr            = Default(nr,                 true)
  info          = Default(info,              false)

  # Only supports planar format
  Assert( IsPlanar(input), "SeparateResize16: only supports planar colorspace!" )
  Assert( IsFloat(nr) || IsBool(nr), """SeparateResize16: "nr" should be either bool or float!""" )

  res_mul   = Float( target_width * target_height ) / Float( w * h )
  res_mul   = min( max( res_mul, 1 ), 2.25 )
  nr_weight = IsFloat(nr)       ? nr
  \         : nr /* == True  */ ? Spline( res_mul, 1, 0, 2.25, 1, 3.5, 0, true )
  \         :    /* == False */   0
  nr_weight = min( max( nr_weight, 0 ), 1 )

  # Repair can only handle YV12 directly with correct output
  # They can handle some other formats like YV16/YV24, but chroma is not correct
  # Although chroma does not come from this luma clip, I still don't want to take the risk if luma is not processed correctly
  # Use chromaresample="point" for chroma if possible, as it is fast and chroma is not taken from this clip
  try {
    input_luma = input.IsYV12 ? input
    \                         : input.ConvertToYV12(chromaresample="point")
  } catch ( error_msg ) {
    input_luma = input.IsYV12 ? input
    \                         : input.ConvertToYV12
  }

  # Typos for additional parameters
  LumaPara   = LumaPara   == "" ? ")" : ( ", " + LumaPara   + ")" )
  ChromaPara = ChromaPara == "" ? ")" : ( ", " + ChromaPara + ")" )

  # Generate subtitles for info=true
  InfoSub = "Input colorspace is " + csp
  InfoSub = InfoSub
  \         + "\n\nSource Resolution:\n" + String(w) + "x" + String(h)
  \         + "\n\nResizer's Internal Crop Setting:\nCrop(" + String(src_left) + ", " + String(src_top) + ", "
  \                                                         + String(src_width) + ", " + String(src_height) + ")"
  \         + "\n\nTarget Resolution:\n" + String(target_width) + "x" + String(target_height)
  \         + "\n\nLumaResizer:\nDither_resize16(" + String(target_width) + ", " + String(target_height)
  \         + ", " + String(src_left) + ", " + String(src_top) + ", " + String(src_width) + ", " + String(src_height)
  \         + """, kernel="""" + LumaR + """""""
  \         + LumaPara
  InfoSub = csp == "Y8" ? InfoSub
  \       : InfoSub
  \         + "\n\nChromaResizer:\nDither_resize16(" + String(target_width) + ", " + String(target_height)
  \         + ", " + String(src_left) + ", " + String(src_top) + ", " + String(src_width) + ", " + String(src_height)
  \         + """, kernel="""" + ChromaR + """""""
  \         + ChromaPara
  InfoSub = InfoSub + "\n\nNon-ringing repair: " + ( nr_weight==1 ? "On" : nr_weight == 0 ? "Off" : "On (weight=" + String(nr_weight) + ")" )

  # Generate full parameters for resizer
  LumaPara = "Dither_resize16(" + String(target_width) + ", " + String(target_height)
  \                             + ", src_left=" + String(src_left) + ", src_top=" + String(src_top)
  \                             + ", src_width=" + String(src_width) + ", src_height=" + String(src_height)
  \                             + """, kernel="""" + LumaR + """", Y=3, U=1, V=1"""
  \                             + LumaPara

  ChromaPara = "Dither_resize16(" + String(target_width) + ", " + String(target_height)
  \                               + ", src_left=" + String(src_left) + ", src_top=" + String(src_top)
  \                               + ", src_width=" + String(src_width) + ", src_height=" + String(src_height)
  \                               + """, kernel="""" + ChromaR + """", Y=1, U=3, V=3"""
  \                               + ChromaPara

  # Process luma
  Luma   = Eval( "input_luma." + LumaPara )
  # Non-ringing algorithm
  nrLuma = input_luma.Dither_resize16(target_width, target_height, src_left, src_top, src_width, src_height, kernel="Gaussian", a1=100, Y=3, U=1, V=1)
  mainL8 = Luma.DitherPost(mode=-1, Y=3, U=1, V=1)
  nrL8   = nrLuma.DitherPost(mode=-1, Y=3, U=1, V=1)
  fixL8  = mainL8.Repair(nrL8, 1, -1)
  difML8 = mt_lutxy(mainL8, fixL8, "x y != " + String(255*nr_weight) + " 0 ?", Y=3, U=1, V=1)
  fixL16 = fixL8.Dither_convert_8_to_16
  fixL16 = nrLuma.Dither_limit_dif16(fixL16, thr=0.5, Y=3, U=1, V=1)
  Luma   = nr_weight == 0 ? Luma
  \                       : Dither_merge16_8(Luma, fixL16, difML8, Y=3, U=1, V=1)
  # Convert luma to output colorspace
  # Use chromaresample="point" for chroma if possible, as it is fast and chroma is not taken from this clip
  try {
    Luma = csp == "YV12" ? Luma : Eval( "Luma.ConvertTo" + csp + """(chromaresample="point")""" )
  } catch ( error_msg ) {
    Luma = csp == "YV12" ? Luma : Eval( "Luma.ConvertTo" + csp )
  }

  # Process chroma
  Chroma = Eval( "input." + ChromaPara )

  result = csp == "Y8" ? Luma : MergeChroma(Luma, Chroma)

  return info ? result.Subtitle(InfoSub, font="Comic Sans MS",
  \                               x=target_width/64, y=target_height/48,
  \                               size=min(target_width/32, target_height/20), lsp=1)
  \            : result
}



# ============ Supporting functions ============

FUNCTION GetCSP(clip c) {
  return c.IsPlanar ? c.IsYV12 ? "YV12" :
  \                   c.IsYV16 ? "YV16" :
  \                   c.IsYV24 ? "YV24" : c.Separate_Y8_YV411 :
  \      c.IsYUY2   ? "YUY2"   :
  \      c.IsRGB32  ? "RGB32"  :
  \      c.IsRGB24  ? "RGB24"  : "Unknown"
}

FUNCTION IsYV411(clip c) {
  return c.GetCSP == "YV411"
}

FUNCTION IsY8(clip c) {
  return c.GetCSP == "Y8"
}

FUNCTION Separate_Y8_YV411(clip c) {
  try {
    c.UtoY
    csp = "YV411"
  } catch ( error_msg ) {
    csp = "Y8"
  }
  return csp
}
