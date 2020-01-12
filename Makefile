ODGS := $(wildcard draw/*.dia)
PNGS := $(patsubst %.dia,%.png,${ODGS})
DOCS := $(wildcard doc/*.doc)
PDFS := $(patsubst %.doc,%.pdf,${DOCS})

JPOSTS := $(wildcard posts/*.md)
EPOSTS := $(patsubst %.md,en/%.md,${JPOSTS})
OPT_UPDATEPO := $(patsubst %.md,-m %.md,${JPOSTS})

all: ${PNGS} ${PDFS} build

#%.png: %.odg
#	unoconv -n -f png -o $@.tmp $< 2> /dev/null   || \
#          unoconv -f png -o $@.tmp $<                 || \
#	  unoconv -n -f png -o $@.tmp $< 2> /dev/null || \
#          unoconv -f png -o $@.tmp $<
#	convert -resize 500x $@.tmp $@
#	rm -f $@.tmp

%.png: %.dia
	dia -t png -e $@ $<

%.pdf: %.doc
	unoconv -n -f pdf -o $@.tmp $< 2> /dev/null   || \
          unoconv -f pdf -o $@.tmp $<                 || \
	  unoconv -n -f pdf -o $@.tmp $< 2> /dev/null || \
          unoconv -f pdf -o $@.tmp $<
	mv $@.tmp $@

#updatepo: ${JPOSTS}
#	po4a-updatepo -M utf8 -f text ${OPT_UPDATEPO} -p po/en.po

#en/posts/%.md: posts/%.md po/en.po
#	po4a-translate -M utf8 -f text -m $< -p po/en.po -l $@

build: # ${EPOSTS}
	stack build
	stack run metasepi-website build

server: all
	stack run metasepi-website server

publish: all
	cp -pr _site/* ~/doc/metasepi.github.io/

lint: src/Main.hs
	hlint -c src/Main.hs

clean:
	stack run metasepi-website clean
	stack clean
	rm -rf _site.tar.gz
	rm -rf *.hi *.o
	rm -rf `find . -name "*~"`

distclean: clean
	rm -f draw/*.png draw/*.tmp doc/*.pdf doc/*.tmp

.PHONY: all build server publish lint clean distclean updatepo
