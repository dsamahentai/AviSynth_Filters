function showHist(clip clp, bool "info") {
   info = Default(info, true)
   w = clp.width()
   h = clp.Height()
   mtx = (h>=720) ? "PC.709" : "PC.601"
   
   hist_v = clp.Histogram("classic").crop(w, 0, 0, 0)
   hist_h = clp.TurnRight().Histogram("classic").crop(h, 0, 0, 0).TurnLeft().AddBorders(0, 0, 4, 0, $CCCCCC)
   hist_yuy2 = clp.ColorYUY2(debug=3)
   hist_g = hist_yuy2.crop(w, 0, 0, 182).AddBorders(0, 0, 0, 74)
   hist_c = hist_yuy2.crop(0, 0, w, 0)
   
   hist_top = StackHorizontal(hist_h, hist_g).AddBorders(0, 0, 0, 4, $CCCCCC)
   hist_bottom = 
   \ (info == true) ? 
   \ StackHorizontal(hist_c.AddBorders(0, 0, 4, 0, $CCCCCC), hist_v) : 
   \ StackHorizontal(clp.ShowOverRange.AddBorders(0, 0, 4, 0, $CCCCCC), hist_v)
   out = StackVertical(hist_top, hist_bottom)

   return out
}