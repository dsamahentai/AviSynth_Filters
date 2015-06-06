###### srestore v2.7g ######
# ==================================================================================================================================
/* Change List

11/12/2013 martin53
- Update v2.7f -> v2.7g
  Refactored to use a single line ScriptClip() call like v2.7e - Neccessary to save AviSynth string heap space when RTE is called

10/28/2013 martin53
- Update v2.7e -> v2.7f
  Callable more than once from the same script with help of unique global variables per instance.
  Moderate reformatting to re-establish readability with the new variable names.
  Needs GRunT plugin  http://forum.doom9.org/showthread.php?t=139337
*/
# ==================================================================================================================================

function Srestore(clip source, float "frate", "omode", float "speed", float "blocks", int "mode", float "thresh", int "cache", clip "dclip")
{
###### parameters & other necessary vars ######
    srad  = isfloat(speed) && abs(speed)>=1 ? sqrt(abs(speed))*4 : 12
    cache = default(cache, -1)
    irate = framerate(source)
    bsize = isfloat(speed) && speed>0 ? 16 : 32

	dm      = default(mode, 2)
	om      = default(omode, 6)
	bom     = isstring(om)
	thr     = abs(default(thresh, 16))+0.01
	frfac   = bom || abs(om-3)<2.5 ? 1 : isfloat(frate) ? frate*5<irate || frate>irate ? 1 :
			\ abs(frate)/irate : round(irate*10010)%30000==0 ? 1001./2400. : 480./1001.

	numr    = abs(frfac*1001-round(frfac*1001))<0.01 ? round(frfac*1001) :
			\ abs(1001/frfac-round(1001/frfac))<0.01 ? 1001 : round(frfac*9000)
	numr    = isfloat(frate) && abs(irate*numr/float(round(numr/frfac))-frate) >
			\ abs(irate*round(frate*100)/float(round(irate*100))-frate) ? round(frate*100) : numr
	denm    = round(numr/frfac)

	###### source preparation & lut ######
	out = source
	mec = abs(dm)<2 || bom ? nop() : mergeluma(mergechroma(out, out.trim(1, 0), 0.5), out.trim(1, 0), 0.5)
	det	= default(dclip, source).killaudio.converttoyv12
	det	= det.pointresize(srad==4 ? det.width : int(det.width/2/srad+4)*4, srad==4 ? det.height : int(det.height/2/srad+4)*4).trim(2, 0)
	det	= dm<0 ? stackvertical(stackhorizontal(det.utoy, det.vtoy), det) : det
	det = bom ? det.mt_lut("x 0.5 * 64 +", y=3, u=1, v=1) : det

		code0   = "x 128 - y 128 - * 0 > x 128 - abs y 128 - abs < x 128 - 128 x - * y 128 - 128 y - * ? x y + 256 - x y + 256 - * ? 0.25 * 128 +"
		code1   = "x y - 2 ^ 3 * x y + 256 - 2 ^ - 128 +"
		diff 	= mt_makediff(det, det.trim(1, 0), y=3, u=1, v=1)
	bclp    = bom==false ? mt_lutxy(diff, diff.trim(1, 0), expr=code0, y=3, u=1, v=1).bilinearresize(bsize, bsize) :
			\ mt_lutxy(diff.trim(1, 0), mt_adddiff(diff, diff.trim(2, 0), y=3, u=1, v=1), expr=code1, y=3, u=1, v=1).bilinearresize(bsize, bsize)
	dclp    = diff.trim(1, 0).mt_lut("x 128 - abs 1.1 ^ 1 -", y=3, u=1, v=1).bilinearresize(bsize, bsize)

	###### POSTPROCESSING ######
    unblend1    = bom ? average(out.loop(2, 0, 0), -1.0, out, 2.0) : nop()
    unblend2    = bom ? average(out.trim(1, 0), 2.0, out.trim(2, 0), -1.0) : nop()

    qmask1  = bom ? mt_makediff(unblend1.removegrain(mode=19, modeU=-1, modeV=-1), unblend1, y=3, u=1, v=1) : nop()
    qmask2  = bom ? mt_makediff(unblend2.removegrain(mode=19, modeU=-1, modeV=-1), unblend2, y=3, u=1, v=1) : nop()
    diffm   = bom ? mt_makediff(out.loop(2, 0, 0), out, y=3, u=1, v=1).mt_lut("x y - abs", y=3, u=1, v=1).mt_expand() : nop()
	# 10/28/2013 note: next UPN expression is buggy, but correct expression not known
    bmask	= bom ? mt_lutxy(qmask1, qmask2, expr="x y - == 128 x 128 - 2 ^ x 128 - 2 ^ y 128 - 2 ^ + / 255 *", y=3, u=1, v=1) : nop()
    dmask	= bom ? mt_lutxy(diffm, diffm.trim(2, 0), expr="x 2 * y < x 4 < & 0 y 2 * x < y 4 < & 255 x x y + / 200 * 28 + ? ?", y=3, u=1, v=1) : nop()
    pmask	= bom ? mt_lutxy(dmask, bmask, expr="y 0 > y 255 < & x 0 == x 255 == | & x y ?", y=3, u=1, v=1) : nop()

    pp0 = bom ? average(out.loop(2, 0, 0), -0.5, out, 1.0, out.trim(1, 0), 1.0, out.trim(2, 0), -0.5) : nop()
    pp1 = bom ? mt_merge(unblend1, unblend2, dmask.removegrain(mode=12, modeU=-1, modeV=-1).greyscale(), y=3, u=3, v=3) : nop()
    pp2 = bom ? mt_merge(unblend1, unblend2, bmask.removegrain(mode=12, modeU=-1, modeV=-1), luma=true) : nop()
    pp3 = bom ? mt_merge(unblend1, unblend2, pmask.removegrain(mode=12, modeU=-1, modeV=-1), luma=true).removegrain(mode=0, modeU=12, modeV=12) : nop()

	fin  = bom ? eval(om) : nop()

	Try { BlankClip.GScriptClip("") } catch(err) { assert(false, "Unable to call GScriptClip(). Essential GRunT plugin installed? http://forum.doom9.org/showthread.php?t=139337") }
	#######################################
    # Unique Identifier Definition
    #######################################
	Try { global Srestore_InstanceNumber = Srestore_InstanceNumber+1 } catch(err) { global Srestore_InstanceNumber = 1 }

	# Runtime Environment Preparation & Call
	Eval(StrReplace("""	#"
        #######################################
        # 1) Unique Global Variables Initialization
        #######################################
		global  Srestore_lfr%%%     = -100
		global  Srestore_offs%%%    = 0
		global  Srestore_ldet%%%    = -100
		global  Srestore_lpos%%%    = 0

        #######################################
        # 2) Unique Runtime Call
        #######################################
		###### evaluation call & output calculation ######
		ARGS = "dm, om, bom, thr, frfac, numr, denm, mec, det, bclp, dclp, fin"
		source
		GScriptClip("srestore_inside_%%%(last, dm, om, bom, thr, frfac, numr, denm, mec, det, bclp, dclp, fin)", local=true, args=ARGS)

		###### final decimation & caching ######
		cache<0 ? last : last.RequestLinear(8, cache, 5, false, false)

		temp    = frameratenumerator(det)*float(numr)>2147483600. ? det.assumescaledfps(numr, denm) : nop()
		isclip(temp) ? last.changefps(temp, linear=true) : last.changefps(frameratenumerator(source)*numr, frameratedenominator(source)*denm, linear=true)

		return last

        #######################################
        # 3) Unique Runtime Function Definition
        #######################################
		function srestore_inside_%%%(clip source, dm, om, bom, thr, frfac, numr, denm, mec, det, bclp, dclp, fin) {
			out = source

			### preparation ###
			cfr = current_frame
			jmp = Srestore_lfr%%%+1==cfr
			cfo = (((cfr%denm)*numr*2+denm+(versionnumber()>2.575 ? numr : 0))%(2*denm))-denm
			bfo = cfo>-numr && cfo<=numr

			global	Srestore_lfr%%%     = cfr
			global	Srestore_offs%%%    = bfo && Srestore_offs%%%<=-4*numr
												\? Srestore_offs%%%+2*denm
												\: bfo && Srestore_offs%%%>=4*numr
													\? Srestore_offs%%%-2*denm
													\: Srestore_offs%%%

			pos = frfac==1 ? 0 : bfo ? -round((cfo+Srestore_offs%%%)/(2.*numr)) : Srestore_lpos%%%
			cof = cfo+Srestore_offs%%%+2*numr*pos

			global	Srestore_ldet%%%    = cfr+pos==Srestore_ldet%%% ? -1 : cfr+pos

			## diff value shifting ##
			d_v = yplanemax(dclp)+.015625
			Srestore_d43%%% = jmp ? Srestore_d32%%% : d_v
			global 	Srestore_d32%%% = jmp ? Srestore_d21%%% : d_v
			global	Srestore_d21%%% = jmp ? Srestore_d10%%% : d_v
			global	Srestore_d10%%% = jmp ? Srestore_d01%%% : d_v
			global	Srestore_d01%%% = jmp ? Srestore_d12%%% : d_v
			global	Srestore_d12%%% = jmp ? Srestore_d23%%% : d_v
			global	Srestore_d23%%% = jmp ? Srestore_d34%%% : d_v
			global  Srestore_d34%%% = d_v

			## diff value shifting ##
			m_v = isfloat(om) && abs(om)>5 ? lumadifference(det, det.trim(2, 0))+.015625 : 1
			Srestore_m53%%% = jmp ? Srestore_m42%%% : m_v
			global 	Srestore_m42%%% = jmp ? Srestore_m31%%% : m_v
			global  Srestore_m31%%% = jmp ? Srestore_m20%%% : m_v
			global	Srestore_m20%%% = jmp ? Srestore_m11%%% : m_v
			global	Srestore_m11%%% = jmp ? Srestore_m02%%% : m_v
			global	Srestore_m02%%% = jmp ? Srestore_m13%%% : m_v
			global	Srestore_m13%%% = jmp ? Srestore_m24%%% : m_v
			global  Srestore_m24%%% = m_v

			## get blend and clear values ##
			b_v = 128-yplanemin(bclp)
			b_v = b_v<1 ? .125 : b_v
			c_v = yplanemax(bclp)-128
			c_v = c_v<1 ? .125 : c_v

			## blend value shifting ##
			Srestore_bp3%%% = jmp ? Srestore_bp2%%% : bom ? b_v-c_v : b_v
			global 	Srestore_bp2%%% = jmp ? Srestore_bp1%%% : Srestore_bp3%%%
			global	Srestore_bp1%%% = jmp ? Srestore_bn0%%% : Srestore_bp3%%%
			global	Srestore_bn0%%% = jmp ? Srestore_bn1%%% : Srestore_bp3%%%
			global	Srestore_bn1%%% = jmp ? Srestore_bn2%%% : Srestore_bp3%%%
			global	Srestore_bn2%%% = jmp ? Srestore_bn3%%% : Srestore_bp3%%%
			global	Srestore_bn3%%% = bom ? b_v-c_v : b_v

			## clear value shifting ##
			Srestore_cp3%%% = jmp ? Srestore_cp2%%% : c_v
			global	Srestore_cp2%%% = jmp ? Srestore_cp1%%% : c_v
			global	Srestore_cp1%%% = jmp ? Srestore_cn0%%% : c_v
			global	Srestore_cn0%%% = jmp ? Srestore_cn1%%% : c_v
			global	Srestore_cn1%%% = jmp ? Srestore_cn2%%% : c_v
			global	Srestore_cn2%%% = jmp ? Srestore_cn3%%% : c_v
			global	Srestore_cn3%%% = c_v

			## used detection values ##
			bb  = select(pos+2, Srestore_bp3%%%, Srestore_bp2%%%, Srestore_bp1%%%, Srestore_bn0%%%, Srestore_bn1%%%)
			bc  = select(pos+2, Srestore_bp2%%%, Srestore_bp1%%%, Srestore_bn0%%%, Srestore_bn1%%%, Srestore_bn2%%%)
			bn  = select(pos+2, Srestore_bp1%%%, Srestore_bn0%%%, Srestore_bn1%%%, Srestore_bn2%%%, Srestore_bn3%%%)

			cb  = select(pos+2, Srestore_cp3%%%, Srestore_cp2%%%, Srestore_cp1%%%, Srestore_cn0%%%, Srestore_cn1%%%)
			cc  = select(pos+2, Srestore_cp2%%%, Srestore_cp1%%%, Srestore_cn0%%%, Srestore_cn1%%%, Srestore_cn2%%%)
			cn  = select(pos+2, Srestore_cp1%%%, Srestore_cn0%%%, Srestore_cn1%%%, Srestore_cn2%%%, Srestore_cn3%%%)

			dbb = select(pos+2, Srestore_d43%%%, Srestore_d32%%%, Srestore_d21%%%, Srestore_d10%%%, Srestore_d01%%%)
			dbc = select(pos+2, Srestore_d32%%%, Srestore_d21%%%, Srestore_d10%%%, Srestore_d01%%%, Srestore_d12%%%)
			dcn = select(pos+2, Srestore_d21%%%, Srestore_d10%%%, Srestore_d01%%%, Srestore_d12%%%, Srestore_d23%%%)
			dnn = select(pos+2, Srestore_d10%%%, Srestore_d01%%%, Srestore_d12%%%, Srestore_d23%%%, Srestore_d34%%%)
			dn2 = select(pos+2, Srestore_d01%%%, Srestore_d12%%%, Srestore_d23%%%, Srestore_d34%%%, Srestore_d34%%%)

			mb1 = select(pos+2, Srestore_m53%%%, Srestore_m42%%%, Srestore_m31%%%, Srestore_m20%%%, Srestore_m11%%%)
			mb  = select(pos+2, Srestore_m42%%%, Srestore_m31%%%, Srestore_m20%%%, Srestore_m11%%%, Srestore_m02%%%)
			mc  = select(pos+2, Srestore_m31%%%, Srestore_m20%%%, Srestore_m11%%%, Srestore_m02%%%, Srestore_m13%%%)
			mn  = select(pos+2, Srestore_m20%%%, Srestore_m11%%%, Srestore_m02%%%, Srestore_m13%%%, Srestore_m24%%%)
			mn1 = select(pos+2, Srestore_m11%%%, Srestore_m02%%%, Srestore_m13%%%, Srestore_m24%%%, .01)


			### basic calculation ###
			bbool   = .8*bc*cb>bb*cc && .8*bc*cn>bn*cc && bc*bc>cc
			blend   = bbool && bc*5>cc && dbc+dcn>1.5*thr && (dbb<7*dbc || dbb<8*dcn) && (dnn<8*dcn || dnn<7*dbc) &&
					\ (mb<mb1 && mb<mc || mn<mn1 && mn<mc || (dbb+dnn)*4<dbc+dcn || (bb*cc*5<bc*cb || mb>thr) && (bn*cc*5<bc*cn || mn>thr) && bc>thr)

			clear   = dbb+dbc>thr && dcn+dnn>thr && (bc<2*bb || bc<2*bn) && (dbb+dnn)*2>dbc+dcn && (mc<.96*mb && mc<.96*mn && (bb*2>cb || bn*2>cn) &&
					\ cc>cb && cc>cn || frfac>.45 && frfac<.55 && .8*mc>mb1 && .8*mc>mn1 && mb>.8*mn && mn>.8*mb)

			highd   = dcn>5*dbc && dcn>5*dnn && dcn>thr && dbc<thr && dnn<thr

			lowd    = dcn*5<dbc && dcn*5<dnn && dbc>thr && dnn>thr && dcn<thr && frfac>.35 && (frfac<.51 || dcn*5<dbb)

			res     = (Srestore_d43%%%<thr
					  \&& Srestore_d32%%%<thr
					  \&& Srestore_d21%%%<thr
					  \&& Srestore_d10%%%<thr
					  \&& Srestore_d01%%%<thr
					  \&& Srestore_d12%%%<thr
					  \&& Srestore_d23%%%<thr
					  \&& Srestore_d34%%%<thr)
					  \|| (dbc*4<dbb && dcn*4<dbb && dnn*4<dbb && dn2*4<dbb)
					  \|| (dcn*4<dbc && dnn*4<dbc && dn2*4<dbc)


			### offset calculation ###
			odm     = blend ? denm : clear ? 0 : highd ? denm-numr : lowd ? 2*denm-numr : cof
			odm     = odm+round((cof-odm)/(2.*denm))*2*denm
			odr     = (blend ? denm-numr : clear ? numr : highd ? numr : frfac<0.5 ? 2*numr : 2*(denm-numr)) * .9

			cof     = Srestore_ldet%%%<0
						\? cof
						\: cof>odm+odr
							\? cof-Srestore_offs%%%-odm-odr>denm && res
								\? odm+2*denm-odr
								\: odm+odr
							\: cof<odm-odr
								\? Srestore_offs%%%>denm && res
									\? odm-2*denm+odr
									\: odm-odr
								\: Srestore_offs%%%<-1.15*denm && res
									\? cof+2*denm
									\: Srestore_offs%%%>1.25*denm && res
										\? cof-2*denm
										\: cof

			global	Srestore_offs%%%    = frfac==1 ? 0 : cof-cfo-2*numr*pos
			global	Srestore_lpos%%%    = pos
			opos    = frfac==1 ? 0 : -round((cfo+Srestore_offs%%%+(bfo && Srestore_offs%%%<=-4*numr ? denm : 0))/(2.*numr))
			pos     = opos<-2 ? -2 : opos>2 ? 2 : opos

			### frame output calculation - resync - dup ###
			dbb = select(pos+2, Srestore_d43%%%, Srestore_d32%%%, Srestore_d21%%%, Srestore_d10%%%, Srestore_d01%%%)
			dbc = select(pos+2, Srestore_d32%%%, Srestore_d21%%%, Srestore_d10%%%, Srestore_d01%%%, Srestore_d12%%%)
			dcn = select(pos+2, Srestore_d21%%%, Srestore_d10%%%, Srestore_d01%%%, Srestore_d12%%%, Srestore_d23%%%)
			dnn = select(pos+2, Srestore_d10%%%, Srestore_d01%%%, Srestore_d12%%%, Srestore_d23%%%, Srestore_d34%%%)

			## dup_hq - merge ##
			dup     = opos!=pos || abs(dm)<2 || abs(dm)==3 ? 0 : dcn*5<dbc && dnn*5<dbc && (dcn<1.25*thr || bn<bc && pos==Srestore_lpos%%%) ||
					\ (dcn*dcn<dbc || dcn*5<dbc) && bn<bc && pos==Srestore_lpos%%% && dnn<.9*dbc || dnn*9<dbc && dcn*3<dbc ? 1 :
					\ (dbc*dbc<dcn || dbc*5<dcn) && bb<bc && pos==Srestore_lpos%%% && dbb<.9*dcn || dbb*9<dcn && dbc*3<dcn ||
					\ dbb*5<dcn && dbc*5<dcn && (dbc<1.25*thr || bb<bc && pos==Srestore_lpos%%%) ? -1 : 0
			mer     = bom==false && opos==pos && dup==0 && abs(dm)>2 && (dbc*8<dcn || dbc*8<dbb || dcn*8<dbc || dcn*8<dnn || dbc*2<thr ||
					\ dcn*2<thr || dnn*9<dbc && dcn*3<dbc || dbb*9<dcn && dbc*3<dcn)

			## deblend - doubleblend removal - postprocessing ##
			add     = Srestore_bp1%%%*Srestore_cn2%%%>Srestore_bn2%%%*Srestore_cp1%%%*(1+thr*.01)
					  \&& Srestore_bn0%%%*Srestore_cn2%%%>Srestore_bn2%%%*Srestore_cn0%%%*(1+thr*.01)
					  \&& Srestore_cn2%%%*Srestore_bn1%%%>Srestore_cn1%%%*Srestore_bn2%%%*(1+thr*.01)
			dup     = bom
						\? (Srestore_bn0%%%>Srestore_bp2%%%
							\&& Srestore_bn0%%%>=Srestore_bp1%%%
							\&& Srestore_bn0%%%>Srestore_bn1%%%
							\&& Srestore_bn0%%%>Srestore_bn2%%%
							\&& Srestore_cn0%%%<125
							\? (Srestore_d12%%%*Srestore_d12%%%<Srestore_d10%%%
								\|| Srestore_d12%%%*9<Srestore_d10%%%)
								\? 1
								\: (Srestore_d10%%%*Srestore_d10%%%<Srestore_d12%%%
									\|| Srestore_d10%%%*9<Srestore_d12%%%)
									\? 0
									\: 4
							\: Srestore_bp1%%%>Srestore_bp3%%%
								\&& Srestore_bp1%%%>=Srestore_bp2%%%
								\&& Srestore_bp1%%%>Srestore_bn0%%%
								\&& Srestore_bp1%%%>Srestore_bn1%%%
								\? 1
								\: 0)
						\: dup!=0
							\? dup
							\: om>0 && om<5
								\? (bbool==false
									\? 0
									\: (om==4 && Srestore_bp1%%%*Srestore_cn1%%%<Srestore_bn1%%%*Srestore_cp1%%%)
										\|| (om==3 && Srestore_d10%%%<Srestore_d01%%%)
										\|| om==1
										\? -1
										\: 1)
								\: om==5
									\? (Srestore_bp1%%%*Srestore_cp2%%%>Srestore_bp2%%%*Srestore_cp1%%%*(1+thr*.01)
										\&& Srestore_bn0%%%*Srestore_cp2%%%>Srestore_bp2%%%*Srestore_cn0%%%*(1+thr*.01)
										\&& Srestore_cp2%%%*Srestore_bn1%%%>Srestore_cn1%%%*Srestore_bp2%%%*(1+thr*.01)
										\&& (add==false || Srestore_cp2%%%*Srestore_bn2%%%>Srestore_cn2%%%*Srestore_bp2%%%)
										\? -2
										\: add
											\? 2
											\: Srestore_bn0%%%*Srestore_cp1%%%>Srestore_bp1%%%*Srestore_cn0%%%
												\&& (Srestore_bn0%%%*Srestore_cn1%%%<Srestore_bn1%%%*Srestore_cn0%%%
												\|| Srestore_cp1%%%*Srestore_bn1%%%>Srestore_cn1%%%*Srestore_bp1%%%)
												\? -1
												\: Srestore_bn0%%%*Srestore_cn1%%%>Srestore_bn1%%%*Srestore_cn0%%%
													\? 1
													\: 0)
									\: 0

			### output clip ###
			oclp    = mer && dup==0 ? mec : out
			opos    = opos + dup - (dup==0 && mer && dbc<dcn ? 1 : 0)
			dup==4 ? fin : opos<0 ? oclp.loop(1-opos, 0, 0) : oclp.trim(opos, 0)

		}
	""", "%%%", string(Srestore_InstanceNumber)))	#"
}

Function StrReplace(string s, string find, string replace) # Repeated, string replacements
# Original:- http://forum.doom9.org/showthread.php?t=147846&highlight=gscript           By Vampiredom, Gavino, IanB
{ i = s.FindStr(find) return (i==0 ? s : (s.LeftStr(i-1)+replace+s.MidStr(Strlen(find)+i)).StrReplace(find, replace)) }
