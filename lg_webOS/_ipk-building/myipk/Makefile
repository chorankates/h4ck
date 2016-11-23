all: myipk.ipk

myipk.ipk:
	rm -rf ipk
	mkdir -p ipk/opt/myipk
	#mkdir -p ipk/
	#cp -r payload/* ipk/opt/myipk
	cp -r payload/* ipk/
	# sanity
	echo 'bar' >> ipk/opt/myipk/foo
	tar czvf control.tar.gz control
	cd ipk; tar czvf ../data.tar.gz .; cd ..
	echo 2.0 > debian-binary
	ar r myipk.ipk control.tar.gz data.tar.gz debian-binary

clean: FORCE
	rm -rf ipk
	rm -f control.tar.gz
	rm -f data.tar.gz
	rm -f myipk.ipk

FORCE:
