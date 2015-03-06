SHELL := /bin/bash

STORM_VERSION := 0.9.3
PARCEL_VERSION := $(STORM_VERSION)$(if $(BUILD_NUMBER),-b$(BUILD_NUMBER),-local)
PARCEL_DIR := STORM-$(PARCEL_VERSION)

GPG := gpg2 --homedir gpg-homedir
JAVA := $(if $(JAVA_HOME),$(JAVA_HOME)/bin/java,java)
MVN := mvn
TAR := tar
VALIDATOR := cm_ext/validator/target/validator.jar
WGET := wget -c --no-use-server-timestamps

$(PARCEL_DIR)-wheezy.parcel: stamp-extract $(PARCEL_DIR)/bin/storm-cm $(PARCEL_DIR)/meta/parcel.json $(PARCEL_DIR)/meta/defines $(PARCEL_DIR)/meta/alternatives.json $(VALIDATOR)
	fakeroot $(TAR) --create --file=$@ $(PARCEL_DIR) --gzip
	if ! $(JAVA) -jar $(VALIDATOR) -f $@; then rm $@; exit 1; fi

stamp-extract: apache-storm-$(STORM_VERSION).tar.gz
	mkdir -p $(PARCEL_DIR)
	$(TAR) --strip-components=1 --extract --directory=$(PARCEL_DIR) --file=$(filter %.tar.gz,$^)
	touch $@

$(PARCEL_DIR)/bin/storm-cm: storm-cm stamp-extract
	mkdir -p $(dir $@)
	install -T -m 0755 $< $@

$(PARCEL_DIR)/meta/defines: defines
	mkdir -p $(dir $@)
	install -T -m 0755 $< $@

$(PARCEL_DIR)/meta/%.json: %.json.in
	mkdir -p $(dir $@)
	sed \
		-e 's/@VERSION@/$(PARCEL_VERSION)/g' \
		-e '/^!/d' \
		$< > $@

apache-storm-$(STORM_VERSION).tar.gz: stamp-gpg apache-storm-$(STORM_VERSION).tar.gz.asc
	$(WGET) http://mirror.symnds.com/software/Apache/storm/apache-storm-$(STORM_VERSION)/apache-storm-$(STORM_VERSION).tar.gz
	$(GPG) --verify $(filter %.asc,$^) || rm -f $@

apache-storm-$(STORM_VERSION).tar.gz.asc:
	$(WGET) http://www.apache.org/dist/storm/apache-storm-$(STORM_VERSION)/apache-storm-$(STORM_VERSION).tar.gz.asc

stamp-gpg: KEYS
	mkdir --mode=0700 gpg-homedir
	$(GPG) --homedir gpg-homedir --import KEYS
	touch $@

KEYS:
	$(WGET) https://www.apache.org/dist/storm/KEYS

$(VALIDATOR): stamp-cm_ext
	cd cm_ext && $(MVN) -pl validator package

stamp-cm_ext:
	git clone https://github.com/cloudera/cm_ext.git
	touch $@

.PHONY: clean
clean:
	rm -rf stamp-* *.gz *.gz.asc *.parcel *.validator $(PARCEL_DIR) gpg-homedir cm_ext

.DEFAULT_GOAL := $(PARCEL_DIR)-wheezy.parcel
