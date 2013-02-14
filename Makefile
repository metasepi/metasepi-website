ODGS := $(wildcard draw/*.odg)
PNGS := $(patsubst %.odg,%.png,${ODGS})

all: build ${PNGS}

%.png: %.odg
	unoconv -n -f png -o $@.tmp $< 2> /dev/null   || \
          unoconv -f png -o $@.tmp $<                 || \
	  unoconv -n -f png -o $@.tmp $< 2> /dev/null || \
          unoconv -f png -o $@.tmp $<
	convert -resize 500x $@.tmp $@
	rm -f $@.tmp

hakyll: hakyll.hs
	ghc --make -Wall -Werror hakyll.hs -o hakyll

build: hakyll
	./hakyll build

server: all
	./hakyll server

publish: all
	ssh sakura.masterq.net rm -rf ~/vhosts/_site
	scp -pr _site sakura.masterq.net:~/vhosts/
	ssh sakura.masterq.net rm -rf ~/vhosts/metasepi
	ssh sakura.masterq.net mv ~/vhosts/_site ~/vhosts/metasepi

lint: hakyll.hs
	hlint -c hakyll.hs

clean:
	-./hakyll clean
	rm -rf hakyll
	rm -rf *.hi *.o
	rm -rf `find . -name "*~"`

distclean: clean
	rm -f draw/*.png draw/*.tmp

.PHONY: lint clean
