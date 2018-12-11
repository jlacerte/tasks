# This file is licensed under the Affero General Public License version 3 or
# later. See the COPYING file.
# @author Bernhard Posselt <dev@bernhard-posselt.com>
# @copyright Bernhard Posselt 2017
# @author Georg Ehrke <oc.list@georgehrke.com>
# @copyright Georg Ehrke 2017
# @author Raimund Schlüßler
# @copyright 2018 Raimund Schlüßler <raimund.schluessler@mailbox.org>

# Generic Makefile for building and packaging a Nextcloud app which uses npm and
# Composer.
#
# Dependencies:
# * make
# * which
# * curl: used if phpunit and composer are not installed to fetch them from the web
# * tar: for building the archive
# * npm: for building and testing everything JS
#
# The npm command by launches the npm build script:
#
#    npm run build
#
# The npm test command launches the npm test script:
#
#    npm run test
#

app_name=$(notdir $(CURDIR))
build_directory=$(CURDIR)/build
appstore_build_directory=$(CURDIR)/build/appstore/$(app_name)
appstore_artifact_directory=$(CURDIR)/build/artifacts/appstore
appstore_package_name=$(appstore_artifact_directory)/$(app_name)
npm=$(shell which npm 2> /dev/null)
gcp=$(shell which gcp 2> /dev/null)

ifeq (, $(gcp))
	copy_command=cp
else
	copy_command=gcp
endif

# code signing
# assumes the following:
# * the app is inside the nextcloud/apps folder
# * the private key is located in ~/.nextcloud/tasks.key
# * the certificate is located in ~/.nextcloud/tasks.crt
occ=$(CURDIR)/../../occ
configdir=$(CURDIR)/../../config
private_key=$(HOME)/.nextcloud/$(app_name).key
certificate=$(HOME)/.nextcloud/$(app_name).crt
sign=php -f $(occ) integrity:sign-app --privateKey="$(private_key)" --certificate="$(certificate)"
sign_skip_msg="Skipping signing, either no key and certificate found in $(private_key) and $(certificate) or occ can not be found at $(occ)"
ifneq ("$(wildcard $(private_key))","") #(,$(wildcard $(private_key)))
	ifneq ("$(wildcard $(certificate))","")#(,$(wildcard $(certificate)))
		ifneq ("$(wildcard $(occ))","")#(,$(wildcard $(occ)))
			CAN_SIGN=true
		endif
	endif
endif

all: build

# Fetches the PHP and JS dependencies and compiles the JS. If no composer.json
# is present, the composer step is skipped, if no package.json or js/package.json
# is present, the npm step is skipped
.PHONY: build
build:
	$(npm) run build

# Sets up the development environment
.PHONY: development
development:
	$(npm) install
	$(npm) update
	$(npm) run dev

# Removes the build directory and the compiled files
.PHONY: clean
clean:
	rm -f ./css/src/sprites.scss
	rm -f ./css/src/sprites-bw.scss
	rm -f ./css/src/sprites-color.scss
	rm -f ./img/sprites.svg
	rm -f ./img/bw.svg
	rm -f ./img/color.svg
	rm -f ./js/tasks.js
	rm -f ./js/tasks.js.map
	rm -rf $(build_directory)

# Same as clean but also removes dependencies installed by npm
.PHONY: distclean
distclean: clean
	rm -rf node_modules

# Watches the js and scss files
.PHONY: watch
watch:
	$(npm) run watch

# Builds the source package for the app store
.PHONY: appstore
appstore: clean build
	mkdir -p $(appstore_build_directory) $(appstore_artifact_directory)
	rsync -av .	$(appstore_build_directory) \
	--exclude=/.git \
	--exclude=/.babelrc \
	--exclude=/.babelrc.js \
	--exclude=/.editorconfig \
	--exclude=/.eslintrc.js \
	--exclude=/.gitattributes \
	--exclude=/.gitignore \
	--exclude=/.gitlab-ci.yml \
	--exclude=/.prettierrc.js \
	--exclude=/.scrutinizer.yml \
	--exclude=/.stylelintrc \
	--exclude=/.travis.yml \
	--exclude=/.tx \
	--exclude=/.v8flags*.json \
	--exclude=/build.xml \
	--exclude=/CONTRIBUTING.md \
	--exclude=/issue_template.md \
	--exclude=/gulpfile.js \
	--exclude=/Makefile \
	--exclude=/package-lock.json \
	--exclude=/package.json \
	--exclude=/README.md \
	--exclude=/svg-sprite-bw.json \
	--exclude=/svg-sprite-bw.tmpl \
	--exclude=/svg-sprite-color.json \
	--exclude=/svg-sprite-color.tmpl \
	--exclude=/webpack.common.js \
	--exclude=/webpack.prod.js \
	--exclude=/webpack.dev.js \
	--exclude=/build \
	--exclude=/coverage \
	--exclude=/img/src \
	--exclude=/src \
	--exclude=/node_modules \
	--exclude=/screenshots/ \
	--exclude=/test \
	--exclude=/tests
ifdef CAN_SIGN
	mv $(configdir)/config.php $(configdir)/config-2.php
	$(sign) --path="$(appstore_build_directory)"
	mv $(configdir)/config-2.php $(configdir)/config.php
else
	@echo $(sign_skip_msg)
endif
	cd $(appstore_build_directory)/../; \
	zip -r $(appstore_package_name).zip $(app_name)
	tar -czf $(appstore_package_name).tar.gz -C $(appstore_build_directory)/../ $(app_name)
# create hash
ifdef CAN_SIGN
	openssl dgst -sha512 -sign $(private_key) $(appstore_package_name).tar.gz | openssl base64 -out $(appstore_artifact_directory)/$(app_name).sha512
else
	@echo "Skipping hashing, no key found in $(private_key)."
endif

# Command for running VUE tests
.PHONY: test
test:
	$(npm) run test
