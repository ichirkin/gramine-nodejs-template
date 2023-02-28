MANIFEST_FILE = nodejs.manifest
NODEJS_SIGN = nodejs.sig
MANIFEST_SGX_FILE = $(MANIFEST_FILE).sgx
NODEJS_DIR ?= /usr/local/bin
BUILD_IMAGE = ichirkin/gramine-nodejs
ENCLAVE_KEY = enclave-key.pem
APP_DIR = /opt/app
DOCKER_RUN = docker run --rm -w /build -v $$(pwd):/build -v $$(pwd)/dist:$(APP_DIR) $(BUILD_IMAGE)
GPG_KEY ?= gpg.key
SOURCES := $(wildcard src/**/*.*)

ARCH_LIBDIR ?= /lib/x86_64-linux-gnu

ifeq ($(DEBUG),1)
GRAMINE_LOG_LEVEL = debug
else
GRAMINE_LOG_LEVEL = error
endif

$(MANIFEST_FILE): nodejs.manifest.template
	$(DOCKER_RUN) \
		"gramine-manifest \
		-Dlog_level=$(GRAMINE_LOG_LEVEL) \
		-Darch_libdir=$(ARCH_LIBDIR) \
		-Dnodejs_dir=$(NODEJS_DIR) \
		-Dapp_dir=$(APP_DIR) \
		$< >$@"

$(GPG_KEY):
	@LC_ALL=C tr -dc 'A-Z0-9' </dev/urandom | head -c 64  > $@

$(ENCLAVE_KEY).gpg: $(GPG_KEY)
	$(DOCKER_RUN) \
		"gramine-sgx-gen-private-key $(ENCLAVE_KEY)"

	cat $(GPG_KEY) | gpg --pinentry-mode loopback \
		--symmetric \
		--passphrase-fd 0 \
		--cipher-algo AES256 $(ENCLAVE_KEY)

$(ENCLAVE_KEY): $(ENCLAVE_KEY).gpg $(GPG_KEY)
	@gpg --quiet --batch --yes --decrypt --passphrase="$$(cat $(GPG_KEY))" \
		--output $@ $<

sgx_sign: $(MANIFEST_FILE) $(ENCLAVE_KEY)
	$(DOCKER_RUN) \
		"gramine-sgx-sign \
		--manifest $< \
		--key $(ENCLAVE_KEY) \
		--output $<.sgx"
