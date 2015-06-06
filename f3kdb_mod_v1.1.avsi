# flash3kyuv_deband_mod 1.1
# Original Author(ver 1.0): eric888a
# modified by(ver 1.1): LittlePox

Function f3KDB_MOD(clip   input,int  "luma1",int  "luma2",int  "luma3",
\int  "chroma1",int  "chroma2",int  "chroma3",bool   "lsb",bool  "lsb_in",int  "range",int  "Y",int  "Cb",int  "Cr",int  "dither_algo",bool  "dynamic_grain")
{  
  #-----------------------------------------------------------------------------------
  
  lsb_in   = Default( lsb_in,   false ) 
  lsb      = Default( lsb,      false )  
  luma1    = Default( luma1,       48 )  
  luma2    = Default( luma2,       24 ) 
  luma3    = Default( luma3,       12 )  
  chroma1  = Default( chroma1,     48 )  
  chroma2  = Default( chroma2,     24 )  
  chroma3  = Default( chroma3,     12 )
  _range   = Default( range,       15 )
  _Y       = Default( Y,           64 )
  _Cb      = Default( Cb,          64 )
  _Cr      = Default( Cr,          64 )
  da       = Default( dither_algo,  3 )
  dr   = Default( dynamic_grain , true)
#-----------------------------------------------------------------------------------
  
  src16    = lsb_in  ? input : input.Dither_convert_8_to_16()
  src8     = !lsb_in ? input : input.f3kdb_dither()
  last      =src8
#-----------------------------------------------------------------------------------
 chroma  = ( chroma1 == 0 ) && ( chroma2 == 0 ) && ( chroma3 == 0 ) ? false : true
  
  msk  = TEdgeMask( link=2, preblur=true, valon=-1, u=chroma?1:0, v=chroma?1:0 ).mt_lut( "x 255 *", u=chroma?3:1,v=chroma?3:1 )
  msk  = msk.mt_deflate(u=chroma?3:1, v=chroma?3:1)
  msk  = msk.RemoveGrain(20, chroma?20:-1)
#-----------------------------------------------------------------------------------
gf   = src16.f3kdb(range=_range,Y=_Y,Cb=_Cb,Cr=_Cr,output_mode=1,input_mode=1,input_depth=16,output_depth = 16,dither_algo=da,dynamic_grain=dr)
#-----------------------------------------------------------------------------------
o    = gf
o8   = gf.f3kdb_dither()
oblr = o8.RemoveGrain(19, -1)
ox   = o8.width
oy   = o8.height
sx1  = m4(ox/float(0.90))
sy1  = m4(oy/float(0.90))
sx1a = m4((ox+sx1)/2.0)
sy1a = m4((oy+sy1)/2.0)
sx2  = m4(ox/float(0.70))
sy2  = m4(oy/float(0.70))
sx2a = m4((ox+sx2)/2.0)
sy2a = m4((oy+sy2)/2.0)
sx3  = m4(ox/float(0.60))
sy3  = m4(oy/float(0.60))
sx3a = m4((ox+sx3)/2.0)
sy3a = m4((oy+sy3)/2.0)
#-----------------------------------------------------------------------------------
gL1 = BlankClip(o,width=sx1, height=sy1, color_yuv=$808080)
gL1 = gL1.f3kdb(range=_range,Y=_Y,Cb=_Cb,Cr=_Cr,grainY=luma1,grainC=chroma1,output_mode=1,input_mode=1,input_depth=16,output_depth = 16,dither_algo=da,dynamic_grain=dr)
gL1 = (sx1==ox && sy1==oy) ? gL1: gL1.Dither_resize16(ox,oy,a1=-0.2,a2=0.6,kernel="bicubic")
#-----------------------------------------------------------------------------------
gL2 = BlankClip(o,width=sx2, height=sy2, color_yuv=$808080)
gL2 = gL2.f3kdb(range=_range,Y=_Y,Cb=_Cb,Cr=_Cr,grainY=luma2,grainC=chroma2,output_mode=1,input_mode=1,input_depth=16,output_depth = 16,dither_algo=da,dynamic_grain=dr)
gL2 = (sx2==ox && sy2==oy) ? gL2: gL2.Dither_resize16(ox,oy,a1=-0.32,a2=0.66,kernel="bicubic")
#-----------------------------------------------------------------------------------
gL3 = BlankClip(o, width=sx3, height=sy3, color_yuv=$808080)
gL3 = gL3.f3kdb(range=_range,Y=_Y,Cb=_Cb,Cr=_Cr,grainY=luma3,grainC=chroma3,output_mode=1,input_mode=1,input_depth=16,output_depth = 16,dither_algo=da,dynamic_grain=dr)
gL3 = (sx3==ox && sy3==oy) ? gL3: gL3.Dither_resize16(ox,oy,a1=-0.6,a2=0.8,kernel="bicubic")
#-----------------------------------------------------------------------------------
grainLayer = gL1
          \ .GrainFL_merge16_8(gL2,
          \ oblr.mt_lut("x "+string(24)+" < 0 x "+string(56)+" > 255 255 "+string(56)+" "+string(24)+" - / x "+string(24)+" - * ? ?", U=1, 
          \ V=1),luma=chroma,U=chroma?3:1, V=chroma?3:1)
          \ .GrainFL_merge16_8(gL3,
          \ oblr.mt_lut("x "+string(128)+" < 0 x "+string(160)+" > 255 255 "+string(160)+" "+string(128)+" - / x "+string(128)+" - * ? ?", 
          \ U= 1,V=1),luma=chroma, U=chroma?3:1, V=chroma?3:1)

#-----------------------------------------------------------------------------------
  gf= o.Dither_add16(grainLayer, dif=true, U=chroma?3:2, V=chroma?3:2)
  result16 =GrainFL_merge16_8( gf, src16, msk, luma=false, u=chroma?3:4, v=chroma?3:4 ) 
  result   = lsb ? result16:result16.f3kdb_dither()

  return result
}
# ==============================================
function m4(float x) {return( x<16?16:int(round(x/4.0)*4)) }


Function GrainFL_merge16_8(clip src1, clip src2, clip mask, bool "luma", int "y", int "u", int "v"){
   luma = Default(luma, false)

   y = Default(y, 3)
   u = Default(u, 2)
   v = Default(v, 2)

   mask16 = StackVertical(mask, mask)
   Dither_merge16(src1, src2, mask16, luma=luma, y=y, u=u, v=v)
}