ODGS := $(wildcard draw/*.odg)
PNGS := $(patsubst %.odg,%.png,${ODGS})
DOCS := $(wildcard doc/*.doc)
PDFS := $(patsubst %.doc,%.pdf,${DOCS})

all: ${PNGS} ${PDFS} build

%.png: %.odg
	unoconv -n -f png -o $@.tmp $< 2> /dev/null   || \
          unoconv -f png -o $@.tmp $<                 || \
	  unoconv -n -f png -o $@.tmp $< 2> /dev/null || \
          unoconv -f png -o $@.tmp $<
	convert -resize 500x $@.tmp $@
	rm -f $@.tmp

%.pdf: %.doc
	unoconv -n -f pdf -o $@.tmp $< 2> /dev/null   || \
          unoconv -f pdf -o $@.tmp $<                 || \
	  unoconv -n -f pdf -o $@.tmp $< 2> /dev/null || \
          unoconv -f pdf -o $@.tmp $<
	mv $@.tmp $@

hakyll: hakyll.hs
	ghc --make -Wall -Werror hakyll.hs -o hakyll

build: hakyll
	./hakyll build

server: all
	./hakyll server

publish: all
	ssh sakura.masterq.net rm -rf ~/vhosts/_site ~/vhosts/_site.tar.gz
	tar cfz _site.tar.gz _site
	scp _site.tar.gz sakura.masterq.net:~/vhosts/
	ssh sakura.masterq.net tar xfz ~/vhosts/_site.tar.gz -C ~/vhosts/
	ssh sakura.masterq.net rm -rf ~/vhosts/metasepi
	ssh sakura.masterq.net mv ~/vhosts/_site ~/vhosts/metasepi

lint: hakyll.hs
	hlint -c hakyll.hs

clean:
	-./hakyll clean
	rm -rf hakyll _site.tar.gz
	rm -rf *.hi *.o
	rm -rf `find . -name "*~"`

distclean: clean
	rm -f draw/*.png draw/*.tmp doc/*.pdf doc/*.tmp

.PHONY: lint clean
