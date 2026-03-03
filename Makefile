AE_START_TS := $(shell date +%s)
AE_END_TS := $(shell date +%s --date="1 month")

START_TS := $(shell date +"%Y-%m-%d")
END_TS := $(shell date +"%Y-%m-%d" --date="1 month")

TOTAL_ENVIRONMENT_API_TOKEN := $(shell curl_chrome116 --silent --insecure 'https://api.total-environment.com/api/v1.0/token.json' | jq -r '.data.token')

# Set PYTHONPATH for module imports
export PYTHONPATH := $(CURDIR)/src

define restore-file
	(echo "FAIL $1" && git checkout -- $1 && echo "RESTORED $1")
endef

out/allevents.txt:
	curl_chrome116 --silent --cookie-jar /tmp/allevents.cookies https://allevents.in/ -o /dev/null
	curl_chrome116 --silent --cookie /tmp/allevents.cookies --request POST \
	  --url https://allevents.in/api/index.php/categorization/web/v1/list \
	  --header 'Referer: https://allevents.in/new-delhi/all' \
	  --header "Content-Type: application/json" \
	  --data-raw '{"venue": 0,"page": 1,"rows": 100,"tag_type": null,"sdate": $(AE_START_TS),"edate": $(AE_END_TS),"city": "new-delhi","keywords": 0,"category": ["all"],"formats": 0,"sort_by_score_only": true}' | \
	  jq -r '.item[] | .share_url' | sort > $@ || $(call restore-file,$@)
	echo "[ALLEVENTS] $$(wc -l $@ | cut -d ' ' -f 1)"

out/te.jsonnet:
	curl_chrome116 --silent --insecure 'https://api.total-environment.com/api/v1.0/getEvents.json' -X POST -H 'content-type: application/json' -H 'Authorization: Bearer $(TOTAL_ENVIRONMENT_API_TOKEN)' --data-raw '{"flag":"upcoming"}' --output $@

out/te.json: out/te.jsonnet
	python src/jsonnet.py out/te.jsonnet || $(call restore-file,$@)

out/skillboxes.jsonnet:
	python -m src.sources.skillboxes 9 1105542 || $(call restore-file,$@)

out/skillboxes.json: out/skillboxes.jsonnet
	python src/jsonnet.py out/skillboxes.jsonnet || $(call restore-file,$@)

out/atta_galatta.json:
	python -m src.sources.atta_galatta || $(call restore-file,$@)

out/champaca.json:
	python -m src.sources.champaca || $(call restore-file,$@)

out/highape.txt:
	python -m src.sources.highape | sort > $@ || $(call restore-file,$@)
	echo "[HIGHAPE] $$(wc -l $@ | cut -d ' ' -f 1)"

out/mapindia.ics:
	python -m src.sources.mapindia || $(call restore-file,$@)

out/mapindia.json: out/mapindia.ics
	python src/ics-to-event.py out/mapindia.ics $@ || $(call restore-file,$@)

out/district.txt:
	curl_chrome116 --silent \
	--url 'https://api.insider.in/home?city=delhi&eventType=physical&filterBy=go-out&norm=1&select=lite&typeFilter=physical' | \
	jq -r '.list.masterList|keys[]|["https://insider.in",., "event"]|join("/")' | sort > $@ ||  $(call restore-file,$@)
	sed -i 's|https://insider.in/|https://district.in/|g' $@
	echo "[DISTRICT] $$(wc -l $@ | cut -d ' ' -f 1)"

out/artzo.txt:
	python -m src.sources.artzo | sort > $@ || $(call restore-file,$@)
	echo "[ARTZO] $$(wc -l $@ | cut -d ' ' -f 1)"

out/bhaagoindia.txt:
	python -m src.sources.bhaagoindia | sort > $@ ||  $(call restore-file,$@)
	echo "[BHAAGOINDIA] $$(wc -l $@ | cut -d ' ' -f 1)"

out/goethe.json:
	python -m src.sources.goethe || $(call restore-file,$@)

out/urbanaut.json:
	python -m src.sources.urbanaut || $(call restore-file,$@)

out/sofar.json:
	python -m src.sources.sofar || $(call restore-file,$@)

out/sumukha.json:
	python -m src.sources.sumukha || $(call restore-file,$@)

out/timeandspace.json:
	python -m src.sources.timeandspace || $(call restore-file,$@)

out/townscript.txt:
	python -m src.sources.townscript | sort -u > $@ || $(call restore-file,$@)
	echo "[TOWNSCRIPT] $$(wc -l $@ | cut -d ' ' -f 1)"

out/bluetokai.json:
	python -m src.sources.bluetokai || $(call restore-file,$@)

out/gullytours.json:
	python -m src.sources.gullytours || $(call restore-file,$@)

out/tonight.json:
	python -m src.sources.tonight || $(call restore-file,$@)

out/creativemornings.txt:
	python -m src.sources.creativemornings | sort > $@ || $(call restore-file,$@)
	echo "[CREATIVEMORNINGS] $$(wc -l $@ | cut -d ' ' -f 1)"

out/adidas.json:
	python -m src.sources.adidas || $(call restore-file,$@)

out/pvr-cinemas.csv:
	python -m src.sources.pvr || ($(call restore-file,$@); $(call restore-file,"out/pvr-movies.csv"); $(call restore-file,"out/pvr-sessions.csv"))

out/ticketnew/cinemas.csv:
	mkdir -p out/ticketnew
	python -m src.sources.ticketnew || echo "[TICKETNEW] FAILED";

out/trove.json:
	python -m src.sources.trove || $(call restore-file,$@)

out/thewhitebox.json:
	python -m src.sources.thewhitebox || $(call restore-file,$@)

out/sis.json:
	python -m src.sources.sis || $(call restore-file,$@)

out/pumarun.txt:
	python -m src.sources.eventbrite pumarun | sort > $@ || $(call restore-file,$@)
	echo "[PUMARUN] $$(wc -l $@ | cut -d ' ' -f 1)"

# we just do a minimal transform to remove extra bits we don't need

out/cksl.ics:
	wget -q https://calendar.google.com/calendar/ical/c_0tfecbctgj9m3ei54jihee4u0c%40group.calendar.google.com/public/basic.ics -O $@ || $(call restore-file,$@)

out/cksl.jsonnet: out/cksl.ics
	python src/ics-to-event.py out/cksl.ics $@ || $(call restore-file,$@)

out/cksl.json: out/cksl.jsonnet
	python src/jsonnet.py out/cksl.jsonnet || $(call restore-file,$@)

out/ihc.json:
	python -m src.sources.ihc || $(call restore-file,$@)
	
out/lavonne.json:
	python -m src.sources.lavonne || $(call restore-file,$@)

out/paintbar.json:
	python -m src.sources.paintbar || $(call restore-file,$@)

out/pedalintandem.json:
	python -m src.sources.pedalintandem || $(call restore-file,$@)

out/sabha.json:
	python -m src.sources.sabha || $(call restore-file,$@)

out/indiarunning.json:
	python -m src.sources.indiarunning || $(call restore-file,$@)

out/penciljam.json:
	python -m src.sources.penciljam || $(call restore-file,$@)

fetch: out/allevents.txt \
 out/highape.txt \
 out/district.txt \
 out/bhaagoindia.txt \
 out/goethe.json \
 out/urbanaut.json \
 out/sumukha.json \
 out/sofar.json \
 out/bluetokai.json \
 out/gullytours.json \
 out/townscript.txt \
 out/tonight.json \
 out/creativemornings.txt \
 out/adidas.json \
 out/pvr-cinemas.csv \
 out/ticketnew/cinemas.csv \
 out/trove.json \
 out/te.json \
 out/sis.json \
 out/pumarun.txt \
 out/skillboxes.json \
 out/thewhitebox.json \
 out/timeandspace.json \
 out/paintbar.json \
 out/artzo.txt \
 out/pedalintandem.json \
 out/cksl.json \
 out/indiarunning.json \
 out/penciljam.json
	@echo "Done"

clean:
	rm -f libsqlite.so
	rm -rf out/*

build: fetch
	python -m src.build

libsqlite.so:
	.github/sqlite.sh

post-build: libsqlite.so
	@echo "Running post-build steps"
	python -m src.processors
	LD_PRELOAD=./libsqlite.so python3 -c "import sqlite3;print(sqlite3.sqlite_version)"
	LD_PRELOAD=./libsqlite.so python3 -m sqlite3 events.db < post-build.sql
	python src/validator.py --output report.json

all: build post-build
	@echo "Finished build"
