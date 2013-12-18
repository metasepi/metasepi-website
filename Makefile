ODGS := $(wildcard draw/*.odg)
PNGS := $(patsubst %.odg,%.png,${ODGS})
DOCS := $(wildcard doc/*.doc)
PDFS := $(patsubst %.doc,%.pdf,${DOCS})

POTGT := posts/2013-01-09-design_arafura.md

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

updatepo: ${POTGT}
	po4a-updatepo -M utf8 -f text -m ${POTGT} -p po/en.po

en/${POTGT}: po/en.po
	po4a-translate -M utf8 -f text -m ${POTGT} -p po/en.po -l en/${POTGT}

hakyll: hakyll.hs
	ghc --make -Wall -Werror hakyll.hs -o hakyll

build: hakyll en/${POTGT}
	./hakyll build

server: all
	./hakyll preview -p 9001

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
	rm -rf *.hi *.o en
	rm -rf `find . -name "*~"`

distclean: clean
	rm -f draw/*.png draw/*.tmp doc/*.pdf doc/*.tmp

.PHONY: lint clean updatepo
