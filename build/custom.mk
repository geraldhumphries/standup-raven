define GetPluginVersion
$(shell node -p "'v' + require('./plugin.json').version")
endef

define AddTimeZoneOptions
$(shell node -e 
"
let fs = require('fs');
try {
	let manifest = fs.readFileSync('${MANIFEST_FILE}', 'utf8'); 
	manifest = JSON.parse(manifest);
	let timezones = fs.readFileSync('timezones.json', 'utf8'); 
	timezones = JSON.parse(timezones); 
	manifest.settings_schema.settings[0].options=timezones; 
	let json = JSON.stringify(manifest, null, 2);
	fs.writeFileSync('${MANIFEST_FILE}', json, 'utf8'); 
} catch (err) {
	console.log(err);
};"
)
endef

define RemoveTimeZoneOptions
$(shell node -e 
"
let fs = require('fs');
try {
	let manifest = fs.readFileSync('${MANIFEST_FILE}', 'utf8'); 
	manifest = JSON.parse(manifest);
	manifest.settings_schema.settings[0].options=[]; 
	let json = JSON.stringify(manifest, null, 2);
	fs.writeFileSync('${MANIFEST_FILE}', json, 'utf8'); 
} catch (err) {
	console.log(err);
};"
)
endef

define UpdateServerHash
git ls-files ./server | xargs shasum -a 256 | cut -d" " -f1 | shasum -a 256 | cut -d" " -f1 > server.sha
endef

define UpdateWebappHash
git ls-files ./webapp | xargs shasum -a 256 | cut -d" " -f1 | shasum -a 256 | cut -d" " -f1 > webapp.sha
endef

vendor: go.sum
	echo "Downloading server dependencies"
	go mod download

PLUGIN_VERSION = $(call GetPluginVersion)
GO_BUILD_FLAGS = -ldflags="-X 'main.PluginVersion=$(PLUGIN_VERSION)' -X 'main.SentryServerDSN=$(SERVER_DSN)' -X 'main.SentryWebappDSN=$(WEBAPP_DSN)' -X 'main.EncodedPluginIcon=data:image/svg+xml;base64,$(shell base64 assets/logo.svg)'"

#
#
#.PHONY: default build test run clean stop check-style check-style-server .distclean dist fix-style release
#
#.SILENT: default build test run clean stop check-style check-style-server .distclean dist fix-style release inithashes buildwebapp buildserver package
#
#default: check-style test dist
#
#check-style: check-style-server check-style-webapp
#
#check-style-webapp: .webinstall
#	echo Checking for style guide compliance
#	cd webapp && yarn run lint
#
#check-style-server:
#	if ! [ -x "$$(command -v golangci-lint)" ]; then \
#			echo "golangci-lint is not installed. Please see https://github.com/golangci/golangci-lint#install for installation instructions."; \
#			exit 1; \
#		fi; \
#	
#	echo Running golangci-lint
#	golangci-lint run ./server/...
#	

fix-style: fix-style-server fix-style-webapp

fix-style-server:
	echo "Fixing server styles..."
	if ! [ -x "$$(command -v golangci-lint)" ]; then \
			echo "golangci-lint is not installed. Please see https://github.com/golangci/golangci-lint#install for installation instructions."; \
			exit 1; \
		fi; \
	
	echo Running golangci-lint
	golangci-lint run --fix ./server/...

fix-style-webapp:
	echo "Fixing webapp styles..."
	cd webapp && yarn run fix

inithashes:
ifeq (,$(wildcard ./server.sha))
	echo "Initializing server hash file"
	$(call UpdateServerHash)
endif
ifeq (,$(wildcard ./webapp.sha))
	echo "Initializing webapp hash file"
	$(call UpdateWebappHash)
endif


prequickdist: plugin.json
	@echo Updating plugin.json with timezones
	$(call AddTimeZoneOptions)

buildserver:
	cp server.sha server.old.sha
	echo "Updating server hash"
	$(call UpdateServerHash)
	FILES_MATCH=true;\
	if cmp -s "server.sha" "server.old.sha"; then\
		FILES_MATCH=true;\
	else\
		FILES_MATCH=false;\
	fi;\
	ARTIFACTS_EXIST=false;\
	if [[ -f ./dist/intermediate/plugin_linux_amd64 && -f ./dist/intermediate/plugin_darwin_amd64 && -f ./dist/intermediate/plugin_windows_amd64.exe ]]; then\
		ARTIFACTS_EXIST=true;\
	else\
		ARTIFACTS_EXIST=false;\
	fi;\
	if $$FILES_MATCH && $$ARTIFACTS_EXIST; then\
		echo "Skipping server build as nothing updated since last build.";\
	else\
		echo "Building server component";\
		# Build files from server\
		# We need to disable gomodules when installing gox to prevent `go get` from updating go.mod file.\
		# See this for more details -\
		# 	https://stackoverflow.com/questions/56842385/using-go-get-to-download-binaries-without-adding-them-to-go-mod\
		cd server;\
		GO111MODULE=off go get github.com/mitchellh/gox;\
		cd ..;\
		$(shell go env GOPATH)/bin/gox -ldflags="-X 'main.PluginVersion=$(PLUGINVERSION)' -X 'main.SentryServerDSN=$(SERVER_DSN)' -X 'main.SentryWebappDSN=$(WEBAPP_DSN)' -X 'main.EncodedPluginIcon=data:image/svg+xml;base64,`base64 webapp/src/assets/images/logo.svg`' " -osarch='darwin/amd64 linux/amd64 windows/amd64' -gcflags='all=-N -l' -output 'dist/intermediate/plugin_{{.OS}}_{{.Arch}}' ./server;\
	fi

buildwebapp:
	cp webapp.sha webapp.old.sha
	echo "Updating webapp hash"
	$(call UpdateWebappHash)
	FILES_MATCH=true;\
	if cmp -s "webapp.sha" "webapp.old.sha"; then\
		FILES_MATCH=true;\
	else\
		FILES_MATCH=false;\
	fi;\
	pwd;\
	DIST_DIR="./dist/$(PLUGIN_ID)/webapp";\
	export DIST_EXISTS=true;\
	if [ -d $$DIST_DIR ]; then\
		export DIST_EXISTS=true;\
	else\
		export DIST_EXISTS=false;\
	fi;\
	echo $$FILES_MATCH;\
	echo $$DIST_EXISTS;\
	if $$FILES_MATCH && $$DIST_EXISTS; then\
		echo "Skipping webapp build as nothing updated since last build.";\
	else\
		cd webapp;\
		yarn run build;\
		cd ..;\
		mkdir -p dist/$(PLUGIN_ID)/webapp;\
		cp -r webapp/dist/* dist/$(PLUGIN_ID)/webapp/;\
	fi

package:
	WEBAPP_CHANGED=true;\
	if cmp -s "webapp.sha" "webapp.old.sha"; then\
		WEBAPP_CHANGED=false;\
	else\
		WEBAPP_CHANGED=true;\
	fi;\
	SERVER_CHANGED=true;\
	if cmp -s "server.sha" "server.old.sha"; then\
		SERVER_CHANGED=false;\
	else\
		SERVER_CHANGED=true;\
	fi;\
	ARTIFACTS_MISSING=false;\
	if [[ -f dist/$(BUNDLE_NAME)-linux-amd64.tar.gz && -f dist/$(BUNDLE_NAME)-darwin-amd64.tar.gz && dist/$(BUNDLE_NAME)-windows-amd64.tar.gz ]]; then\
		ARTIFACTS_MISSING=false;\
	else\
		ARTIFACTS_MISSING=true;\
	fi;\
	if $$WEBAPP_CHANGED || $$SERVER_CHANGED || $$ARTIFACTS_MISSING; then\
		mkdir -p dist/$(PLUGIN_ID);\
		cp plugin.json dist/$(PLUGIN_ID)/;\

		mkdir -p dist/$(PLUGIN_ID)/server;\
		
		pwd;\
		cp dist/intermediate/plugin_darwin_amd64 dist/$(PLUGINNAME)/server/plugin.exe;\
		cd dist && tar -zcvf $(PACKAGENAME)-darwin-amd64.tar.gz $(PLUGINNAME)/*;\
		cd ..;\
		
		cp dist/intermediate/plugin_linux_amd64 dist/$(PLUGINNAME)/server/plugin.exe;\
		cd dist && tar -zcvf $(PACKAGENAME)-linux-amd64.tar.gz $(PLUGINNAME)/*;\
		cd ..;\
		
		cp dist/intermediate/plugin_windows_amd64.exe dist/$(PLUGINNAME)/server/plugin.exe;\
		cd dist && tar -zcvf $(PACKAGENAME)-windows-amd64.tar.gz $(PLUGINNAME)/*;\
		cd ..;\
		echo Linux plugin built at: dist/$(PACKAGENAME)-linux-amd64.tar.gz;\
		echo MacOS X plugin built at: dist/$(PACKAGENAME)-darwin-amd64.tar.gz;\
		echo Windows plugin built at: dist/$(PACKAGENAME)-windows-amd64.tar.gz;\
	else\
		echo "Skipping package plugin as nothing changed";\
	fi
	rm server.old.sha
	rm webapp.old.sha
	
doquickdist: inithashes buildwebapp buildserver package
	echo $(PLUGIN_ID)
	echo $(BUNDLE_NAME)
	echo $(PLUGIN_VERSION)
	echo Quick building plugin

postquickdist:
	echo Remove data from plugin.json
	$(call RemoveTimeZoneOptions)

quickdist: prequickdist doquickdist postquickdist

release: dist
	echo "Installing ghr"
	go get -u github.com/tcnksm/ghr
	echo "Create new tag"
	$(shell git tag $(PLUGIN_VERSION))
	echo "Uploading artifacts"
	ghr -t $(GITHUB_TOKEN) -u $(ORG_NAME) -r $(REPO_NAME) $(PLUGIN_VERSION) dist/
