function nnedi3x(clip a, int "field", bool "dh", bool "Y", bool "U", bool "V", int "nsize", int "nns", int "qual", int "etype", int "pscrn", int "threads", int "opt", int "fapprox", int "dw")
{
	a.IsYUY2() ? a.ConvertToYV16() : a.IsRGB24() ? YToUV(a.ShowBlue("Y8"), a.ShowRed("Y8"), a.ShowGreen("Y8")) : a
	nnedi3ocl(dh=dh, field=field, dw=dw, nsize=nsize, nns=nns, qual=qual, etype=etype, Y=Y, U=U, V=V)
	return a.IsYUY2() ? ConvertToYUY2() : a.IsRGB24() ? MergeRGB(VToY8(), last, UToY8(), "RGB24") : last
}

function nnedi3x_resize_helper(clip a, int w, int h, float dx, float dy, string cshift, "ep0", "ep1")
{
	return cshift == "BicubicResize" ? BicubicResize(a, w, h, ep0, ep1, dx, dy) :\
		cshift == "GaussResize" || cshift == "BlackmanResize" || cshift == "LanczosResize" || cshift == "SincResize" ? Apply(cshift, a, w, h, dx, dy, Undefined(), Undefined(), ep0) :\
		Apply(cshift, a, w, h, dx, dy)
}

function nnedi3x_rpow2_helper(clip a, int fy, int fx, int rfactor, int "nsize", int "nns", int "qual", int "etype", bool "Y", bool "U", bool "V")
{
	a.nnedi3ocl(field=fy, dw=fx, nsize=nsize, nns=nns, qual=qual, etype=etype, Y=Y, U=U, V=V)
	return rfactor <= 2 ? last : last.nnedi3x_rpow2_helper(fy, fx, bitshr(rfactor, 1), nsize, nns, qual, etype, Y, U, V)
}

function nnedi3x_rpow2(clip a, int "rfactor", int "nsize", int "nns", int "qual", int "etype", int "pscrn", string "cshift", int "fwidth", int "fheight", "ep0", "ep1", int "threads", int "opt", int "fapprox", bool "Y", bool "U", bool "V")
{
	a.IsYUY2() ? a.ConvertToYV16() : a.IsRGB24() ? YToUV(a.ShowBlue("Y8"), a.ShowRed("Y8"), a.ShowGreen("Y8")) : a

	nsize = default(nsize, 0)
	nns = default(nns, 3)
	Y = default(Y, true)
	U = !IsY8() && default(U, true)
	V = !IsY8() && default(V, true)
	cshift = default(cshift, "")
	rfactor = default(rfactor, 2)
	assert(rfactor > 1 && bitand(rfactor, rfactor - 1) == 0, "nnedi3x_rpow2: rfactor must be a power of 2")

	csc = !(IsYV24() || IsY8()) # format has subsampled horizontally co-sited chroma, YV12 is assumed to use MPEG-2 layout
	cscu = IsYV411() || !IsYV12() && csc && cshift == "" # should we maintain alignment of subsampled horizontally co-sited chroma

	nnedi3ocl(field=1, dw=1, nsize=nsize, nns=nns, qual=qual, etype=etype, Y=Y, U=U, V=V)
	v4 = nnedi3ocl(field=0, dw=cscu?1:0, nsize=nsize, nns=nns, qual=qual, etype=etype, Y=Y, U=U, V=V)
	v8 = v4.nnedi3x_rpow2_helper(0, (Y?cscu:csc)?1:0, bitshr(rfactor, 2), nsize, nns, qual, etype, Y, U, V)
	l8 = v4.nnedi3x_rpow2_helper(0, cscu        ?1:0, bitshr(rfactor, 2), nsize, nns, qual, etype, Y, false, false)
	c8 = v4.nnedi3x_rpow2_helper(0, csc         ?1:0, bitshr(rfactor, 2), nsize, nns, qual, etype, false, U, V)
	rfactor == 2 ? last : rfactor == 4 ? v4 : csc != cscu && Y && (U || V) ? MergeChroma(l8, c8) : v8

	dxl = !cscu ? -0.5 : -rfactor/2+0.5
	dyl = -0.5
	dxc = rfactor == 2 || !csc ? -0.5 : cscu ? -rfactor/2+0.5 : 0.5
	dyc = IsYV12() ? 0.0 : -0.5

	fwidth = default(fwidth, Width())
	fheight = default(fheight, Height())

	l = cshift == "" ? last : nnedi3x_resize_helper(last, fwidth, fheight, dxl, dyl, cshift, ep0, ep1)
	c = cshift == "" ? nnedi3x_resize_helper(last, fwidth, fheight, dxc-dxl, dyc-dyl, "Spline36Resize") : nnedi3x_resize_helper(last, fwidth, fheight, dxc, dyc, cshift, ep0, ep1)

	Y ? !U && !V || dxc == dxl && dyc == dyl ? l : MergeChroma(l, c) : c

	return a.IsYUY2() ? ConvertToYUY2() : a.IsRGB24() ? MergeRGB(VToY8(), last, UToY8(), "RGB24") : last
}
