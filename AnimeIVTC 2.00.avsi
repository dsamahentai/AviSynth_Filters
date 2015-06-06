# AnimeIVTC() by thetoof
# v2.00 2010-01-07
# Read the documentation for all the required info to know how to use this function

function AnimeIVTC (clip i, int "mode", int "aa", int "precision", int "killcomb", int "cache", bool "ifade"\
		, bool "chrfix"\
		, bool "blend"\  
		, bool "normconv"\
		, int "pattern"\
		, int "pass", bool "rendering" \
		, int "bbob", int "cbob", string "edimode", int "degrain", int "omode"\
		, int "i1", int "i2", int "e1", int "e2", int "e3", int "p1", int "p2" \
		, int "overlap", int "pel", int "search", bool "nnedi2pel", string "credconv"\
		, float "dark", int "thin", int "sharp", int "smooth", bool "stabilize", int "tradius", int "aapel", int "aaov", int "aablk", int "aatype"){

###General arguments###
Assert(defined(mode), "Specify a mode... please read the documentation.")

#Highest quality by default
precision 	= default ( precision, 		  3 ) 

#boolean "creds" is set to true if any of the i/p arguments are defined (i.e. if there's a 30i or 30p section to process)
creds = defined(i1) ? true : false
creds = defined(i2) ? true : creds
creds = defined(p1) ? true : creds
creds = defined(p2) ? true : creds
creds = defined(e1) ? true : creds
creds = defined(e2) ? true : creds
creds = defined(e3) ? true : creds

###Framerate preparation###
normconv = default( normconv, false)
#Determine source region by analysing framerate
Ifrate 	= round(framerate(i))==30 ? 1 : framerate(i)==25 ? 2 : 3
assert(ifrate!=3, "What is your input clip?? It's not 30fps NTSC nor 25fps PAL... maybe you're using the function for a purpose it was not meant to. Please post in the AnimeIVTC thread.")

#Set the output to the other region if normconv (norm-conversion) is set to true, use same as input if not
Ofrate 	= Ifrate==1 && normconv ? 2 : Ifrate==2 && normconv ? 1 : Ifrate

#prepare arguments for srestore and tdecimate based on user settings (as seen previously)
frate  	= Ofrate==1 ? 23.976 : 25 
tnum	= Ofrate==1 ? 24000 : 25
tden	= Ofrate==1 ? 1001 : 1



#Set pattern=0 (tdecimate) for DHT (safest)
pattern		= default ( pattern,		  0 )

#Set defaults of bobbing filters to use to general optimal quality
bbob		= default ( bbob, 	          3 )
cbob		= default ( cbob, 	          4 )

#Sets output mode to 1 (23.976fps for NTSC and 25fps for PAL) when no 30i or 30p sections are specified and sets it to 0 to use NOP() for every operation where it needs to be specified by the user
omode = (creds==false && mode!=4) || ofrate==2 || normconv ? 1 : default (omode, 0)
Assert(omode!=0, "Specify an output mode... please read the documentation.")
normconv ? assert(mode==2, "Why would you use normconv=true with a telecined source?") : nop()

###Framerate conversion arguments###
bs		= (i.width>1100) ? 16 : 8
overlap 	= default ( overlap,	       bs/2 )
pel       	= default ( pel, 		  2 )
search 		= default ( search, 		  4 )
assert(search >= 2, "Using a lower search than 2 will most probably lead to weird artifacts")
nnedi2pel 	= default ( nnedi2pel, 	      false )
credconv	= default ( credconv, 	    omode==2 ? "a" : "blah" )
creds ? assert(credconv!= "blah", "Please specify credconv. Check in the docs to see which is more appropriate to your source.") : nop()

#VFR - If this is pass=2 and that the user made a rendering pass out of pass=1, use input directly for decimation instead of recomputing everything
pass		= default (pass,		  1 )
rendering 	= default ( rendering,	      false )

#Ask if hard telecine (mode=1) is actually blend telecine (patter = 3 clean frames followed by 2 blended ones)
blend		= default ( blend, 	      false )

#Ask if double chroma blend removal is needed (see guide for more info about this problem)
chrfix	= default ( chrfix,       false )

#Set cache to 10 frames for all functions using scriptclip to prevent seeking issues + frame order mess-up with temporal filters
cache		= default ( cache,		 10 )

#Let the user decide which edimode (optimal varies greatly depending on source) and degrain (++ affects quality vs speed) settings to use in TGMC
edimode		= default ( edimode, 	   "nnedi2" )
degrain		= default ( degrain, 		  1 ) 

#Set decombing and antialiasing filters to off by default
killcomb	= default ( killcomb,		  0 )
aa		= default ( aa,			  0 )

#Set interlaced fade ins detection (and correction to off by default)
ifade		= default ( ifade,	       false )
#Also turn it off if aa=2 (use daa()), since it applies the same operation on the whole clip as ifade would have had selectively)
ifade		= aa==2 ? false : ifade

###Alright, let's start doing something :p ###


#########
#Bobbing#
#########

#Assign clip to prevent double computation
edeint= i.nnedi2(-2)
emask = i.tmm(1)

#For later NOP() use if blendbob is not needed
usebbob = chrfix && blend || mode==2


#Use non-motion-compensated bobber for blended clips since blends have a negative impact on motion detection (if blends are averaged with frames, they can be harder to detect/remove) (mode=2 and mode=1 with blend and chrfix because blend telecine... well has a lot of blends)
blendbob 	= usebbob ?	bbob<=0 ? i.tdeint(1) 					 	: 
\				bbob==1 ? i.tdeint(1,		edeint=edeint	) 		: 
\				bbob==2 ? i.tdeint(1,		edeint=edeint,emask=emask) 	: 
\				bbob==3 ? i.yadifmod(mode=1,	edeint=edeint)			:
\					  i.TGMCmod(edimode=edimode,tr2=degrain,edeint=edeint)	: NOP()

#For later NOP() use if clearbob is not needed
usecbob = mode==3 || defined(i1) || chrfix && blend==false

#Allow usage of mo-comp bobber (TempGaussMC) when source is not blended. Highly recommended for stability. (mode=3, interlaced credits, used in chrfix because impact is minimal compared to bob flicker on the whole clip)
clearbob 	= usecbob ?	cbob<=0 ? i.tdeint(1)						: 
\				cbob==1 ? i.tdeint(1,		edeint=edeint)			: 
\				cbob==2 ? i.tdeint(1,		edeint=edeint,emask=emask)	: 
\				cbob==3 ? i.yadifmod(mode=1,	edeint=edeint)			:
\					  i.TGMCmod(edimode=edimode,tr2=degrain,edeint=edeint)	: NOP()

############################
#Chroma swap between fields# chrfix
############################

#Repair double chroma blending if requested by user using xbob depending on source (known by the mode)
chrdeb = chrfix ? blend || mode==2 ? blendbob.chroma_rep(cache) : clearbob.chroma_rep(cache) : nop()

#Remove duplicates (like a safe selecteven/odd) for further processing before final decimation (hybrid decimation (except blend decimation to prevent having 2 calls of tdecimate) or blend telecine IVTC)
#Once bobbed, in mode=1 (tdecimate(1,3,5), in mode=1 + blend = back to 30fps for further deblending, in mode=2 srestore will do the job, in mode=3 tdecimate(1,3,5), in mode 4 VFR needs 30, CFR can do it (personal notes)
debprep = chrfix ? mode==1 && blend || mode==4 && omode==2 ? chrdeb.tdecimate(1,1,2) : chrdeb : i

################
#Field matching# MODE=1 AND 4
################

#Field match for mode 1, pass 2 of mode 4 (hybrid without tfm.txt output) or mode=4 with blend decimation (no need for txt file) or mode=4 with interlaced credits (txt file unusable)
usefm = mode==1 || (mode==4 && (pass==2 || creds || omode==1))

#field match for hard telecine or blend telecine restoration for mode==1
fm = 	(precision==0 && usefm) ? blend ? debprep.srestore(omode="pp0") : i.tfm(slow=2) : 
\	(precision==1 && usefm) ? blend ? debprep.srestore(omode="pp1") : i.tfm(slow=2,clip2=edeint) : 
\	(precision==2 && usefm) ? blend ? debprep.srestore(omode="pp2") : i.tfm(slow=2,clip2=i.tdeint(2,edeint=edeint)) : 
\	(precision==3 && usefm) ? blend ? debprep.srestore(omode="pp3") : i.tfm(slow=2,clip2=i.tdeint(2,edeint=edeint,emask=emask)) : 
\	nop()
fm = usefm ? ifade ? fm.smartfademod(sfthr, sfshow, cache) : fm : nop()

#Field match + tfm.txt output for VFR clips (mode=4, pass=1)
usehfm = mode==4 && pass==1 && usefm==false

hybridfm = 	(usehfm && precision==0) ? i.tfm(slow=2, output="tfm.txt") : 
\		(usehfm && precision==1) ? i.tfm(slow=2, output="tfm.txt",clip2=i.tdeint(2)) : 
\		(usehfm && precision==2) ? i.tfm(slow=2, output="tfm.txt",clip2=i.tdeint(2,edeint=edeint)) : 
\		(usehfm && precision==3) ? i.tfm(slow=2, output="tfm.txt",clip2=i.tdeint(2,edeint=edeint,emask=emask)) : 
\		nop()
hybridfm = usehfm ? ifade ? hybridfm.smartfademod(sfthr, sfshow, cache) : hybridfm : nop()

###############        ######################
#Field blended# MODE=2 #Double hard telecine# MODE=3
###############	       ######################

#Since during double chroma blend removal it was checked whether to use blendbob or clearbob depending on the source (blendbob was used for field blended and clearbob was used for double hard telecine), use chrbob when chrfix=true, else use the appropriate one

fbbob = mode==2 ? chrfix ? debprep : blendbob : nop()

dhtbob = mode==3 ? chrfix ? debprep : clearbob : nop()

################
#CFR decimation# OMODE=1
################

#HT decimation (mode=1), remove 3 frames out of 5 when chrfix=true since the clip has been bobbed to 60fps
fmdecim = mode==1 ? chrfix ? debprep.tdecimate(1,3,5) : 			fm.tdecimate() 											: nop()

#Field blended blend removal & decimation (mode=2) No need to check for chrfix since it was done in the previous step
fbdecim = mode==2 ? chrfix ? fbbob.srestore(frate=frate, cache=cache) : 	fbbob.srestore(frate=frate, cache=cache, dclip=i.bob(-0.2,0.6).reduceflicker(strength=1)) 	: nop()

#Pattern finding and decimation for double hard telecine (mode=3) No need to check for chrfix since it was done in the previous step
a= mode==3 && (pattern==1 || pattern==-1) ? dhtbob.selectevery(5,0,3) : NOP()
b= mode==3 && (pattern==2 || pattern==-1) ? dhtbob.selectevery(5,1,4) : NOP()
c= mode==3 && (pattern==3 || pattern==-1) ? dhtbob.selectevery(5,0,2) : NOP()
d= mode==3 && (pattern==4 || pattern==-1) ? dhtbob.selectevery(5,1,3) : NOP()
e= mode==3 && (pattern==5 || pattern==-1) ? dhtbob.selectevery(5,2,4) : NOP()
dhtdecim = mode==3 ? 			pattern==-1 ? stackvertical(stackhorizontal(a.subtitle("pattern=1"),b.subtitle("pattern=2"),c.subtitle("pattern=3")),stackhorizontal(d.subtitle("pattern=4"),e.subtitle("pattern=5"),e.blackness())) : 
\					pattern==1 ? a : 
\					pattern==2 ? b : 
\					pattern==3 ? c : 
\					pattern==4 ? d : 
\					pattern==5 ? e : 
\					pattern==0 ? dhtbob.tdecimate(1,3,5) : nop() : nop()

#Hybrid CFR blend decimation of 30p into 24p
blenddecim = (mode==4 && omode==1) ? chrfix ? debprep.tdecimate(1,3,5,hybrid=1) : 	fm.tdecimate(hybrid=1) 				: nop()

#########
#Credits# CREDS=TRUE (USER SPECIFIES I1, I2, P1, P2, E1, E2 OR E3)
#########

#Interlaced : use the same smart-bobbed clip as before; we don't care if the background is blended or not since it is unrecoverable anyways (at least for now... see developments about using masking to isolate creds from background)
credbob = defined(i1) ? clearbob.selecteven() : nop()

#Progressive : Blend deinterlace the 24t background while doing minimal damage on the 30p credits
blendbg= defined(p1) ? i.daa() : nop()

###CFR conversion###
#######################
###Framerate conversion (recommended for static or low-motion backgrounds since it is prone artifacts... it reduces framerate/motion based on motion vectors)

#External pelclip on source with nnedi, if requested
upsi = 		nnedi2pel && usemocompi ? 	credbob.	nnedi2_rpow2(rfactor=pel,cshift="spline36resize") 		 : nop()
upsp = 		nnedi2pel && usemocompi ? 	blendbg.	nnedi2_rpow2(rfactor=pel,cshift="spline36resize") 		 : nop()

####Convert the framerate of the interlaced credits
#Determine if usage of the following conversion is required
usemocompi = defined(i1) && credconv=="mocomp"

#Prepare super clip for the interlaced credits
credbobsuper	= usemocompi ? 			credbob.	MSuper(pel=pel, levels=0) 					 : nop()
credbobupsuper	= usemocompi && nnedi2pel ? 	credbob.	MSuper(pel=pel, levels=0, pelclip=upsi) 			 : nop()

#Calculate vectors
bvi = 		usemocompi ? nnedi2pel ? 	credbobupsuper.	MAnalyse(isb = true,search=search, blksize=bs, overlap=overlap)  : 
\						credbobsuper.	MAnalyse(isb = true,search=search, blksize=bs, overlap=overlap)  : nop()

fvi = 		usemocompi ? nnedi2pel ? 	credbobupsuper.	MAnalyse(isb = false,search=search, blksize=bs, overlap=overlap) : 
\						credbobsuper.	MAnalyse(isb = false,search=search, blksize=bs, overlap=overlap) : nop()

#Apply framerate conversion
fpsconvi =  	usemocompi ? nnedi2pel ? 	credbob.	MFlowFps(credbobupsuper,bvi, fvi, tnum, tden) 			 : 
\						credbob.	MFlowFps(credbobsuper,  bvi, fvi, tnum, tden) 			 : nop()

###Convert the framerate of the progressive credits
#Determine if usage of the following conversion is required
usemocompp = defined(p1) && credconv=="mocomp"

#Prepare super clip for the progressive credits
blendbgsuper	= usemocompp ?			blendbg.MSuper(pel=pel, levels=0) 						 : nop()
blendbgsuperup	= usemocompp && nnedi2pel ? 	blendbg.MSuper(pel=pel, levels=0, pelclip=upsp) 				 : nop()

#Calculate vectors
bvp = 		usemocompp ? nnedi2pel ? 	blendbgsuperup.	MAnalyse(isb = true,search=search, blksize=bs, overlap=overlap)  : 
\						blendbgsuper.	MAnalyse(isb = true,search=search, blksize=bs, overlap=overlap)  : nop()

fvp = 		usemocompp ? nnedi2pel ? 	blendbgsuperup.	MAnalyse(isb = false,search=search, blksize=bs, overlap=overlap) : 
\						blendbgsuper.	MAnalyse(isb = false,search=search, blksize=bs, overlap=overlap) : nop()

#Apply framerate conversion
fpsconvp = 	usemocompp ? nnedi2pel ?	blendbg.MFlowFps(blendbgsuperup,bvp, fvp, tnum, tden) 				 : 
\						blendbg.MFlowFps(blendbgsuper,  bvp, fvp, tnum, tden) 				 : nop()

#######################
###Blend 30p creds into 24t (ugly and fast, but can lead to less disturbing artifacts when you have a high motion background)
blendi = defined(i1) && credconv=="blend" ? credbob.convertfps(tnum,tden) : nop()

blendp = defined(p1) && credconv=="blend" ? blendbg.convertfps(tnum,tden) : nop()

########
#SPLICE# CREDS=TRUE (USER SPECIFIES I1, I2, P1, P2, E1, E2 OR E3)
########

#Determine the "mix" mode (how the different sections (30i, 24t, 30p) are spliced together)
#Also check for user error when entering the frame numbers

mix22a17	= defined(e1) && defined(e2) && defined(e3) && defined(i1) && defined(p1)	? true : false
mix7 		= defined(e1) && defined(e2) && defined(e3) && defined(i1) && defined(i2)	? true : false
mix14 		= defined(e1) && defined(e2) && defined(e3) && defined(p1) && defined(p2)	? true : false

mix21a20a16a15 	= defined(e1) && defined(e2) && defined(i1) && defined(p1) && mix22a17==false	? true : false
mix6a3 		= defined(e1) && defined(e2) && defined(i1) && defined(i2) && mix7==false	? true : false
mix13a10	= defined(e1) && defined(e2) && defined(p1) && defined(p2) && mix14==false	? true : false

mix19a18	= defined(e1) && defined(p1) && defined(i1) && mix21a20a16a15==false	? true : false 
mix9 		= defined(e1) && defined(p1) && defined(p2) && mix13a10==false		? true : false
mix2 		= defined(e1) && defined(i1) && defined(i2) && mix6a3==false		? true : false
mix4 		= defined(e1) && defined(e2) && defined(i1) && mix21a20a16a15==false && mix6a3==false	? true : false
mix11 		= defined(e1) && defined(e2) && defined(p1) && mix21a20a16a15==false && mix13a10==false	? true : false

mix1a5 	= defined(e1) && defined(i1) && mix19a18==false && mix2==false && mix4==false		? true : false
mix8a12 = defined(e1) && defined(p1) && mix19a18==false && mix11==false && mix9==false		? true : false


#Getting the "mix" mode based on user input
mix = 0
mix = mix1a5 		&& i1<e1 		? 1 : mix
mix = mix2 		&& i1<e1<i2 		? 2 : mix
mix = mix6a3 		&& i1<e1<i2<e2 		? 3 : mix
mix = mix4 		&& e1<i1<e2 		? 4 : mix
mix = mix1a5 		&& e1<i1 		? 5 : mix
mix = mix6a3 		&& e1<i1<e2<i2 		? 6 : mix
mix = mix7 		&& e1<i1<e2<i2<e3 	? 7 : mix
mix = mix8a12 		&& p1<e1 		? 8 : mix
mix = mix9 		&& p1<e1<p2 		? 9 : mix
mix = mix13a10 		&& p1<e1<p2<e2 		? 10 : mix
mix = mix11 		&& e1<p1<e2 		? 11 : mix
mix = mix8a12 		&& e1<p1 		? 12 : mix
mix = mix13a10 		&& e1<p1<e2<p2 		? 13 : mix
mix = mix14 		&& e1<p1<e2<p2<e3 	? 14 : mix
mix = mix21a20a16a15 	&& e1<i1<e2<p1 		? 15 : mix
mix = mix21a20a16a15 	&& i1<e1<p1<e2 		? 16 : mix
mix = mix22a17 		&& e1<i1<e2<p1<e3 	? 17 : mix
mix = mix19a18 		&& i1<e1<p1 		? 18 : mix
mix = mix19a18 		&& p1<e1<i1 		? 19 : mix
mix = mix21a20a16a15 	&& e1<p1<e2<i1 		? 20 : mix
mix = mix21a20a16a15 	&& p1<e1<i1<e2 		? 21 : mix
mix = mix22a17 		&& e1<p1<e2<i1<e3 	? 22 : mix
mix = defined(i2) && defined(i1)==false ? 0 : mix
mix = defined(p2) && defined(p1)==false ? 0 : mix
mix = defined(e2) && defined(e1)==false ? 0 : mix
mix = defined(e3) && defined(e2)==false ? 0 : mix
mix = defined(e3) && defined(e1)==false ? 0 : mix
mix = defined(i1) && defined(e1)==false ? 0 : mix
mix = defined(p1) && defined(e1)==false ? 0 : mix
creds ? assert(mix!=0, "Mistake in entering i1, e1.... parameters. Please check.") : nop()

#Determine frame numbers based on mix mode and user input of i/p/e1/2/3
istart1=mix==1 || mix==2 || mix==3 || mix==16 || mix==18 					? 0 	: \
	mix==4 || mix==5 || mix==6 || mix==7 || mix==15 || mix==17 || mix==19 || mix==21  	? e1+1 	: \
	mix==20	|| mix==22									? e2+1  : nop()

istart2=mix==2 || mix==3 ? e1+1 : mix==6 || mix==7 ? e2+1 : nop()

pstart1=mix==8 || mix==9 || mix==10 || mix==19 || mix==21 					? 0 	: \
	mix==11 || mix==12 || mix==13 || mix==14 || mix==16 || mix==18 || mix==20 || mix==22  	? e1+1 	: \
	mix==15	|| mix==17									? e2+1  : nop()

pstart2=mix==9 || mix==10 ? e1+1 : mix==13 || mix==14 ? e2+1 : nop()

estart1=mix==4 || mix==5 || mix==6 || mix==7 || mix==11 || mix==12 || mix==13 || mix==14 || mix==15 || mix==17 || mix==20 || mix==22	? 0 	: \
	mix==1 || mix==2 || mix==3 || mix==16 || mix==18  										? i1+1 	: \
	mix==8 || mix==9 || mix==10 || mix==19 || mix==21										? p1+1  : nop()

estart2=mix==4 || mix==6 || mix==7 || mix==15 || mix==17 || mix==21  	? i1+1 	: \
	mix==3 								? i2+1  : \
	mix==11 || mix==13 || mix==14 || mix==16 || mix==20 || mix==22 	? p1+1 	: \
	mix==10								? p2+1  : nop()

estart3=mix==7 ? i2+1 : mix==14 ? p2+1 : mix==17 ? p1+1 : mix==22 ? i1+1 : nop()

maxfps = defined(i1) ? framerate(i) : defined(p1) ? framerate(i) : nop()

#Final 24fps ivtced clip and deinterlaced + framerate converted for CFR (omode=1)
tocfrfinalt = omode==1 ? (mode==1) ? fmdecim : (mode==2) ? fbdecim : (mode==3) ? dhtdecim : (mode==4 && omode==1) ? blenddecim : nop() : nop()
tocfrfinali = omode==1 && creds ? (credconv=="mocomp") ? fpsconvi : (credconv=="blend") ? blendi : nop() : nop()
tocfrfinalp = omode==1 && creds ? (credconv=="mocomp") ? fpsconvp : (credconv=="blend") ? blendp : nop() : nop()

#Final 30fps clips (prepare for hybrid decimation, make everything 30fps) for hybrid use fm since it will be spliced (txt file will be useless) (used when creds=true)
tovfrfinalt = omode==2 && creds ? (mode==1) ? fm : (mode==2) ? fbdecim.changefps(maxfps) : (mode==3) ? dhtdecim.changefps(maxfps) : (mode==4 && omode==2) ? fm : nop() : nop()
tovfrfinali = omode==2 && creds ? credbob : nop()
tovfrfinalp = omode==2 && creds ? blendbg : nop()

#Final clip to splice
spliceprept = mix!=0 ? omode==1 ? tocfrfinalt : omode==2 ? tovfrfinalt : nop() : nop()
spliceprepi = mix!=0 ? omode==1 ? tocfrfinali : omode==2 ? tovfrfinali : nop() : nop()
spliceprepp = mix!=0 ? omode==1 ? tocfrfinalp : omode==2 ? tovfrfinalp : nop() : nop()

#######################
###Trim
#Factor to get the proper trim values after decimating
factor = omode==1 ? defined(i1) ? float(framerate(tocfrfinali)/framerate(i)) : defined(p1) ? float(framerate(tocfrfinalp)/framerate(i)) : nop() : nop()

et1 = 	defined(e1) ? omode==2 ? spliceprept.trim(estart1,e1) : spliceprept.trim(int(estart1*factor),int(e1*factor)) : nop()
et2 = 	defined(e2) ? omode==2 ? spliceprept.trim(estart2,e2) : spliceprept.trim(int(estart2*factor),int(e2*factor)) : nop()
et3 = 	defined(e3) ? omode==2 ? spliceprept.trim(estart3,e3) : spliceprept.trim(int(estart3*factor),int(e3*factor)) : nop()

ci1 = 	defined(i1) ? omode==2 ? spliceprepi.trim(istart1,i1) : spliceprepi.trim(int(istart1*factor),int(i1*factor)) : nop()
ci2 = 	defined(i2) ? omode==2 ? spliceprepi.trim(istart2,i2) : spliceprepi.trim(int(istart2*factor),int(i2*factor)) : nop()

#Prepare 30p sections for splicing
cp1 = 	defined(p1) ? omode==2 ? spliceprepp.trim(pstart1,p1) : spliceprepp.trim(int(pstart1*factor),int(p1*factor)) : nop()
cp2 = 	defined(p2) ? omode==2 ? spliceprepp.trim(pstart2,p2) : spliceprepp.trim(int(pstart2*factor),int(p2*factor)) : nop()

spliced=(mix==1) ? 	ci1 + 	et1 : \
	(mix==2) ? 	ci1 + 	et1 + 	ci2 : \
	(mix==3) ? 	ci1 + 	et1 + 	ci2 + 	et2 : \ 
	(mix==4) ? 	et1 + 	ci1 + 	et2 : \
	(mix==5) ? 	et1 + 	ci1 : \ 
	(mix==6) ? 	et1 + 	ci1 + 	et2 + 	ci2 : \
	(mix==7) ? 	et1 + 	ci1 + 	et2 + 	ci2 + 	et3 : \
	(mix==8) ? 	cp1 + 	et1 : \
	(mix==9) ? 	cp1 + 	et1 + 	cp2 : \
	(mix==10) ? 	cp1 + 	et1 + 	cp2 + 	et2 : \ 
	(mix==11) ? 	et1 + 	cp1 + 	et2 : \
	(mix==12) ? 	et1 + 	cp1 : \ 
	(mix==13) ? 	et1 + 	cp1 + 	et2 + 	cp2 : \
	(mix==14) ? 	et1 + 	cp1 + 	et2 + 	cp2 + 	et3 : \
	(mix==15) ? 	et1 + 	ci1 + 	et2 + 	cp1 : \
	(mix==16) ? 	ci1 + 	et1 + 	cp1 + 	et2 : \
	(mix==17) ?	et1 + 	ci1 + 	et2 + 	cp1 +	et3 : \
	(mix==18) ? 	ci1 + 	et1 + 	cp1 : \
	(mix==19) ? 	cp1 + 	et1 + 	ci1 : \ 
	(mix==20) ? 	et1 + 	cp1 + 	et2 + 	ci1 : \
	(mix==21) ? 	cp1 + 	et1 + 	ci1 + 	et2 : \
	(mix==22) ? 	et1 + 	cp1 + 	et2 + 	ci1 +	et3 : \
	NOP()

finalcfr =  omode==1 ? creds ? spliced : tocfrfinalt : nop()
tovfrdec1 = omode==2 ? creds ? spliced : chrfix ? debprep : hybridfm : nop()
tovfrdec2 = omode==2 ? rendering ? i : creds ? spliced : chrfix ? debprep : fm : nop()

finalvfr = 	omode==2 && pass==1 ? tovfrdec1.TDecimate(4, output="stats.txt") : 
\		omode==2 && pass==2 ? tovfrdec2.TDecimate(5,hybrid=2,tfmin=creds ? "" : "tfm.txt",input="stats.txt",mkvout="timecodes.txt",batch=true) : nop()

topp = omode==1 ? finalcfr : omode==2 ? finalvfr : nop()

#Kill combing depending on user settings
dec = 	killcomb==0 ? topp : 
\	killcomb==1 ? topp.vinverse() : 
\	killcomb==2 ? topp.vinverseD() : 
\		interleave(	topp.		 subtitle("killcomb=0",align=9),
\				topp.vinverse(). subtitle("killcomb=1",align=9),
\				topp.vinverseD().subtitle("killcomb=2",align=9))

aaed = 	aa==0 ? dec : 
\	aa==1 ? dec.ediaa() : 
\	aa==2 ? dec.daa() : 
\	aa==3 ? dec.maa() : 
\	aa==4 ? dec.sharpaamcmod(dark,thin,sharp,smooth,stabilize,tradius,aapel,aaov,aablk,aatype) : 
\			interleave(	dec.		subtitle("aa=0",align=9),
\					dec.ediaa().	subtitle("aa=1",align=9),
\					dec.daa().	subtitle("aa=2",align=9),
\					dec.maa().	subtitle("aa=3",align=9),
\					dec.sharpaamcmod(dark,thin,sharp,smooth,stabilize,tradius,aapel,aaov,aablk,aatype).subtitle("aa=4",align=9))

return omode==2 && pass==1 ? finalvfr : aaed
}


function chroma_rep(clip source, int "cache")
{
###### parameters & other necessary vars ######
    cache   = default(cache,-1)


###### source preparation & lut ######
global  out1    = source
global  out2    = mergechroma(source,mt_adddiff(source.trim(1,0),mt_makediff(source.trim(1,0),source.trim(2,0),y=1,u=3,v=3),y=1,u=3,v=3).blur(1))


###### initialise variables ######
global  lfr     = -100


###### evaluation call & output calculation ######
scriptclip( source, """

 ### preparation ###
        cfr = current_frame
        jmp = lfr+1==cfr
        
    global  lfr = cfr

        l_v = LumaDifference(out1.trim(1,0),out1.trim(2,0))
        c_v = ChromaUDifference(out1.trim(1,0),out1.trim(2,0)) + ChromaVDifference(out1.trim(1,0),out1.trim(2,0))

  ## luma value shifting ##
    l10 = jmp ? l01 : l_v
	l01	= jmp ? l12 : l_v
	l12	= l_v
	
  ## chroma value shifting ##
    c10 = jmp ? c01 : c_v
	c01 = jmp ? c12 : c_v
	c12 = c_v
	
 ### condition ###
    change  = l12*3<l01 && c01*1.5<c12
    chango  = l01*3<l10 && c10*1.5<c01
    
    change ? out2 : chango ? out1.trim(1,0) : out1

""")


###### final decimation & caching ######
cache<0 ? last : last.RequestLinear(8, cache, 5, false, false)

return last
}


#based on smartfade v0.2 by martino - Aimed at removing interlaced fades in anime. Uses luma difference between two fields as activation threshold.
#mod by thetoof : removed degrainmedian post-processing, 
#		changed how the fields are blended together (average of 2 nnedi interpolations + contra-sharpening to retain more detail) and 
#		added cache parameter to forward the setting of animeivtc to this function
#		renamed global parameter to something less general than "threshold"

function smartfademod(clip clip, float "sfthr", bool "sfshow", int "cache") {
    
global sfthr	= default ( sfthr,  0.4 ) # Threshold for fade detection.
show		= default ( show, false ) # Displays luma difference between fields without processing anything.
cache		= default ( cache,   10 ) # Cache the frames to help seeking and other functions requesting many frames

show ? scriptclip(c, "subtitle(string(abs(	  separatefields().selectodd().averageluma() \
            				- separatefields().selecteven().averageluma())))") : \
       scriptclip(c, "sep = separatefields() \
       avg = sep.selectodd().averageluma() - sep.selecteven().averageluma() \
       abs(avg) > sfthr ? interleave(sep.selecteven(),sep.selectodd()).weave().daa() : last")

cache<0 ? last : last.RequestLinear(8, cache, 5, false, false)

    return last

}

#Suggested by Mystery Keeper in "Denoise of tv-anime" thread
function ediaa(clip a) {return a.EEDI2(field=1).TurnRight().EEDI2(field=1).TurnLeft().spline36resize(a.width,a.height,-0.5,-0.5)}

#Anti-aliasing with contra-sharpening by Didée
function daa(clip c) {
nn	= c.nnedi2(field=-2)
dbl   	= mt_average(selecteven(nn),selectodd(nn),U=3,V=3)
dblD 	= mt_makediff(c,dbl,U=3,V=3)
shrpD 	= mt_makediff(dbl,dbl.removegrain((width(c)>1100) ? 20 : 11),U=3,V=3)
DD 	= shrpD.repair(dblD,13)
return dbl.mt_adddiff(DD,U=3,V=3) }

#Anti-aliasing with edge masking by martino, mask using "sobel" taken from Kintaro's useless filterscripts and modded by thetoof for spline36
function maa(clip input, int "mask") {
mask = input.mt_edge("sobel",7,7,5,5).mt_inflate()
aa_clip=input.spline36Resize(width(input)*2,height(input)*2).TurnLeft().SangNom().TurnRight().SangNom().spline36Resize(width(input),height(input)).MergeChroma(input) 
return mt_merge(input,aa_clip,mask) }

#Developped in the "fine anime antialiasing thread"
function SharpAAMCmod(clip orig, float "dark", int "thin", int "sharp", int "smooth", bool "stabilize", int "tradius", int "aapel", int "aaov", int "aablk", string "aatype")
{
dark	= default ( dark,     0.2 ) # strokes darkening strength
thin	= default ( thin,      10 ) # Presharpening
sharp	= default ( sharp,    150 ) # Postsharpening
smooth	= default ( smooth,    -1 ) # Postsmoothing
stabilize= default ( stabilize,false ) # Use post stabilization with Motion Compensation
Tradius	= default ( Tradius,    2 ) # 2 = MDegrain2 / 3 = MDegrain3 
aapel	= default ( aapel,      1 ) # accuracy of the motion estimation (Value can only be 1, 2 or 4. 1 means a precision to the pixel. 2 means a precision to half a pixel, 4 means a precision to quarter a pixel, produced by spatial interpolation (better but slower).)
aaov	= default ( aaov,       (orig.width>1100) ? 8 : 4 ) # block overlap value (horizontal). Must be even and less than block size. (Higher = more precise & slower)
aablk	= default ( aablk,      (orig.width>1100) ? 16 : 8 ) # Size of a block (horizontal). It's either 4, 8 or 16 ( default is 8 ). Larger blocks are less sensitive to noise, are faster, but also less accurate.
aatype	= default ( aatype, "Sangnom" ) # Use Sangnom() or EEDI2() for anti-aliasing

w=width(orig)
h=height(orig)
m=mt_logic( orig.DEdgeMask(0,255,0,255,"5 10 5 0 0 0 -5 -10 -5", divisor=4,Y=3,U=3,V=3)
 \       ,orig.DEdgeMask(0,255,0,255,"5 0 -5 10 0 -10 5 0 -5", divisor=4,Y=3,U=3,V=3)
 \       ,"max").mt_lut("x 128 / 0.86 ^ 255 *")
preaa=(thin==0 && dark==0) ? orig : (thin==0) ? orig.Toon(dark) : (dark==0) ? orig.awarpsharp2(depth=thin) : orig.Toon(dark).awarpsharp2(depth=thin)
aa= (aatype=="Sangnom") ? preaa.spline36resize(w*2,h*2).TurnLeft().SangNom().TurnRight().SangNom().spline36resize(w,h) : (aatype=="EEDI2") ? preaa.ediaa() : blankclip(pixel_type="YV12").subtitle("Please use Sangnom or EEDI2 for aatype")
postsh=(sharp==0 && smooth==0) ? aa : aa.lsfmod(edgemode=1,strength=sharp,overshoot=1,soft=smooth)
merged=mt_merge(orig,postsh,m,Y=3,U=3,V=3)

sD=mt_makediff(orig,merged)

origsuper= orig.MSuper(pel=aapel)
sDsuper  = sD.  MSuper(pel=aapel, levels=1)


fv3 = tradius==3 ? origsuper.MAnalyse(isb=false,delta=3,overlap=aaov,blksize=aablk) : nop()
fv2 = tradius>=2 ? origsuper.MAnalyse(isb=false,delta=2,overlap=aaov,blksize=aablk) : nop()
fv1 = tradius>=1 ? origsuper.MAnalyse(isb=false,delta=1,overlap=aaov,blksize=aablk) : nop()
bv1 = tradius>=1 ? origsuper.MAnalyse(isb=true, delta=1,overlap=aaov,blksize=aablk) : nop()
bv2 = tradius>=2 ? origsuper.MAnalyse(isb=true, delta=2,overlap=aaov,blksize=aablk) : nop()
bv3 = tradius==3 ? origsuper.MAnalyse(isb=true, delta=3,overlap=aaov,blksize=aablk) : nop()
sDD = tradius==1 ? sD.MDegrain1(sDsuper,bv1,fv1) : tradius==2 ? sD.MDegrain2(sDsuper,bv1,fv1,bv2,fv2) : sD.MDegrain3(sDsuper,bv1,fv1,bv2,fv2,bv3,fv3)

reduc = 0.4
sDD = mt_lutxy(sD,sDD,"x 128 - abs y 128 - abs < x y ?").mergeluma(sDD,1.0-reduc)

return stabilize ? orig.mt_makediff(sDD,U=2,V=2) : merged
}

# Kill Combing Function from mcbob
function VinverseD(clip clp, float "sstr", int "amnt", int "uv")
{
uv   = default(uv,3)
sstr = default(sstr,2.7)
amnt = default(amnt,255)
uv2  = (uv==2) ? 1 : uv
STR  = string(sstr)
AMN  = string(amnt)
vblur  = clp.mt_convolution("1","50 99 50",U=uv,V=uv)
vblurD = mt_makediff(clp,vblur,U=uv2,V=uv2)
Vshrp  = mt_lutxy(vblur,vblur.mt_convolution("1","1 4 6 4 1",U=uv2,V=uv2),expr="x x y - "+STR+" * +",U=uv2,V=uv2)
VshrpD = mt_makediff(Vshrp,vblur,U=uv2,V=uv2)
VlimD  = mt_lutxy(VshrpD,VblurD,expr="x 128 - y 128 - * 0 < x 128 - abs y 128 - abs < x y ? 128 - 0.25 * 128 + x 128 - abs y 128 - abs < x y ? ?",U=uv2,V=uv2)
mt_adddiff(Vblur,VlimD,U=uv,V=uv)
(amnt>254) ? last : (amnt==0) ? clp : mt_lutxy(clp,last,expr="x "+AMN+" + y < x "+AMN+" + x "+AMN+" - y > x "+AMN+" - y ? ?",U=uv,V=uv) 
return(last)
}
