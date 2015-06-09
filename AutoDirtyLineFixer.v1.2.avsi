function AutoDLF(clip video, string alignment, int dirty, int "clean") {
  video

  dirty=dirty+(dirty<0 ? alignment=="v" ? width : height : -1)
  clean=Defined(clean) ? clean+(clean<0 ? alignment=="v" ? width : height : -1)
                     \ : dirty+(dirty<(alignment=="v" ? width : height)/2 ? 1 : -1)
  Assert(alignment=="v" || alignment=="h", """"alignment" value is not correct! Must be "v" or "h"""")
 
  ConvertToRGB()
  clipclean=alignment=="v" ? Crop(clean,0,1,0) : Crop(0,clean,0,1)
  alignment=="v" ? Crop(dirty,0,1,0) : Crop(0,dirty,0,1)
  StackVertical(clipclean)
    
  ScriptClip("
    clipdirty=Crop(0,0,width,height/2)
    clipclean=Crop(0,height/2,width,0)
    BlankClip(clipdirty)
    dr=RGBDifference(ShowRed(clipclean))-RGBDifference(ShowRed(clipdirty))
    dg=RGBDifference(ShowGreen(clipclean))-RGBDifference(ShowGreen(clipdirty))
    db=RGBDifference(ShowBlue(clipclean))-RGBDifference(ShowBlue(clipdirty))
    RGBAdjust(clipdirty,rb=dr,gb=dg,bb=db)
    StackVertical(last)
  ")
  
  Crop(0,0,width,height/2)
  Overlay(video,last,x=alignment=="v" ? dirty : 0,y=alignment=="v" ? 0 : dirty,pc_range=IsRGB(video))
}
