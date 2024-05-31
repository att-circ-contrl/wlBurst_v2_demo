# wlBurst demo - Demo script - Makefile
# Written by Christopher Thomas.

MATLAB=matlab
MATFLAGS=-nodisplay -nodesktop -nosplash
# NOTE - I needed to use "-noopengl" for ft_databrowser to work.
MATGUIFLAGS=-nodesktop -nosplash -noopengl

default:
	@echo "Targets:   clean  detect  detectgui  gallery"


clean:
	rm -f plots/*

checkdirs:
	./checkdirs.sh

detect: checkdirs
	nice -n +10 $(MATLAB) $(MATFLAGS) \
		-r "dbstop if error; run('do_demo.m'); exit;"

detectgui: checkdirs
	nice -n +10 $(MATLAB) $(MATGUIFLAGS) \
		-r "dbstop if error; run('do_demo.m'); exit;"

gallery: gallery3

gallery6:
	sync
	cd plots; ../makegallery.pl --width=16% --nofolders *png; cd ..

gallery5:
	sync
	cd plots; ../makegallery.pl --width=19% --nofolders *png; cd ..

gallery4:
	sync
	cd plots; ../makegallery.pl --width=24% --nofolders *png; cd ..

gallery3:
	sync
	cd plots; ../makegallery.pl --width=32% --nofolders *png; cd ..

gallery2:
	sync
	cd plots; ../makegallery.pl --width=49% --nofolders *png; cd ..

#
# This is the end of the file.
