all: clean base-files.ipk

base-files.ipk:
	rm -rf ipk
	mkdir -p ipk/
	cp -r source/* ipk/
	tar czvf control.tar.gz control
	cd ipk; tar czvf ../data.tar.gz .; cd ..
	echo 2.0 > debian-binary
	ar r base-files.ipk control.tar.gz data.tar.gz debian-binary

clean: FORCE
	rm -rf ipk
	rm -f control.tar.gz
	rm -f data.tar.gz
	rm -f base-files.ipk

FORCE:
