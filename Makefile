ODGS := $(wildcard draw/*.odg)
PNGS := $(patsubst %.odg,%.png,${ODGS})

all: build ${PNGS}

%.png: %.odg
	unoconv -f png $<

hakyll: hakyll.hs
	ghc --make -Wall -Werror hakyll.hs -o hakyll

build: hakyll
	./hakyll build

server: build
	./hakyll server

publish: build
	ssh sakura.masterq.net rm -rf ~/vhosts/_site ~/vhosts/metasepi
	scp -pr _site sakura.masterq.net:~/vhosts/
	ssh sakura.masterq.net mv ~/vhosts/_site ~/vhosts/metasepi

lint: hakyll.hs
	hlint -c hakyll.hs

clean:
	-./hakyll clean
	rm -rf hakyll
	rm -rf *.hi *.o
	rm -rf `find . -name "*~"`

distclean: clean
	rm -f draw/*.png

.PHONY: lint clean
