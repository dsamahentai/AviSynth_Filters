Function DeBlend (clip Last, bool "Debug") {

  # Declarations
Debug = Default (Debug, False)
Global Original = Last

  # Test each frame for deblending matches.
Global a = Subtract (Last, Trim (1, 0).Levels (0, 1, 255, 128, 255, False)).Levels (0, 1, 127, 0, 255, False).Trim (1, 0)
Global b = Subtract (Levels (0, 1, 255, 0, 127, False), Trim (1, 0)).Levels (0, 1, 127, 255, 0, False).DuplicateFrame (0)
Global Unblended = Merge (a, b)	# Use this as higher quality replacement in final clip
Global Diff = Subtract (a, b)


  # Perform Deblending on best matches, also decimates 5 frames to 4
ScriptClip (Original, """\
	(Dupe == "ab") ? Interleave (Unblended.SelectEvery (5, 0), Original.SelectEvery (5, 2), Original.SelectEvery (5, 3), Original.SelectEvery (5, 4)) : \
	(Dupe == "bc") ? Interleave (Original.SelectEvery (5, 0), Unblended.SelectEvery (5, 1), Original.SelectEvery (5, 3), Original.SelectEvery (5, 4)) : \
	(Dupe == "cd") ? Interleave (Original.SelectEvery (5, 0), Original.SelectEvery (5, 1), Unblended.SelectEvery (5, 2), Original.SelectEvery (5, 4)) : \
	(Dupe == "de") ? Interleave (Original.SelectEvery (5, 0), Original.SelectEvery (5, 1), Original.SelectEvery (5, 2), Unblended.SelectEvery (5, 3)) : \
	(Dupe == "ea") ? Interleave (Original.SelectEvery (5, 0), Original.SelectEvery (5, 1), Original.SelectEvery (5, 2), Original.SelectEvery (5, 3)) : \
Last""").\
AssumeFPS (Original.Framerate () * 0.8, False).Trim (0, Round ((Original.Framecount () + 1) * 0.8) - 1)


  # Find frame with least difference between a & b in every 5 frames
FrameEvaluate ("""Dupe = (Eval (Dupe) < ea) ? Dupe : "ea" """)
FrameEvaluate ("""Dupe = (Eval (Dupe) < de) ? Dupe : "de" """)
FrameEvaluate ("""Dupe = (Eval (Dupe) < cd) ? Dupe : "cd" """)
FrameEvaluate ("""Dupe = (ab < bc) ? "ab" : "bc" """)


  # Find differences between a & b for each frame
FrameEvaluate ("ea = YPlaneMinMaxDifference (Diff.SelectEvery (5, 4))")
FrameEvaluate ("de = YPlaneMinMaxDifference (Diff.SelectEvery (5, 3))")
FrameEvaluate ("cd = YPlaneMinMaxDifference (Diff.SelectEvery (5, 2))")
FrameEvaluate ("bc = YPlaneMinMaxDifference (Diff.SelectEvery (5, 1))")
FrameEvaluate ("ab = YPlaneMinMaxDifference (Diff.SelectEvery (5, 0))")


  # Create Debugging clip
Global Match = "% Similar"
Top = StackHorizontal (Original, ScriptClip (Diff, "Subtitle (String (Round ((255 - YPlaneMinMaxDifference ()) / 2.55)) + Match)"))
Bottom = StackHorizontal (a, b)
Info = StackVertical (Top, Bottom)

Return (Debug == True) ? Info : Last

}