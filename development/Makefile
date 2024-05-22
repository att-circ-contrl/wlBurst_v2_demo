# wlBurst demo - Development scripts - Makefile
# Written by Christopher Thomas.

MATLAB=matlab
MATFLAGS=-nodisplay -nodesktop -nosplash
MATGUIFLAGS=-nodesktop -nosplash

default:
	@echo "Targets:   clean  gensynth  synth  robinson  york  detect  gallery"


clean:
	rm -f plots/*
	rm -f output/*

#allclean: clean
#	rm -f datacache/*

checkdirs:
	./checkdirs.sh


gensynth: checkdirs
	nice -n +10 $(MATLAB) $(MATFLAGS) \
		-r "dbstop if error; addpath('lib-wlburst-v2'); wlAddPaths; run('do_minimal_synth.m'); exit;"
	mv output/*png plots/

synth: checkdirs
	nice -n +10 $(MATLAB) $(MATFLAGS) \
		-r "dbstop if error; run('do_process_synth.m'); exit;"
	mv output/ftdata_wlburst.mat ../datasets-cooked

robinson: checkdirs
	nice -n +10 $(MATLAB) $(MATFLAGS) \
		-r "dbstop if error; run('do_process_robinson.m'); exit;"
	mv output/ftdata_robinson.mat ../datasets-cooked

york: checkdirs
	nice -n +10 $(MATLAB) $(MATFLAGS) \
		-r "dbstop if error; run('do_process_york.m'); exit;"
	mv output/ftdata_york.mat ../datasets-cooked

detect: checkdirs
	nice -n +10 $(MATLAB) $(MATFLAGS) \
		-r "dbstop if error; run('do_analysis.m'); exit;"

gallery: gallery4

gallery6:
	sync
	cd plots; makegallery.pl --width=16% --nofolders *png; cd ..

gallery5:
	sync
	cd plots; makegallery.pl --width=19% --nofolders *png; cd ..

gallery4:
	sync
	cd plots; makegallery.pl --width=24% --nofolders *png; cd ..

gallery3:
	sync
	cd plots; makegallery.pl --width=32% --nofolders *png; cd ..

gallery2:
	sync
	cd plots; makegallery.pl --width=49% --nofolders *png; cd ..

#
# This is the end of the file.
