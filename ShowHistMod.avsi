function ShowHistMod(clip clp, int "info") {
   info = Default(info, 1)
   w = clp.width()
   h = clp.Height()
   mtx = (h>=720) ? "PC.709" : "PC.601"
   Assert( info>=0 && info<=3, """ShowHist: "info" must be 0, 1, 2 or 3!""")
   
   hist_v = clp.Histogram("classic").crop(w, 0, 0, 0)
   hist_h = clp.TurnRight().Histogram("classic").crop(h, 0, 0, 0).TurnLeft().AddBorders(0, 0, 4, 0, $CCCCCC)
   hist_yuy2 = clp.ColorYUY2(debug=3)
   hist_g = hist_yuy2.crop(w, 0, 0, 182).AddBorders(0, 0, 0, 74)
   hist_c = hist_yuy2.crop(0, 0, w, 0)
   debug_diff = mt_makediff(hist_c, clp)
   
   hist_top = StackHorizontal(hist_h, hist_g).AddBorders(0, 0, 0, 4, $CCCCCC)
   
   hist_bottom = 
   \ (info == 0) ? 
   \ StackHorizontal(clp.AddBorders(0, 0, 4, 0, $CCCCCC), hist_v) : 
   \ (info == 1) ? 
   \ StackHorizontal(hist_c.AddBorders(0, 0, 4, 0, $CCCCCC), hist_v) : 
   \ (info == 2) ? 
   \ StackHorizontal(clp.ShowOverRange.AddBorders(0, 0, 4, 0, $CCCCCC), hist_v) :
   \ (info == 3) ?
   \ StackHorizontal(clp.ShowOverRange.mt_adddiff(debug_diff).AddBorders(0, 0, 4, 0, $CCCCCC), hist_v) :
   \ nop()
   
   out = StackVertical(hist_top, hist_bottom)

   return out
}